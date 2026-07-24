#!/usr/bin/env bash
# Sutra profile injector (SessionStart hook).
#
# Prints the active operating profile to stdout. Claude Code adds a
# SessionStart hook's stdout to the session context, so this is how Sutra
# delivers an always-on operating contract without editing your CLAUDE.md.
#
# Choose the profile (default: standard) with either:
#   export SUTRA_PROFILE=lite|standard|strict
# or a per-project file named ".sutra" at the project root whose only
# contents are the profile name, e.g.:
#   echo strict > .sutra
#
# Set SUTRA_PROFILE=off (or ".sutra" containing "off") to inject nothing.

set -euo pipefail

root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

profile="${SUTRA_PROFILE:-}"
if [ -z "$profile" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "$CLAUDE_PROJECT_DIR/.sutra" ]; then
  profile="$(tr -d '[:space:]' < "$CLAUDE_PROJECT_DIR/.sutra" 2>/dev/null || true)"
fi
profile="${profile:-standard}"

case "$profile" in
  off) exit 0 ;;
  lite|standard|strict) ;;
  *) profile="standard" ;;
esac

file="$root/profiles/$profile.md"
[ -f "$file" ] && cat "$file"
exit 0
