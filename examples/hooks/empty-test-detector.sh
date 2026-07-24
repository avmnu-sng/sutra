#!/usr/bin/env bash
#
# empty-test-detector.sh -- OPT-IN PostToolUse hook (non-blocking).
#
# Warns when a just-written test file appears to define a test but contains
# no assertion anywhere. This is a coarse, whole-file heuristic meant as a
# TEMPLATE you adapt to your language and test framework -- not a turnkey
# parser. It never blocks a tool call and always exits 0.
#
# ---------------------------------------------------------------------------
# What it does
# ---------------------------------------------------------------------------
# Claude Code invokes a PostToolUse hook AFTER a tool runs, passing a JSON
# event on stdin. For a file-writing tool (Write/Edit/etc.) that JSON carries
# the path that was written. This script:
#
#   1. Reads the JSON from stdin.
#   2. Extracts the written file path (sed only -- no jq dependency).
#   3. No-ops unless the path looks like a test file (TEST_FILE_REGEX).
#   4. If the file looks like it defines a test but no assertion token
#      (ASSERT_REGEX) appears anywhere in it, emits a JSON systemMessage
#      warning that names the file.
#   5. Exits 0 no matter what.
#
# ---------------------------------------------------------------------------
# Install (opt-in)
# ---------------------------------------------------------------------------
# Wire it into your project or user settings.json under hooks.PostToolUse,
# matching the file-writing tools you care about. Example:
#
#   {
#     "hooks": {
#       "PostToolUse": [
#         {
#           "matcher": "Write|Edit",
#           "hooks": [
#             { "type": "command",
#               "command": "/absolute/path/to/empty-test-detector.sh" }
#           ]
#         }
#       ]
#     }
#   }
#
# ---------------------------------------------------------------------------
# Tuning (environment variables)
# ---------------------------------------------------------------------------
# Override either regex without editing this file:
#
#   TEST_FILE_REGEX  Extended-regex deciding whether a path is a test file.
#                    Default matches common conventions across languages:
#                      _test   .test.   test_   spec
#                    e.g. foo_test.go, app.test.ts, test_foo.py, foo_spec.rb
#
#   ASSERT_REGEX     Extended-regex for "this file contains an assertion".
#                    Default covers common assertion / expectation / fatal
#                    helpers: assert, expect, require, should, must,
#                    check, verify, and fail/error-style fatals (t.Fatal,
#                    t.Error, XCTFail, ...).
#
#   TEST_DEF_REGEX   Extended-regex for "this file defines a test". Default
#                    matches typical test declarations across languages
#                    (def test..., func Test..., it(, test(, @Test, ...).
#                    Tune this to cut false positives in your ecosystem.
#
# Because the heuristic is whole-file, a file where ONE test asserts and
# ANOTHER does not will NOT warn. A real per-language version should parse
# each test body and check assertions per test. Treat this script as the
# starting scaffold for that.
#
# ---------------------------------------------------------------------------
# Graceful degradation
# ---------------------------------------------------------------------------
# Every failure mode -- missing stdin, unparseable JSON, unreadable file,
# absent tools -- falls through to a clean exit 0 with no output. A hook
# should never be the reason a test run or edit is disrupted.
# ---------------------------------------------------------------------------

# Do not let an unexpected error take the hook (and thus the tool call) down.
set -u

# Configurable heuristics. Override via env; defaults below.
TEST_FILE_REGEX="${TEST_FILE_REGEX:-(_test|\.test\.|(^|/)test_|spec)}"
ASSERT_REGEX="${ASSERT_REGEX:-(assert|expect|require|should|must|check|verify|Fatal|Error|Fail|XCTFail)}"
TEST_DEF_REGEX="${TEST_DEF_REGEX:-(def[[:space:]]+test|func[[:space:]]+Test|@Test|(^|[^[:alnum:]])(it|test|describe|context|scenario)[[:space:]]*\()}"

# Read the whole PostToolUse JSON event from stdin. If nothing is piped in
# (e.g. run by hand), do not hang -- bail out cleanly.
if [ -t 0 ]; then
  exit 0
fi
payload="$(cat 2>/dev/null || true)"
[ -n "${payload}" ] || exit 0

# Extract the written file path WITHOUT jq. PostToolUse events expose the
# path under tool_input (the arguments the tool was called with). Different
# tools name it differently, so try the common keys in order:
#   file_path  -> Write/Edit/MultiEdit
#   path       -> some file tools
#   notebook_path -> NotebookEdit
#
# grep -o pulls the first "key": "value" match; sed peels off the value.
# This is intentionally forgiving: any miss just yields an empty path and a
# clean exit below.
extract_path() {
  key="$1"
  printf '%s' "${payload}" \
    | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -n 1 \
    | sed -E "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/"
}

file_path="$(extract_path file_path)"
[ -n "${file_path}" ] || file_path="$(extract_path path)"
[ -n "${file_path}" ] || file_path="$(extract_path notebook_path)"

# Unescape the two escape sequences that legitimately appear in JSON paths:
# escaped forward slashes and backslashes. Good enough for filesystem paths.
file_path="$(printf '%s' "${file_path}" | sed -e 's#\\/#/#g' -e 's#\\\\#\\#g')"

# No path, or the file is gone / unreadable -> nothing to inspect.
[ -n "${file_path}" ] || exit 0
[ -f "${file_path}" ] || exit 0
[ -r "${file_path}" ] || exit 0

# Only look at files whose PATH looks like a test file. Everything else is
# out of scope for this hook.
printf '%s' "${file_path}" | grep -Eq "${TEST_FILE_REGEX}" || exit 0

# Whole-file scan. Read once; if it is unreadable for any reason, bail.
contents="$(cat "${file_path}" 2>/dev/null || true)"
[ -n "${contents}" ] || exit 0

# Does the file even look like it defines a test? If not, stay quiet -- a
# helpers/fixtures file living under a test path is not a finding.
printf '%s' "${contents}" | grep -Eq "${TEST_DEF_REGEX}" || exit 0

# Does an assertion token appear ANYWHERE in the file? If yes, assume the
# file is fine (coarse heuristic -- see the note in the header about
# per-test scanning).
if printf '%s' "${contents}" | grep -Eq "${ASSERT_REGEX}"; then
  exit 0
fi

# Reaching here: the file looks like a test file, defines at least one test,
# and contains no recognizable assertion. Emit a non-blocking warning.
#
# A JSON object on stdout with a systemMessage surfaces the note to the user
# without blocking. We keep the message on one line and escape the only
# characters that matter for a JSON string literal: backslash and
# double-quote. (Paths rarely contain either, but escape defensively.)
escaped_path="$(printf '%s' "${file_path}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"

printf '{"systemMessage":"empty-test-detector: %s looks like a test file with no assertion (assert/expect/require/should/...). Heuristic is coarse and whole-file; verify manually."}\n' \
  "${escaped_path}"

# Always succeed. A warning is advisory, never a gate.
exit 0
