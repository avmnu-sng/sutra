#!/usr/bin/env bash
# The repository checks CI runs, for contributors to run before a PR:
#   bash scripts/check.sh
# Checks tracked files plus untracked files git does not ignore. Needs git, jq
# and perl. Without shellcheck, or python3 with PyYAML, that check prints a skip
# line; under CI=true a skipped check fails instead.

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
      "docs/demo.gif"                 => "GIF8",
      "plugins/sutra/assets/icon.png" => "\x89PNG\r\n\x1a\n",
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
  finish ascii "$count files scanned for NUL, control and non-ASCII bytes; allowlisted binaries: docs/demo.gif, plugins/sutra/assets/icon.png"
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

check_plugin_limits() {
  local f n=0 size line
  local hooks=plugins/sutra/hooks/hooks.json manifest=plugins/sutra/.claude-plugin/plugin.json
  shopt -s nocasematch
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
  done < <(files plugins/sutra)
  shopt -u nocasematch
  [ "$n" -gt 0 ] || problem "no files under plugins/sutra"
  [ "$n" -le 512 ] || problem "plugins/sutra: $n files, and the limit is 512"
  local bad_commands='
    [.. | objects | .command? | strings][]
    | select(test("[.][.]")
        or (gsub("[$][{]CLAUDE_PLUGIN_ROOT[}]"; "ROOT")
            | test("[$`]|(^|[^A-Za-z0-9_.-])[/~]")))
    | "command holds .., an absolute path, or a variable or command substitution other than ${CLAUDE_PLUGIN_ROOT}: \(.)"'
  local bad_paths='
    paths(strings) as $p
    | getpath($p)
    | select(test("^(/|~|[A-Za-z]:[\\\\/])") or test("(^|[\\\\/])\\.\\.([\\\\/]|$)"))
    | "\($p | map(tostring) | join(".")) is absolute or climbs with ..: \(.)"'
  while IFS= read -r line; do
    problem "$hooks: $line"
  done < <(jq -r "$bad_commands" "$hooks" 2>&1)
  while IFS= read -r line; do
    problem "$manifest: $line"
  done < <(jq -r "$bad_paths" "$manifest" 2>&1)
  finish plugin-limits "$n files under plugins/sutra (limit 512); file sizes, symlinks, hook commands and manifest paths checked"
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
check_plugin_limits
check_hook_tests bash
# macOS ships bash 3.2 as /bin/bash, and the hook must run under it.
if [ -x /bin/bash ] && [ "$(/bin/bash -c 'echo "$BASH_VERSION"')" != "$(bash -c 'echo "$BASH_VERSION"')" ]; then
  check_hook_tests /bin/bash
fi

printf 'scripts/check.sh: %d ok, %d failed, %d skipped\n' "$passed" "$failed" "$skipped"
[ "$failed" -eq 0 ]
