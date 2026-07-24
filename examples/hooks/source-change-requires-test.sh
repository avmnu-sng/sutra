#!/usr/bin/env bash
#
# source-change-requires-test.sh
# -----------------------------------------------------------------------------
# OPT-IN example hook: "source changes ship with a test change".
#
# Enforces a simple team convention -- if a commit touches product source code
# but touches nothing under the test tree, that is usually a missing test.
# This hook detects that shape and either warns or blocks.
#
# It is intentionally a TEMPLATE. Copy it, tune the regexes for your layout,
# and wire it in one of the two supported ways (see "WIRING" below). Every
# tunable is an environment variable with a safe default, so you can override
# per-repo or per-invocation without editing the script.
#
# DESIGN NOTES
#   * Graceful degradation: if this is not a git repo, or git is missing, the
#     hook exits 0 (allow). A tooling gap must never block a commit.
#   * Safe default mode is "warn" -- it prints guidance and exits 0. Flip to
#     "block" only once the team has agreed to a hard gate.
#   * The changed-file set defaults to the staged diff, which is what both a
#     git pre-commit hook and a commit-time agent hook care about.
#
# EXIT STATUS
#   0  -> allow (no violation, OR violation in warn mode, OR graceful skip)
#   2  -> block (violation in block mode)
# -----------------------------------------------------------------------------

set -euo pipefail

# =============================================================================
# EXTENSION POINTS -- override any of these via the environment.
# =============================================================================

# MODE: "warn" (default, exit 0) or "block" (exit non-zero on violation).
#   Start with "warn" while the team adjusts; switch to "block" to enforce.
MODE="${MODE:-warn}"

# TEST_PATH_REGEX: an extended-regex (ERE) matching paths that COUNT AS TESTS.
#   A changed path matching this is a test change and satisfies the rule.
#   Tune this to your project's test layout. Examples:
#     Ruby/RSpec ..... '(^|/)spec/|_spec\.rb$'
#     JS/Jest ........ '(^|/)__tests__/|\.(test|spec)\.[jt]sx?$'
#     Go ............. '_test\.go$'
#     Python/pytest .. '(^|/)tests?/|(^|/)test_[^/]*\.py$|_test\.py$'
TEST_PATH_REGEX="${TEST_PATH_REGEX:-(^|/)(spec|tests?|__tests__)/|(_spec|_test|\.test|\.spec)\.[A-Za-z0-9]+$}"

# SOURCE_EXCLUDE_REGEX: an ERE matching changed paths that are NOT product
#   source -- docs, config, lockfiles, CI, assets, etc. A change limited to
#   these paths never triggers the rule. Extend this for your repo's shape.
SOURCE_EXCLUDE_REGEX="${SOURCE_EXCLUDE_REGEX:-(^|/)(docs?|examples?|\.github|\.githooks|vendor|node_modules|dist|build)/|(^|/)(README|CHANGELOG|LICENSE|CONTRIBUTING)|\.(md|markdown|txt|rst|adoc)$|\.(ya?ml|toml|ini|cfg|conf|json|lock)$|(^|/)(Dockerfile|Makefile|Taskfile\.ya?ml|Gemfile|Gemfile\.lock|package\.json|package-lock\.json|yarn\.lock|go\.mod|go\.sum)$|\.(png|jpe?g|gif|svg|ico|webp|pdf)$}"

# RANGE: how to compute the changed-file set. Leave empty to use the staged
#   diff (git diff --cached), which is the right choice for commit-time hooks.
#   Override to inspect a range, e.g.:
#     RANGE="origin/main...HEAD"   # everything on this branch vs main
#     RANGE="HEAD~1"               # the last commit
#   When set, the file list comes from: git diff --name-only "$RANGE".
RANGE="${RANGE:-}"

# =============================================================================
# GRACEFUL DEGRADATION -- never block on a tooling gap.
# =============================================================================

# git binary present?
if ! command -v git >/dev/null 2>&1; then
  # No git available; nothing to enforce.
  exit 0
fi

# Inside a git work tree?
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# =============================================================================
# COMPUTE THE CHANGED FILE SET
# =============================================================================

# Collect changed paths, NUL-safe is overkill for a template; newline-split is
# fine because git paths here are compared, not shell-executed.
if [ -n "$RANGE" ]; then
  changed_files="$(git diff --name-only "$RANGE" 2>/dev/null || true)"
else
  changed_files="$(git diff --cached --name-only 2>/dev/null || true)"
fi

# Nothing staged / nothing in range -> nothing to check.
if [ -z "$changed_files" ]; then
  exit 0
fi

# =============================================================================
# CLASSIFY
# =============================================================================
# Walk the changed set once. A path is one of:
#   * a test change     -> matches TEST_PATH_REGEX
#   * an excluded change -> matches SOURCE_EXCLUDE_REGEX (docs/config/assets)
#   * a product-source change -> everything else
#
# The rule fires when there is at least one product-source change AND zero
# test changes.

test_changed=0
source_changed=0
source_examples=""

while IFS= read -r path; do
  # Skip blank lines defensively.
  [ -n "$path" ] || continue

  # Test changes satisfy the rule; count and move on.
  if printf '%s\n' "$path" | grep -Eq "$TEST_PATH_REGEX"; then
    test_changed=1
    continue
  fi

  # Non-source paths (docs, config, assets) are irrelevant to the rule.
  if printf '%s\n' "$path" | grep -Eq "$SOURCE_EXCLUDE_REGEX"; then
    continue
  fi

  # Anything left is product source.
  source_changed=1
  # Keep a short sample of offending paths for the report (cap at 10).
  if [ "$(printf '%s\n' "$source_examples" | grep -c .)" -lt 10 ]; then
    source_examples="${source_examples}${path}
"
  fi
done <<EOF
$changed_files
EOF

# =============================================================================
# VERDICT
# =============================================================================

# No violation: either no source changed, or at least one test changed.
if [ "$source_changed" -eq 0 ] || [ "$test_changed" -eq 1 ]; then
  exit 0
fi

# Violation: product source changed but no test did. Build the message.
{
  echo "----------------------------------------------------------------------"
  echo "source-change-requires-test: product source changed, but no test did."
  echo
  echo "Changed source files (no matching test change):"
  printf '%s' "$source_examples" | sed 's/^/  - /'
  echo
  echo "Add or update a test that exercises the change, or -- if a test truly"
  echo "does not apply -- record why in the commit message."
  echo
  echo "Tune via env: TEST_PATH_REGEX, SOURCE_EXCLUDE_REGEX, RANGE, MODE."
  echo "----------------------------------------------------------------------"
} >&2

# In block mode, fail the commit. In warn mode (default), allow it.
if [ "$MODE" = "block" ]; then
  exit 2
fi

exit 0

# =============================================================================
# WIRING
# =============================================================================
#
# 1) As a git pre-commit hook
# ---------------------------
#   Copy this file to .git/hooks/pre-commit (or your configured
#   core.hooksPath directory) and make it executable:
#
#       cp examples/hooks/source-change-requires-test.sh \
#          .git/hooks/pre-commit
#       chmod +x .git/hooks/pre-commit
#
#   git runs it with an empty argument list and the staged diff already set,
#   so the default RANGE (staged) is exactly right. To enforce hard:
#
#       # .git/hooks/pre-commit wrapper, or export in the shell/CI env
#       MODE=block .git/hooks/pre-commit
#
# 2) As a Claude Code PreToolUse hook
# -----------------------------------
#   Register it in .claude/settings.json so it runs before a commit command.
#   The matcher below gates on Bash tool calls; the hook itself only inspects
#   the staged diff, so it is cheap to run and a no-op when nothing is staged.
#
#       {
#         "hooks": {
#           "PreToolUse": [
#             {
#               "matcher": "Bash",
#               "hooks": [
#                 {
#                   "type": "command",
#                   "command": "examples/hooks/source-change-requires-test.sh"
#                 }
#               ]
#             }
#           ]
#         }
#       }
#
#   Exit 0 lets the tool call proceed; a non-zero exit (MODE=block) signals a
#   blocking condition to the agent. Keep MODE=warn until the team opts in.
#
# =============================================================================
