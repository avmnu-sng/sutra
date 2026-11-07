#!/usr/bin/env bash
#
# source-change-requires-test.sh -- opt-in example hook: a commit that changes
# product source should change a test too.
#
# A TEMPLATE: copy it, tune the regexes for your layout, and wire it one of the
# two ways in examples/hooks/README.md. What arrives on stdin picks the way:
#
#   git pre-commit hook (the reliable form). git gives the hook no input, and
#   it checks the exact index being committed. Block mode exits 1, which aborts
#   the commit; warn mode reports on stderr and exits 0.
#
#   Claude Code PreToolUse hook on Bash. It reads tool_input.command from the
#   JSON payload and stands aside unless the command runs
#   "git [global options] commit" in the repository that holds
#   $CLAUDE_PROJECT_DIR. It checks the index as it stands before the command
#   runs, plus tracked changes for commit -a, plus the whole working tree when
#   the same command also runs git add. Block mode prints a permissionDecision
#   "deny" whose reason Claude sees; warn mode prints a systemMessage and
#   additionalContext. It always exits 0.
#
# Tooling gaps -- no git, not a repository, no CLAUDE_PROJECT_DIR for a
# PreToolUse payload, no jq or perl JSON::PP to read the payload, an invalid
# regex -- exit 0 with no output.
#
# Knobs (environment variables):
#   MODE                  warn (default) or block.
#   TEST_PATH_REGEX       extended regex for paths that count as tests, e.g.
#                           Ruby/RSpec ..... '(^|/)spec/|_spec\.rb$'
#                           JS/Jest ........ '(^|/)__tests__/|\.(test|spec)\.[jt]sx?$'
#                           Go ............. '_test\.go$'
#                           Python/pytest .. '(^|/)tests?/|(^|/)test_[^/]*\.py$|_test\.py$'
#   SOURCE_EXCLUDE_REGEX  extended regex for paths that are not product source
#                         (docs, config, lockfiles, CI, assets). A change
#                         limited to these never triggers the rule.
#   RANGE                 a revision range to check instead of the index, e.g.
#                         origin/main...HEAD or HEAD~1.

set -u
export LC_ALL=C GIT_OPTIONAL_LOCKS=0

MODE="${MODE:-warn}"
TEST_PATH_REGEX="${TEST_PATH_REGEX:-(^|/)(spec|tests?|__tests__)/|(_spec|_test|\.test|\.spec)\.[A-Za-z0-9]+$}"
SOURCE_EXCLUDE_REGEX="${SOURCE_EXCLUDE_REGEX:-(^|/)(docs?|examples?|\.github|\.githooks|vendor|node_modules|dist|build)/|(^|/)(README|CHANGELOG|LICENSE|CONTRIBUTING)|\.(md|markdown|txt|rst|adoc)$|\.(ya?ml|toml|ini|cfg|conf|json|lock)$|(^|/)(Dockerfile|Makefile|Taskfile\.ya?ml|Gemfile|Gemfile\.lock|package\.json|package-lock\.json|yarn\.lock|go\.mod|go\.sum)$|\.(png|jpe?g|gif|svg|ico|webp|pdf)$}"
RANGE="${RANGE:-}"

command -v git >/dev/null 2>&1 || exit 0
case "$RANGE" in -*) exit 0 ;; esac
for re in "$TEST_PATH_REGEX" "$SOURCE_EXCLUDE_REGEX"; do
  [[ "" =~ $re ]]
  [ "$?" -ne 2 ] || exit 0
done

have_jq=0
command -v jq >/dev/null 2>&1 && have_jq=1

# fields prints hook_event_name, tool_input.command and cwd from the payload,
# each NUL-terminated.
fields() {
  if [ "$have_jq" = 1 ]; then
    printf '%s' "$payload" | jq -j '
      def s(f): (try f catch null) | if type == "string" then split("\u0000") | join("") else "" end;
      s(.hook_event_name), "\u0000", s(.tool_input.command), "\u0000", s(.cwd), "\u0000"' 2>/dev/null
  else
    printf '%s' "$payload" | perl -MJSON::PP -e '
      my $d = eval { JSON::PP->new->utf8->decode(do { local $/; <STDIN> }) };
      exit 0 unless ref $d eq "HASH";
      my $in = ref $d->{tool_input} eq "HASH" ? $d->{tool_input} : {};
      for my $v ($d->{hook_event_name}, $in->{command}, $d->{cwd}) {
        $v = "" if !defined $v || ref $v;
        utf8::encode($v);
        $v =~ tr/\0//d;
        print $v, "\0";
      }' 2>/dev/null
  fi
}

# emit MODE REPORT prints the PreToolUse answer as one JSON object.
emit() {
  if [ "$have_jq" = 1 ]; then
    jq -cn --arg mode "$1" --arg msg "$2" '
      if $mode == "block" then
        {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $msg}}
      else
        {systemMessage: $msg, hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $msg}}
      end'
  else
    perl -MJSON::PP -e '
      my ($mode, $msg) = @ARGV;
      utf8::decode($msg);
      my $o = $mode eq "block"
        ? { hookSpecificOutput => { hookEventName => "PreToolUse", permissionDecision => "deny", permissionDecisionReason => $msg } }
        : { systemMessage => $msg, hookSpecificOutput => { hookEventName => "PreToolUse", additionalContext => $msg } };
      print JSON::PP->new->ascii->canonical->encode($o), "\n";' -- "$1" "$2"
  fi
}

# git_in DIR ARGS... runs git in DIR. core.fsmonitor stays off: a repository's
# configuration can name a program there, and git starts it on reading the
# index.
git_in() {
  local d="$1"
  shift
  git -c core.fsmonitor=false -C "$d" "$@"
}

# resolve DIR PATH prints the physical directory PATH names, taken relative to
# DIR.
resolve() {
  local p="$2"
  case "$p" in
    \~) p="${HOME:-}" ;;
    \~/*) p="${HOME:-}/${p#\~/}" ;;
    /*) ;;
    *) p="$1/$p" ;;
  esac
  [ -n "$p" ] || return 1
  (cd -P -- "$p" 2>/dev/null && pwd -P)
}

# in_repo DIR succeeds when DIR lies inside the repository at $top and not in a
# repository nested inside it.
in_repo() {
  local d="$1"
  case "$d/" in "$top"/*) ;; *) return 1 ;; esac
  while [ "$d" != "$top" ]; do
    [ -e "$d/.git" ] && return 1
    d="${d%/*}"
  done
  return 0
}

# quote_state WORD carries QS, the quote character left open, across WORD.
quote_state() {
  local dq='"' sq="'" q c
  q="${1//[!$dq$sq]/}"
  while [ -n "$q" ]; do
    c="${q:0:1}"
    q="${q:1}"
    if [ -z "$QS" ]; then QS="$c"; elif [ "$c" = "$QS" ]; then QS=""; fi
  done
}

# take I sets N to the index after the shell word that starts at words[I], so a
# quoted argument that held spaces counts as one word. take I w also sets W to
# that word with its quotes removed. bash removes them in quadratic time, so
# only the callers that read W ask for it.
take() {
  local i="$1" w="${words[$1]:-}" dq='"' sq="'"
  QS=""
  quote_state "$w"
  while [ -n "$QS" ] && [ $((i + 1)) -lt "$n" ]; do
    i=$((i + 1))
    w="$w ${words[$i]}"
    quote_state "${words[$i]}"
  done
  N=$((i + 1))
  [ -z "${2:-}" ] || W="${w//[$dq$sq]/}"
}

# commit_flags I reads the arguments of "git commit" from words[I] on and sets
# with_tracked for -a / --all.
commit_flags() {
  local i="$1" c
  while [ "$i" -lt "$n" ]; do
    case "${words[$i]}" in
      --) return 0 ;;
      -a|--all) with_tracked=1 ;;
      -m|-F|-C|-c|-t|--message|--file|--reuse-message|--reedit-message|--template|--author|--date|--fixup|--squash|--cleanup|--trailer|--pathspec-from-file)
        take $((i + 1))
        i=$((N - 1)) ;;
      --*) ;;
      -?*)
        c="${words[$i]#-}"
        while [ -n "$c" ]; do
          case "$c" in
            a*) with_tracked=1 ;;
            [mFCct]) take $((i + 1)); i=$((N - 1)); break ;;
            [mFCctSu]*) break ;;
          esac
          c="${c#?}"
        done ;;
    esac
    i=$((i + 1))
  done
}

# split_commands prints each command on its own line: it splits at ; & | ( )
# and backquotes outside quotes, drops comments and here-document bodies, and
# joins the lines that an open quote or a trailing backslash continues. Inside
# (( )) a << is a shift, not a here-document.
split_commands() {
  awk -v sq="'" '
    function heredoc(j,   s, w, d, qq) {
      s = 0
      if (c[j] == "-") { s = 1; j++ }
      while (c[j] == " " || c[j] == "\t") j++
      for (w = ""; j <= n; j++) {
        d = c[j]
        if (qq != "") { if (d == qq) qq = ""; else w = w d }
        else if (d == "\"" || d == sq) qq = d
        else if (d == "\\" && j < n) w = w c[++j]
        else if (index(" \t;&|<>()`", d)) break
        else w = w d
      }
      if (w != "") { hd[++pend] = w; strip[pend] = s }
      return j - 1
    }
    nh {
      l = $0
      if (strip[cur]) sub(/^\t+/, "", l)
      if (l == hd[cur] && ++cur > nh) nh = 0
      next
    }
    {
      n = split($0, c, ""); seg = 1
      for (i = 1; i <= n; i++) {
        ch = c[i]
        if (ch == "\\" && q != sq) {
          if (i == n) { cont = 1; break }
          printf "%s%s", ch, c[++i]
          continue
        }
        if (q == "") {
          if (ch == "\"" || ch == sq) q = ch
          else if (ch == "#" && (i == seg || c[i - 1] == " " || c[i - 1] == "\t")) break
          else if (ch c[i + 1] == "((") { arith++; ch = "\n\n"; seg = ++i + 1 }
          else if (ch c[i + 1] == "))" && arith) { arith--; ch = "\n\n"; seg = ++i + 1 }
          else if (ch c[i + 1] c[i + 2] == "<<<") { ch = "<<<"; i += 2 }
          else if (ch c[i + 1] == "<<" && !arith) { i = heredoc(i + 2); ch = " " }
          else if (index(";&|()`", ch)) { ch = "\n"; seg = i + 1 }
        } else if (ch == q) q = ""
        printf "%s", ch
      }
      if (cont || q != "") { cont = 0; open = 1; printf " "; next }
      open = 0
      printf "\n"
      if (pend) { nh = pend; pend = 0; cur = 1 }
    }
    END { if (open) printf "\n" }'
}

# unquote prints its input with one level of quotes and backslashes removed:
# the command that eval runs.
unquote() {
  awk -v sq="'" '
    {
      n = split($0, c, "")
      for (i = 1; i <= n; i++) {
        ch = c[i]
        if (q == "" && (ch == "\"" || ch == sq)) q = ch
        else if (ch == q) q = ""
        else if (ch == "\\" && q != sq && i < n) printf "%s", c[++i]
        else printf "%s", ch
      }
      printf "\n"
    }'
}

# scan_command succeeds when $cmd runs "git [global options] commit" in the
# repository at $top. It follows cd, git -C and eval as text only: running git
# in a directory the command names would let that repository's configuration
# start a program before the user has approved the command.
scan_command() {
  local dir="$start" found=1
  scan_text "$cmd"
  return "$found"
}

# scan_text TEXT reads the commands in TEXT for scan_command, updating its dir
# and found.
scan_text() {
  local line tdir cw words n i
  while IFS= read -r line; do
    words=()
    read -r -a words <<< "$line"
    n=${#words[@]}
    i=0
    while [ "$i" -lt "$n" ]; do
      case "${words[$i]}" in
        [A-Za-z_]*=*|'!'|'{'|if|elif|then|do|else|while|until|time|command|builtin|exec|nohup|env|nice|sudo|xargs) take "$i"; i=$N ;;
        *) break ;;
      esac
    done
    [ "$i" -lt "$n" ] || continue
    take "$i" w
    i=$N
    cw="${W//\\/}"
    case "$cw" in
      eval)
        [ "$i" -ge "$n" ] || scan_text "$(printf '%s\n' "${words[*]:$i}" | unquote)" ;;
      cd)
        if [ "$i" -lt "$n" ]; then take "$i" w; else W="~"; fi
        case "$W" in
          -*) dir="" ;;
          *) [ -z "$dir" ] || dir="$(resolve "$dir" "$W")" ;;
        esac ;;
      git|*/git)
        tdir="$dir"
        while [ "$i" -lt "$n" ]; do
          case "${words[$i]}" in
            -C) take $((i + 1)) w; i=$N; [ -z "$tdir" ] || tdir="$(resolve "$tdir" "$W")" ;;
            -c|--namespace|--config-env|--attr-source) take $((i + 1)); i=$N ;;
            --git-dir|--work-tree) take $((i + 1)); i=$N; tdir="" ;;
            --git-dir=*|--work-tree=*) i=$((i + 1)); tdir="" ;;
            -*) i=$((i + 1)) ;;
            *) break ;;
          esac
        done
        if [ "$i" -ge "$n" ] || [ -z "$tdir" ] || ! in_repo "$tdir"; then
          continue
        fi
        case "${words[$i]}" in
          add|stage) with_tracked=1; with_untracked=1 ;;
          commit) found=0; commit_flags $((i + 1)) ;;
        esac ;;
    esac
  done < <(printf '%s\n' "$1" | split_commands |
    grep -E '(^|[^[:alnum:]_.-])(cd|git|eval)([^[:alnum:]_.-]|$)')
}

changed_files() {
  if [ -n "$RANGE" ]; then
    git_in "$top" diff --name-only -z "$RANGE" -- 2>/dev/null
    return 0
  fi
  git_in "$top" diff --cached --name-only -z 2>/dev/null
  [ "$with_tracked" = 0 ] || git_in "$top" diff --name-only -z 2>/dev/null
  [ "$with_untracked" = 0 ] || git_in "$top" ls-files -z --others --exclude-standard 2>/dev/null
}

payload=""
[ -t 0 ] || payload="$(cat 2>/dev/null)"

with_tracked=0
with_untracked=0
if [ -n "$payload" ]; then
  case "$payload" in *commit*) ;; *) exit 0 ;; esac
  vals=()
  while IFS= read -r -d '' v; do vals+=("$v"); done < <(fields)
  event="${vals[0]:-}"
  cmd="${vals[1]:-}"
  start="${vals[2]:-}"
  [ -z "$event" ] || [ "$event" = PreToolUse ] || exit 0
  case "$cmd" in *commit*) ;; *) exit 0 ;; esac
  # The repository comes from the project, never from the payload cwd: Claude
  # can cd into a nested repository, and git would run its configuration.
  [ -n "${CLAUDE_PROJECT_DIR:-}" ] || exit 0
  proj="$(cd -P -- "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)" || exit 0
  top="$(git_in "$proj" rev-parse --show-toplevel 2>/dev/null)" || exit 0
  top="$(cd -P -- "$top" 2>/dev/null && pwd -P)" || exit 0
  [ -n "$start" ] && [ -d "$start" ] || start="$proj"
  start="$(cd -P -- "$start" 2>/dev/null && pwd -P)" || exit 0
  scan_command || exit 0
else
  top="$(git_in . rev-parse --show-toplevel 2>/dev/null)" || exit 0
fi

count=0
listed=""
seen="
"
while IFS= read -r -d '' path; do
  [[ $path =~ $TEST_PATH_REGEX ]] && exit 0
  [[ $path =~ $SOURCE_EXCLUDE_REGEX ]] && continue
  case "$seen" in *"
$path
"*) continue ;; esac
  seen="$seen$path
"
  count=$((count + 1))
  [ "$count" -gt 10 ] || listed="$listed
  - $(printf '%s' "$path" | tr '\001-\037\177' '[?*]')"
done < <(changed_files)
[ "$count" -gt 0 ] || exit 0

report="source-change-requires-test: product source changed, but no test did.
Source files with no matching test change:$listed"
[ "$count" -le 10 ] || report="$report
  - and $((count - 10)) more"
[ "$with_untracked" = 0 ] || report="$report
This command stages files and commits in one step, so every change in the working tree was counted. Stage first, then commit, for an exact check."
report="$report
Add or update a test that exercises the change, or record in the commit message why no test applies. Tune with TEST_PATH_REGEX, SOURCE_EXCLUDE_REGEX, RANGE and MODE."

if [ -z "$payload" ]; then
  printf '%s\n' "$report" >&2
  [ "$MODE" = block ] && exit 1
  exit 0
fi
emit "$MODE" "$report" 2>/dev/null
exit 0
