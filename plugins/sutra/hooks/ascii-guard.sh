#!/usr/bin/env bash
# Sutra ASCII guard (PostToolUse hook on Write|Edit).
#
# Active ONLY under the strict profile. Emits a non-blocking warning when a
# just-written file contains a non-ASCII byte. It never blocks the write.
#
# The strict profile keeps committed files ASCII-only so they render
# identically everywhere and never smuggle look-alike Unicode punctuation.
# Set SUTRA_PROFILE=standard (or lower) to silence this entirely.

set -euo pipefail

profile="${SUTRA_PROFILE:-}"
if [ -z "$profile" ] && [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "$CLAUDE_PROJECT_DIR/.sutra" ]; then
  profile="$(tr -d '[:space:]' < "$CLAUDE_PROJECT_DIR/.sutra" 2>/dev/null || true)"
fi
profile="${profile:-standard}"
[ "$profile" = "strict" ] || exit 0

payload="$(cat 2>/dev/null || true)"
file="$(printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
[ -n "$file" ] && [ -f "$file" ] || exit 0

line="$(LC_ALL=C perl -e 'open(my $fh, "<", $ARGV[0]) or exit 0; while (<$fh>) { if (/[^\x00-\x7F]/) { print $.; last } }' -- "$file" 2>/dev/null || true)"
[ -n "$line" ] || exit 0

printf '{"systemMessage":"sutra(strict): non-ASCII byte in %s (first at line %s). Prefer ASCII: -- for an em dash, -> for an arrow, plain quotes. Set SUTRA_PROFILE=standard to silence."}\n' "$file" "$line"
exit 0
