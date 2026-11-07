#!/usr/bin/env bash
#
# empty-test-detector.sh -- opt-in Claude Code PostToolUse hook (non-blocking).
#
# Warns when a file Claude just wrote looks like a test file that defines a
# test but contains no assertion anywhere. A coarse, whole-file heuristic: a
# TEMPLATE to adapt to your language and test framework, not a parser. A file
# where one test asserts and another does not stays quiet.
#
# Input: the PostToolUse payload on stdin. The path comes from
# tool_input.file_path (Write, Edit) or tool_input.notebook_path (NotebookEdit),
# read with jq, or with perl's JSON::PP when jq is missing. A git hook gets no
# payload, so this runs only as a Claude Code hook.
# Output: on a finding, one JSON object with a systemMessage for the user and
# additionalContext for Claude. It never blocks and always exits 0: the write
# has already happened when a PostToolUse hook runs.
#
# Knobs (environment variables, extended regexes):
#   TEST_FILE_REGEX  matched against the path relative to the project: is this
#                    a test file? Default: a name that ends in _test.EXT,
#                    _spec.EXT, .test.EXT or .spec.EXT, or starts with test_
#                    (foo_test.go, app.test.ts, test_foo.py, foo_spec.rb).
#   TEST_DEF_REGEX   does the file define a test? Default: def test...,
#                    func Test..., @Test, it(, test(, describe(, ...
#   ASSERT_REGEX     does the file contain an assertion? Default: assert,
#                    expect, require, should, must, check, verify, Fatal,
#                    Error, Fail, XCTFail.
#
# Every failure -- no input, unparseable JSON, unreadable file, no jq or
# JSON::PP, an invalid regex -- exits 0 with no output.

set -u
export LC_ALL=C

TEST_FILE_REGEX="${TEST_FILE_REGEX:-(_test|_spec|\.test|\.spec)\.[^/]+$|(^|/)test_[^/]+$}"
ASSERT_REGEX="${ASSERT_REGEX:-(assert|expect|require|should|must|check|verify|Fatal|Error|Fail|XCTFail)}"
TEST_DEF_REGEX="${TEST_DEF_REGEX:-(def[[:space:]]+test|func[[:space:]]+Test|@Test|(^|[^[:alnum:]_])(it|test|describe|context|scenario)[[:space:]]*\()}"

[[ "" =~ $TEST_FILE_REGEX ]]
[ "$?" -ne 2 ] || exit 0

[ -t 0 ] && exit 0
payload="$(cat 2>/dev/null)"
[ -n "$payload" ] || exit 0

have_jq=0
command -v jq >/dev/null 2>&1 && have_jq=1

# fields prints tool_input.file_path, tool_input.notebook_path and cwd from the
# payload, each NUL-terminated.
fields() {
  if [ "$have_jq" = 1 ]; then
    printf '%s' "$payload" | jq -j '
      def s(f): (try f catch null) | if type == "string" then split("\u0000") | join("") else "" end;
      s(.tool_input.file_path), "\u0000", s(.tool_input.notebook_path), "\u0000", s(.cwd), "\u0000"' 2>/dev/null
  else
    printf '%s' "$payload" | perl -MJSON::PP -e '
      my $d = eval { JSON::PP->new->utf8->decode(do { local $/; <STDIN> }) };
      exit 0 unless ref $d eq "HASH";
      my $in = ref $d->{tool_input} eq "HASH" ? $d->{tool_input} : {};
      for my $v ($in->{file_path}, $in->{notebook_path}, $d->{cwd}) {
        $v = "" if !defined $v || ref $v;
        utf8::encode($v);
        $v =~ tr/\0//d;
        print $v, "\0";
      }' 2>/dev/null
  fi
}

# emit MESSAGE prints the warning as one JSON object.
emit() {
  if [ "$have_jq" = 1 ]; then
    jq -cn --arg msg "$1" '{systemMessage: $msg, hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $msg}}'
  else
    perl -MJSON::PP -e '
      my $msg = $ARGV[0];
      utf8::decode($msg);
      print JSON::PP->new->ascii->canonical->encode({ systemMessage => $msg,
        hookSpecificOutput => { hookEventName => "PostToolUse", additionalContext => $msg } }), "\n";' -- "$1"
  fi
}

vals=()
while IFS= read -r -d '' v; do vals+=("$v"); done < <(fields)
file="${vals[0]:-}"
[ -n "$file" ] || file="${vals[1]:-}"
cwd="${vals[2]:-}"
[ -n "$file" ] && [ -f "$file" ] && [ -r "$file" ] || exit 0

rel="$file"
for base in "${CLAUDE_PROJECT_DIR:-}" "$cwd"; do
  [ -n "$base" ] || continue
  case "$file" in "$base"/*) rel="${file#"$base"/}"; break ;; esac
done
[[ $rel =~ $TEST_FILE_REGEX ]] || exit 0

grep -Eq -e "$TEST_DEF_REGEX" -- "$file" 2>/dev/null || exit 0
grep -Eq -e "$ASSERT_REGEX" -- "$file" 2>/dev/null
[ "$?" -eq 1 ] || exit 0

label="$(printf '%s' "$rel" | tr '\001-\037\177' '[?*]')"
emit "empty-test-detector: $label looks like a test file with no assertion (assert, expect, require, should, ...). The check is coarse and whole-file; verify by hand." 2>/dev/null
exit 0
