#!/usr/bin/env bash
# The repository checks CI runs, for contributors to run before a PR:
#   bash scripts/check.sh
# Checks tracked files plus untracked files git does not ignore. Needs git, jq
# and perl. Without shellcheck, python3 with PyYAML, or node, that check prints a
# skip line; under CI=true a skipped check fails instead.

set -u

cd "$(dirname -- "$0")/.." || exit 2
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "scripts/check.sh: run it from a git checkout"
  exit 2
}
for tool in jq perl; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "scripts/check.sh: needs $tool"
    exit 2
  }
done

passed=0
failed=0
skipped=0
count=0
problems=()

files() { git ls-files -z --cached --others --exclude-standard -- "$@"; }

problem() { problems+=("$1"); }

finish() { # finish NAME SUMMARY: ok unless a problem was recorded since the last finish
  if [ "${#problems[@]}" -eq 0 ]; then
    passed=$((passed + 1))
    printf 'ok    %s: %s\n' "$1" "$2"
  else
    failed=$((failed + 1))
    printf 'FAIL  %s: %s\n' "$1" "$2"
    printf '%s\n' "${problems[@]}" | sed 's/^/        /'
  fi
  problems=()
}

skip() { # skip NAME REASON
  if [ "${CI:-}" = true ]; then
    problem "$2, and CI=true does not allow a skip"
    finish "$1" "not run"
  else
    skipped=$((skipped + 1))
    printf 'skip  %s: %s\n' "$1" "$2"
  fi
}

collect() { # collect OUTPUT: the last line sets count, every other line is a problem
  local line
  count="$(printf '%s\n' "$1" | tail -n 1)"
  while IFS= read -r line; do
    problem "$line"
  done < <(printf '%s\n' "$1" | sed '$d')
  [ "$count" -gt 0 ] 2>/dev/null || problem "no files to check"
}

regular() { [ -f "$1" ] && [ ! -L "$1" ]; }

check_ascii() {
  local out scan
  scan='
    use strict;
    use warnings;
    my %binary = (
      "docs/demo.gif"                         => "GIF8",
      "plugins/sutra/assets/icon.png"         => "\x89PNG\r\n\x1a\n",
      "plugins/sutra-harness/assets/icon.png" => "\x89PNG\r\n\x1a\n",
    );
    my $bad = qr/[^\t\n\r\x20-\x7e]|\r(?!\n)/;
    my ($count, %seen) = (0);
    local $/ = "\0";
    while (my $name = <STDIN>) {
      chomp $name;
      (my $shown = $name) =~ s/([^\x20-\x7e])/sprintf "\\x%02x", ord $1/ge;
      print "$shown: file name is not printable ASCII\n" if $shown ne $name;
      next if -l $name || !-f _;
      open(my $fh, "<:raw", $name) or do { print "$shown: cannot read: $!\n"; next };
      my $data = do { local $/; <$fh> } // "";
      close $fh;
      $count++;
      if (exists $binary{$name}) {
        $seen{$name} = 1;
        print "$shown: allowlisted as binary but lacks its file signature\n"
          if substr($data, 0, length $binary{$name}) ne $binary{$name};
        next;
      }
      next unless $data =~ $bad;
      my ($n, @lines) = (0);
      for my $line (split /(?<=\n)/, $data) {
        $n++;
        push @lines, $n if $line =~ $bad;
      }
      my $list = join ", ", @lines[0 .. ($#lines > 9 ? 9 : $#lines)];
      $list .= sprintf " and %d more", @lines - 10 if @lines > 10;
      print "$shown: NUL, control or non-ASCII byte on line $list (only tab, LF, and CR before LF are allowed)\n";
    }
    for my $name (sort keys %binary) {
      print "$name: in the binary allowlist but not in the tree\n" unless $seen{$name};
    }
    print "$count\n";
  '
  out="$(files | perl -e "$scan")" || problem "the byte scan failed"
  collect "$out"
  finish ascii "$count files scanned for NUL, control and non-ASCII bytes; allowlisted binaries: docs/demo.gif and each plugin's assets/icon.png"
}

check_json() {
  local f n=0
  while IFS= read -r -d '' f; do
    regular "$f" || continue
    n=$((n + 1))
    jq -e -s 'length == 1' "./$f" >/dev/null 2>&1 </dev/null ||
      problem "$f: not exactly one valid JSON document"
  done < <(files '*.json')
  [ "$n" -gt 0 ] || problem "no JSON files to check"
  finish json "$n files parsed with jq"
}

check_yaml() {
  if ! python3 -I -c 'import yaml' >/dev/null 2>&1; then
    skip yaml "python3 with PyYAML not found"
    return
  fi
  local out parse
  parse='
import os, sys, yaml
count = 0
for raw in sys.stdin.buffer.read().split(b"\0"):
    path = os.fsdecode(raw)
    if not path or os.path.islink(path) or not os.path.isfile(path):
        continue
    count += 1
    try:
        with open(path, "rb") as fh:
            for _ in yaml.safe_load_all(fh):
                pass
    except (OSError, yaml.YAMLError) as err:
        line = "%s: %s" % (path, " ".join(str(err).split()))
        print(line.encode("ascii", "backslashreplace").decode("ascii"))
print(count)
'
  out="$(files '*.yaml' '*.yml' | python3 -I -c "$parse")" || problem "python3 failed"
  collect "$out"
  finish yaml "$count files parsed with PyYAML"
}

check_bash_syntax() {
  local f n=0 out
  while IFS= read -r -d '' f; do
    regular "$f" || continue
    n=$((n + 1))
    out="$(bash -n "./$f" 2>&1 </dev/null)" || problem "${out:-$f: bash -n failed}"
  done < <(files '*.sh')
  [ "$n" -gt 0 ] || problem "no shell scripts to check"
  finish bash-syntax "$n scripts checked with bash -n"
}

check_shellcheck() {
  local version f n=0 out
  version="$(shellcheck --version 2>/dev/null | sed -n 's/^version: //p')"
  if [ -z "$version" ]; then
    skip shellcheck "shellcheck not installed"
    return
  fi
  while IFS= read -r -d '' f; do
    regular "$f" || continue
    n=$((n + 1))
    out="$(shellcheck -S warning "./$f" 2>&1 </dev/null)" || problem "${out:-$f: shellcheck failed}"
  done < <(files '*.sh')
  [ "$n" -gt 0 ] || problem "no shell scripts to check"
  finish shellcheck "$n scripts checked at severity warning (shellcheck $version)"
}

frontmatter() { # frontmatter FILE: prints the block between the first-line --- and the next ---
  awk 'NR == 1 { if ($0 != "---" && $0 != "---\r") exit 1; next }
    $0 == "---" || $0 == "---\r" { closed = 1; exit }
    { print }
    END { if (!closed) exit 1 }' <"$1"
}

has_key() { printf '%s\n' "$1" | grep -Eq "^$2:[[:space:]]*[\"']?[^[:space:]\"']"; }

check_frontmatter() {
  local f fm skills=0 agents=0
  while IFS= read -r -d '' f; do
    regular "$f" || continue
    case "$f" in
      plugins/sutra/agents/*) agents=$((agents + 1)) ;;
      *) skills=$((skills + 1)) ;;
    esac
    if ! fm="$(frontmatter "$f")"; then
      problem "$f: no frontmatter (--- on the first line, then a closing ---)"
      continue
    fi
    has_key "$fm" description || problem "$f: frontmatter has no description"
    case "$f" in
      plugins/sutra/agents/*) has_key "$fm" name || problem "$f: frontmatter has no name" ;;
    esac
  done < <(files 'plugins/sutra/skills/*/SKILL.md' 'plugins/sutra/agents/*.md')
  [ "$skills" -gt 0 ] || problem "no skills under plugins/sutra/skills"
  [ "$agents" -gt 0 ] || problem "no agents under plugins/sutra/agents"
  finish frontmatter "$skills skills checked for a description, $agents agents for a name and a description"
}

plugin_dirs() { # the plugin folders marketplace.json lists, one per line
  jq -r '.plugins[].source | strings | select(startswith("./")) | ltrimstr("./")' .claude-plugin/marketplace.json
}

check_manifests() {
  local market=.claude-plugin/marketplace.json name src manifest version v line names versions=() n=0
  names="$(jq -c '[.plugins[].name]' "$market")"
  while IFS=$'\t' read -r name src; do
    n=$((n + 1))
    manifest="${src#./}/.claude-plugin/plugin.json"
    case "$src" in
      ./plugins/"$name") ;;
      *) problem "$market: $name: source $src is not ./plugins/$name" ;;
    esac
    if ! regular "$manifest"; then
      problem "$market: $name: $manifest is missing"
      continue
    fi
    [ "$(jq -r '.name' "$manifest")" = "$name" ] || problem "$manifest: name is not $name"
    while IFS= read -r line; do
      problem "$manifest: $line"
    done < <(jq -r --argjson names "$names" '.dependencies[]?
      | if type == "string" then (if test("@") then empty else . end)
        elif (.marketplace? // null) == null then .name else empty end
      | select(. as $d | ($names | any(.[]; . == $d)) | not)
      | "dependency \(.) names no plugin in marketplace.json"' "$manifest" 2>&1)
    version="$(jq -r '.version | strings' "$manifest")"
    if [ -z "$version" ]; then
      problem "$manifest: no version"
      continue
    fi
    versions+=("$version")
  done < <(jq -r '.plugins[] | [.name, (.source | tostring)] | @tsv' "$market")
  [ "$n" -gt 0 ] || problem "$market lists no plugins"
  version="${versions[0]:-}"
  for v in ${versions[@]+"${versions[@]}"}; do
    [ "$v" = "$version" ] || problem "plugin versions differ (${versions[*]}); the plugins release together"
  done
  [ -z "$version" ] || grep -q "^## \[$version\]" CHANGELOG.md || problem "CHANGELOG.md: no ## [$version] section"
  finish manifests "$n marketplace entries checked against their plugin folders (name, source, dependencies, one shared version: ${version:-none}) and CHANGELOG.md"
}

check_plugin_limits() {
  local dir f n size line counts=""
  shopt -s nocasematch
  while IFS= read -r dir; do
    n=0
    while IFS= read -r -d '' f; do
      if [ ! -e "$f" ] && [ ! -L "$f" ]; then continue; fi
      n=$((n + 1))
      if [ -L "$f" ]; then
        problem "$f: symlink"
        continue
      fi
      if [ ! -f "$f" ]; then
        problem "$f: not a regular file"
        continue
      fi
      case "$f" in
        *.png | *.jpg | *.jpeg | *.gif | *.webp | *.svg | *.ico | *.bmp | *.avif | \
          *.woff | *.woff2 | *.ttf | *.otf | *.eot) continue ;;
      esac
      size=$(($(wc -c <"$f")))
      [ "$size" -lt 262144 ] || problem "$f: $size bytes, and a file other than an image or font must be under 256 KiB"
    done < <(files "$dir")
    [ "$n" -gt 0 ] || problem "no files under $dir"
    [ "$n" -le 512 ] || problem "$dir: $n files, and the limit is 512"
    counts="$counts${counts:+, }$dir $n"
    local hooks="$dir/hooks/hooks.json" manifest="$dir/.claude-plugin/plugin.json"
    if [ -f "$hooks" ]; then
      while IFS= read -r line; do
        problem "$hooks: $line"
      done < <(jq -r "$bad_commands" "$hooks" 2>&1)
    fi
    while IFS= read -r line; do
      problem "$manifest: $line"
    done < <(jq -r "$bad_paths" "$manifest" 2>&1)
  done < <(plugin_dirs)
  shopt -u nocasematch
  [ -n "$counts" ] || problem "marketplace.json lists no plugin folder"
  finish plugin-limits "files per plugin (limit 512): $counts; file sizes, symlinks, hook commands and manifest paths checked"
}

# Commands in hooks.json may use only ${CLAUDE_PLUGIN_ROOT}; manifest paths stay inside the plugin.
bad_commands='
    [.. | objects | .command? | strings][]
    | select(test("[.][.]")
        or (gsub("[$][{]CLAUDE_PLUGIN_ROOT[}]"; "ROOT")
            | test("[$`]|(^|[^A-Za-z0-9_.-])[/~]")))
    | "command holds .., an absolute path, or a variable or command substitution other than ${CLAUDE_PLUGIN_ROOT}: \(.)"'
bad_paths='
    paths(strings) as $p
    | getpath($p)
    | select(test("^(/|~|[A-Za-z]:[\\\\/])") or test("(^|[\\\\/])\\.\\.([\\\\/]|$)"))
    | "\($p | map(tostring) | join(".")) is absolute or climbs with ..: \(.)"'

# Anthropic's plugin directory refuses, from an organization that is not
# Verified, any hook, workflow script, or file outside Markdown, text, JSON,
# YAML, and PNG/JPEG/GIF/WebP/ICO images. plugins/sutra is the plugin submitted
# there; everything that runs on its own lives in plugins/sutra-harness.
# The checklist still holds an .ico for a reviewer, so this gate rejects ICO too.
check_directory_policy() {
  local dir=plugins/sutra out scan line words f
  scan='
    use strict;
    use warnings;
    use Encode ();
    my $dir = shift;
    my %head = (
      png => qr/\A\x89PNG\r\n\x1a\n/, jpg => qr/\A\xff\xd8\xff/, jpeg => qr/\A\xff\xd8\xff/,
      gif => qr/\AGIF8[79]a/, webp => qr/\ARIFF.{4}WEBP/s,
    );
    my %tail = (png => qr/IEND\xaeB`\x82\z/, jpg => qr/\xff\xd9\z/, jpeg => qr/\xff\xd9\z/, gif => qr/\x3b\z/);
    my $text = qr/\.(?:md|markdown|txt|json|ya?ml)\z|(?:\A|\/)(?:LICENSE|LICENCE|COPYING|NOTICE|README|\.gitignore)\z/i;
    my $pm = qr/(?:\A|\/)(?:package(?:-lock)?\.json|npm-shrinkwrap\.json|pnpm-(?:workspace|lock)\.ya?ml|yarn\.lock|\.yarnrc(?:\.ya?ml)?|\.npmrc|bun\.lockb?|bunfig\.toml|deno\.(?:json|jsonc|lock)|composer\.(?:json|lock)|bower\.json|pubspec\.ya?ml|environment\.ya?ml|[^\/]*(?:requirements|constraints)[^\/]*\.txt|requirements\/[^\/]+\.txt|pipfile(?:\.lock)?|poetry\.lock|uv\.lock)\z/i;
    my $runs = qr/\A(?:(?:hooks|workflows|bin|monitors)\/|(?:\.mcp|\.lsp|settings)\.json\z)/i;
    my $device = qr/\A(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.[^.]*)?\z/i;
    my $component = qr/\A(?:skills\/[^\/]+\/SKILL|agents\/.+|commands\/.+|output-styles\/.+)\.md\z/i;
    my $entry = qr/\A(?:skills\/[^\/]+\/SKILL\.md|agents\/.+\.md|commands\/.+\.md|output-styles\/.+\.md|README\.md)\z/i;
    my %scanned = map { $_ => 1 } qw(name description tools disable-model-invocation);
    my ($count, %folded) = (0);
    local $/ = "\0";
    while (my $name = <STDIN>) {
      chomp $name;
      next if -l $name || !-f _;
      my $size = -s _;
      $count++;
      (my $rel = $name) =~ s/\A\Q$dir\E\///;
      for my $part (split /\//, $rel) {
        print "$name: the name part \"$part\" holds a colon, ends in a dot or space, or is a reserved device name\n"
          if $part =~ /:|[. ]\z/ || $part =~ $device;
        print "$name: macOS archive metadata (__MACOSX)\n" if $part eq "__MACOSX";
      }
      print "$name: differs from $folded{lc $rel} only by case\n" if exists $folded{lc $rel};
      $folded{lc $rel} = $name;
      print "$name: a plugin path that runs code or declares a hook or server\n" if $rel =~ $runs;
      print "$name: a package manager configuration file\n" if $rel =~ $pm;
      print "$name: a skill file must be named SKILL.md exactly\n" if $rel =~ /\Askills\/[^\/]+\/skill\.md\z/i && $rel !~ /\/SKILL\.md\z/;
      print "$name: $size bytes, and every file must be under 5 MiB\n" if $size >= 5 * 1024 * 1024;
      open(my $fh, "<:raw", $name) or do { print "$name: cannot read: $!\n"; next };
      my $data = do { local $/; <$fh> } // "";
      close $fh;
      my ($ext) = $rel =~ /\.([^.\/]+)\z/;
      $ext = lc($ext // "");
      if (exists $head{$ext}) {
        print "$name: not a complete .$ext image\n"
          unless $data =~ $head{$ext} && (!exists $tail{$ext} || $data =~ $tail{$ext});
        next;
      }
      if ($rel !~ $text) {
        print "$name: not Markdown, text, JSON, YAML, or a PNG, JPEG, GIF, or WebP image\n";
        next;
      }
      print "$name: starts with #!\n" if $data =~ /\A(?:\xef\xbb\xbf)?#!/;
      print "$name: holds a NUL byte\n" if index($data, "\0") >= 0;
      my $copy = $data;
      print "$name: not UTF-8\n" unless eval { Encode::decode("UTF-8", $copy, Encode::FB_CROAK()); 1 };
      print "$name: names $1, and the directory flags a download-and-run command in any text it reads\n" if $data =~ /\b(curl|wget|npx|pnpx|uvx|bunx|pipx|(?-i:dlx)|uv\s+(?:tool\s+)?run|npm\s+exec|bun\s+x)\b/i;
      next unless $rel =~ /\.md\z/i;
      if ($data =~ /\A(?:\xef\xbb\xbf)?---\r?\n(.*?)^---\r?$/ms) {
        my $fm = $1;
        while ($fm =~ /^(hooks|mcpServers)[ \t]*:/mg) {
          print "$name: frontmatter declares $1, which runs code\n";
        }
        if ($rel =~ $component) {
          for my $line (split /\r?\n/, $fm) {
            next if $line =~ /^[ \t]*(?:#.*)?$/ || $line =~ /^[ \t]/;
            if ($line =~ /^([A-Za-z][\w-]*)[ \t]*:[ \t]*(.*)$/) {
              my ($key, $value) = ($1, $2);
              print "$name: frontmatter key $key has not passed a directory scan; the directory refuses keys outside its unpublished list\n" unless $scanned{$key};
              print "$name: frontmatter key $key holds a list or map, and the directory takes only text here\n" if $value eq "" || $value =~ /^[\[{]/;
            } else {
              print "$name: frontmatter line is not a key and a value: $line\n";
            }
          }
        }
      }
      if ($rel =~ $entry) {
        while ($data =~ /\$\{?([A-Z][A-Z0-9_]{2,})\}?/g) {
          next if $1 =~ /\A(?:CLAUDE_PLUGIN_ROOT|CLAUDE_SKILL_DIR|ARGUMENTS)\z/;
          print "$name: reads \$$1, which the directory can treat as a credential from the environment\n";
          last;
        }
      }
      print "$name: runs a shell command when it loads (an inline !`...` or a ```! block)\n"
        if $rel =~ /\A(?:skills\/[^\/]+\/SKILL|commands\/.+)\.md\z/i && ($data =~ /(?:^|\s)!`/m || $data =~ /^[ \t]*```!/m);
    }
    print "$count\n";
  '
  out="$(files "$dir" | perl -e "$scan" "$dir")" || problem "the file scan failed"
  collect "$out"
  while IFS= read -r line; do
    problem "$dir/.claude-plugin/plugin.json: $line"
  done < <(jq -r '(keys_unsorted - ["$schema", "name", "displayName", "version", "description", "author", "homepage", "repository", "license", "keywords", "skills", "agents", "outputStyles", "defaultEnabled", "dependencies", "metadata", "userConfig"])[]
    | "key \(.) is outside the allowlist in check_directory_policy, which leaves out every key that can run code and the listing keys (icon and the *Url fields): the directory reads those only at the first submission and reports them on every later scan"' "$dir/.claude-plugin/plugin.json" 2>&1)
  for f in README.md LICENSE; do
    regular "$dir/$f" || problem "$dir/$f is missing"
  done
  words="$(perl -0777 -ne 's/^[ \t]*```.*?^[ \t]*```[^\n]*$//msg; my @w = split; print scalar @w' "$dir/README.md" 2>/dev/null)"
  [ "${words:-0}" -ge 40 ] || problem "$dir/README.md: ${words:-0} words outside code blocks, and the directory wants at least 40"
  while IFS= read -r -d '' f; do
    grep -Eq '(^|[[:space:]])(export-ignore|export-subst|filter=)' "$f" &&
      problem "$f: export-ignore, export-subst, or filter changes the files the directory fetches"
  done < <(files .gitattributes '*/.gitattributes')
  finish directory-policy "$count files under $dir: allowed types and names only, complete images, every file under 5 MiB, UTF-8 text without NUL or #!, no hook, workflow, server, shell injection, or package manager file; frontmatter and manifest keys allowlisted; text free of launcher and download tool names; entry files free of uppercase variable reads; README (40 words outside code) and LICENSE present"
}

check_workflows() {
  local version out parse
  version="$(node --version 2>/dev/null)"
  if [ -z "$version" ]; then
    skip workflows "node not installed"
    return
  fi
  parse='
    const fs = require("node:fs");
    const vm = require("node:vm");
    const gap = /(?:\s|\/\/[^\n]*|\/\*[\s\S]*?\*\/)*/y;
    const head = /export\s+const\s+meta\s*=/y;
    const str = /"(?:[^"\\\n\r]|\\[\s\S])*"|\x27(?:[^\x27\\\n\r]|\\[\s\S])*\x27/y;
    const num = /-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?(?![\w$.])/y;
    const word = /(?:true|false|null)(?![\w$])/y;
    const key = /[A-Za-z_$][\w$]*/y;
    const more = /[(\[.\x60+\-*\/%=<>&|^?,]|!=|in(?:stanceof)?(?![\w$])/y;
    const plain = "export const meta must be a plain literal: strings, numbers, true, false, null, and arrays and objects of them with plain keys";
    function lint(src) {
      let i = 0;
      const eat = (re) => {
        re.lastIndex = i;
        const ok = re.test(src);
        if (ok) i = re.lastIndex;
        return ok;
      };
      const fail = (why) => {
        throw new Error(src.slice(0, i).split("\n").length + ": " + why);
      };
      const list = (close, item) => {
        for (;;) {
          eat(gap);
          if (src[i] === close) {
            i++;
            return;
          }
          item();
          eat(gap);
          if (src[i] === ",") i++;
          else if (src[i] !== close) fail(plain);
        }
      };
      const value = () => {
        eat(gap);
        if (src[i] === "{") {
          i++;
          list("}", () => {
            if (!(eat(str) || eat(num) || eat(key))) fail(plain);
            eat(gap);
            if (src[i] !== ":") fail(plain);
            i++;
            value();
          });
        } else if (src[i] === "[") {
          i++;
          list("]", value);
        } else if (!(eat(str) || eat(num) || eat(word))) fail(plain);
      };
      eat(gap);
      const start = i;
      if (!eat(head)) fail("the first statement must be export const meta = { ... }");
      try {
        new vm.Script("(async function () {" + src.slice(0, start) + "      " + src.slice(start + 6) + "\n})", { filename: "workflow" });
      } catch (err) {
        const line = /^workflow:(\d+)$/m.exec(String(err.stack));
        throw new Error((line ? line[1] : "?") + ": " + err.message);
      }
      value();
      const close = i;
      eat(gap);
      if (src[i] !== ";" && i < src.length && !(/[\n\r]/.test(src.slice(close, i)) && !eat(more))) {
        fail("export const meta must end at its literal; add a semicolon after it");
      }
    }
    let count = 0;
    for (const file of fs.readFileSync(0, "utf8").split("\0")) {
      if (!file || !fs.lstatSync(file, { throwIfNoEntry: false })?.isFile()) continue;
      count++;
      try {
        lint(fs.readFileSync(file, "utf8"));
      } catch (err) {
        const line = file + ":" + err.message;
        console.log(line.replace(/\s+/g, " ").replace(/[^ -~]/g, (c) => "\\u" + c.charCodeAt(0).toString(16).padStart(4, "0")));
      }
    }
    console.log(count);
  '
  out="$(files ':(glob)plugins/sutra-harness/workflows/*.js' | node -e "$parse")" || problem "node failed"
  collect "$out"
  finish workflows "plugins/sutra-harness/workflows/*.js ($count) compiled inside an async function, each led by a plain-literal export const meta (node $version)"
}

check_hook_tests() { # check_hook_tests SHELL
  local out
  if out="$(BASH_UNDER_TEST="$1" bash tests/hooks.sh 2>&1 </dev/null)"; then
    finish hook-tests "$(printf '%s\n' "$out" | tail -n 1)"
  else
    problem "$out"
    finish hook-tests "tests/hooks.sh failed with the hook under $1"
  fi
}

check_ascii
check_json
check_yaml
check_bash_syntax
check_shellcheck
check_frontmatter
check_manifests
check_plugin_limits
check_directory_policy
check_workflows
check_hook_tests bash
# macOS ships bash 3.2 as /bin/bash, and the hook must run under it.
if [ -x /bin/bash ] && [ "$(/bin/bash -c 'echo "$BASH_VERSION"')" != "$(bash -c 'echo "$BASH_VERSION"')" ]; then
  check_hook_tests /bin/bash
fi

printf 'scripts/check.sh: %d ok, %d failed, %d skipped\n' "$passed" "$failed" "$skipped"
[ "$failed" -eq 0 ]
