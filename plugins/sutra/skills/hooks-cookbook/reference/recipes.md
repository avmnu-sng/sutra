# Hooks cookbook: recipes

Each recipe is a pattern plus a sketch built on the fail-open skeleton in
`reference/skeleton.md`. Keep the skeleton's steps 0-1 (`set -u`, the stdin
guard, the choice of jq or `JSON::PP`, `json_get`, `reply`) and replace steps
2-5 with the recipe. Every value reaches stdout through `reply`, never through
a JSON template. Runnable, tunable templates live in `examples/hooks/` in the
sutra repository; adapt any of these to your stack before relying on it.

## Wiring

In a plugin's `hooks/hooks.json`, quote the plugin-root variable so a path
with spaces holds together, and set a timeout:

```json
{ "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/check.sh", "timeout": 10 }
```

In project settings, use `"\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/check.sh"`
the same way.

## A. Fail-open guard wrapper

The skeleton in `reference/skeleton.md` *is* this recipe: parse, early-return
unless relevant, run the checker, warn or block on failure. Every recipe below
is that shape with step 2 (relevance) and steps 4-5 (checker and verdict)
specialized. Start there.

## B. Advisory post-edit CI parity (PostToolUse)

Run the **cheap** CI subset on **only the edited file** and tell Claude what
failed. Do not run the slow full build in a hook -- lint one file, never
compile the world.

```bash
# PostToolUse on Write|Edit. Lint the one file CI would lint; never block.
file="$(json_get tool_input.file_path)"
case "$file" in *.rb) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0
command -v rubocop >/dev/null 2>&1 || exit 0

report="$(rubocop --force-exclusion --format simple "$file" 2>&1)" && exit 0
reply hookSpecificOutput.hookEventName PostToolUse \
  hookSpecificOutput.additionalContext "CI-parity lint on $file:
$(printf '%s\n' "$report" | tail -n 3)"
exit 0
```

**Auto-format-then-tell variant.** A `PostToolUse` hook may mutate the file
it just saw: run the formatter, then report. This is qualitatively different
from a warn-only hook: it *changes the user's file behind the edit*. Only do
it when the formatter is deterministic and idempotent, and always tell Claude,
or its next edit will target text the formatter has rewritten.

```bash
# PostToolUse on Write|Edit, after the relevance checks above.
command -v prettier >/dev/null 2>&1 || exit 0
before="$(cksum < "$file" 2>/dev/null)"
prettier --write "$file" >/dev/null 2>&1 || exit 0
[ "$before" = "$(cksum < "$file" 2>/dev/null)" ] && exit 0
reply systemMessage "Auto-formatted $file with prettier." \
  hookSpecificOutput.hookEventName PostToolUse \
  hookSpecificOutput.additionalContext "A hook reformatted $file with prettier after your edit. Read it again before editing it further."
exit 0
```

## C. Newly-introduced-only guard (PostToolUse)

Warn only when **this edit** introduced the violation. Do not nag about
pre-existing debt: compare the working file against its committed `HEAD`.

```bash
# PostToolUse on Write|Edit. Flag a marker only when the edit raised the count.
file="$(json_get tool_input.file_path)"
# Project files only: another repository's config (core.fsmonitor) can run a program.
case "$file" in "${CLAUDE_PROJECT_DIR:-$PWD}"/*) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0
cd -- "$(dirname -- "$file")" 2>/dev/null || exit 0
name="$(basename -- "$file")"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
pattern='TODO|FIXME|binding\.pry|console\.log'

now="$(grep -Ec -e "$pattern" -- "$name" 2>/dev/null)"
was="$(git show "HEAD:./$name" 2>/dev/null | grep -Ec -e "$pattern")"
[ "${now:-0}" -gt "${was:-0}" ] || exit 0
reply hookSpecificOutput.hookEventName PostToolUse \
  hookSpecificOutput.additionalContext "This edit added a debug or TODO marker to $file (${was:-0} -> $now). Remove it unless it is meant to stay."
exit 0
```

`HEAD:./$name` names the committed copy relative to the file's directory, so
no path from `git ls-files` (which quotes unusual names) is needed; a file
missing from `HEAD` counts from zero. A count delta is coarse but cheap; for
line-precise attribution, take the added lines of
`git diff --no-color --no-ext-diff -U0 -- "$name"` and grep only those.

## D. Structural-ledger validator (PostToolUse, after-the-fact feedback)

Require every **newly added** entry in a Markdown ledger to cite a concrete
`` `backticked` `` identifier and carry a bold **Fix:** line. `PostToolUse`
fires after the write has landed, so this hook cannot stop it: it tells
Claude what is missing, and Claude fixes the entry on its next edit.

```bash
# PostToolUse on Write|Edit of the ledger. The write already happened.
file="$(json_get tool_input.file_path)"
case "$file" in */LEDGER.md) ;; *) exit 0 ;; esac
# Project files only: another repository's config (core.fsmonitor) can run a program.
case "$file" in "${CLAUDE_PROJECT_DIR:-$PWD}"/*) ;; *) exit 0 ;; esac
cd -- "$(dirname -- "$file")" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

added="$(git diff --no-color --no-ext-diff -U0 -- LEDGER.md 2>/dev/null |
  awk '/^@@/ { hunk = 1; next } hunk && /^[+]/ { print substr($0, 2) }')"
entries="$(printf '%s\n' "$added" | grep -e '^- ')" || exit 0
missing=""
printf '%s\n' "$entries" | grep -qv -e '`[^`][^`]*`' &&
  missing="a backticked identifier"
printf '%s\n' "$added" | grep -q -e '[*][*]Fix:[*][*]' ||
  missing="${missing:+$missing and }a **Fix:** line"
[ -n "$missing" ] || exit 0
reply hookSpecificOutput.hookEventName PostToolUse \
  hookSpecificOutput.additionalContext "LEDGER.md was saved with a new entry that lacks $missing. Every new entry needs a backticked identifier and a **Fix:** line; correct the entry now."
exit 0
```

The diff covers every unstaged change to the ledger, not only this edit, and
a reworded bullet counts as new. `--no-color` and `--no-ext-diff` keep a
`color.ui=always` setting or an external diff driver from changing the text
`awk` reads. To refuse the edit before it lands instead, run the same line
checks as a `PreToolUse` hook on `Edit|Write` against
`tool_input.new_string` (Edit) or `tool_input.content` (Write), and answer
with `permissionDecision` `deny`.

## E. Repo freshness (SessionStart, context only)

Compute ahead/behind versus the upstream ref as of the last fetch, and give
Claude the result as context. Do not fetch from a hook: a network call on
every session start acts without a prompt, adds latency, and fails offline.
Report the cached state and leave fetching to an explicit step.
A `SessionStart` hook cannot gate a session, and this one never tries:
detached HEAD and no upstream both fall through to `exit 0`.

```bash
# SessionStart. Reads the upstream state as of the last fetch; never fetches.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" || exit 0
counts="$(git rev-list --left-right --count "$upstream...HEAD" 2>/dev/null)" || exit 0
behind="${counts%%[[:space:]]*}"
ahead="${counts##*[[:space:]]}"
case "$behind$ahead" in ''|*[!0-9]*) exit 0 ;; esac
[ "$behind" -gt 0 ] || exit 0
reply hookSpecificOutput.hookEventName SessionStart \
  hookSpecificOutput.additionalContext "As of the last fetch, this branch is $behind behind and $ahead ahead of $upstream. Tell the user before starting work; the count is only as fresh as that fetch."
exit 0
```

## F. Session-close checklist (UserPromptSubmit, context only)

Match the submitted prompt against a trigger phrase; on a match, add a
close-out checklist to Claude's context. No match is a silent no-op.

```bash
# UserPromptSubmit. On a close-out phrase, add the checklist as context.
prompt="$(json_get prompt)"
printf '%s\n' "$prompt" | grep -Eiq -e 'wrap up|close out|ship it|end of session' || exit 0
reply hookSpecificOutput.hookEventName UserPromptSubmit \
  hookSpecificOutput.additionalContext "Session close-out checklist:
- [ ] tests green
- [ ] lint clean
- [ ] changelog or notes updated
- [ ] no debug markers left behind
- [ ] retro captured"
exit 0
```

## G. Internal-file commit guard (git pre-commit, plus PreToolUse)

Keep internal-only files out of commits by matching a path denylist against
what is being committed.

**The reliable gate is a git `pre-commit` hook.** Git runs it for every
`git commit` (`-a`, `--amend`, and `git commit <path>` included), however the
command is spelled and whichever tool runs it, and it sees the index actually
being committed, including what `-a` or a pathspec stages on the way. It does
not run under `--no-verify` or a changed `core.hooksPath`, or for a commit
that `cherry-pick`, `rebase`, `revert`, `am`, or `merge` creates on its own;
CI holds the line for those.

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit: refuse a commit that adds or changes a denied path.
set -u
deny='(^|/)(docs/private|\.notes|scratch)/|(^|/)PLANNING\.md$'
hit="$(git diff --cached --name-only --diff-filter=ACMR -z 2>/dev/null |
  tr '\0' '\n' | grep -E -e "${DENY_REGEX:-$deny}")" || exit 0
printf 'Internal-only paths are staged; unstage them before committing:\n%s\n' "$hit" >&2
exit 1
```

`-z` keeps git from quoting unusual names (a quoted name would slip past the
`^` anchor), and `--diff-filter=ACMR` lets a commit delete a denied file.

**The `PreToolUse` guard is the early, structured refusal.** It denies a
`git commit` from Claude before the command runs, with a reason Claude can act
on. It matches a git invocation whose subcommand is `commit`, with global
options before it (`git -C . commit`, `git -c user.name=x commit`,
`git --no-pager commit`, a quoted `-C "my dir"` or `--work-tree="my dir"`, a
backslash-continued line), inside `&&` chains, `$(...)`, backquotes, and
`sh -c '...'`. Shell text cannot be parsed completely -- an alias, a
variable, or a script that commits still gets past it, and it checks the
index before `-a` or a pathspec adds to it -- so keep the `pre-commit` hook
as the gate. A false match costs little: it only refuses while a denied path
is staged.

```bash
# PreToolUse on Bash. Refuse a git commit while a denied path is staged.
case "$payload" in *commit*) ;; *) exit 0 ;; esac   # cheapest test first
cmd="$(json_get tool_input.command)"
nl='
'
cmd="${cmd//\\$nl/ }"   # join backslash-continued lines
sq="'"
word="(\"[^\"]*\"|${sq}[^${sq}]*${sq}|[^[:space:];&|()\"${sq}]+)+"
opt="(-C|-c|--git-dir|--work-tree|--namespace|--config-env|--attr-source)[[:space:]]+$word|-[^[:space:];&|()=\"${sq}]*(=$word)?"
lead="(^|[[:space:];&|(){}\`\"${sq}])([^[:space:];&|(){}\`\"${sq}]*/)?"
git_commit="${lead}git([[:space:]]+($opt))*[[:space:]]+commit([[:space:];&|)<>\`]|\$)"
printf '%s\n' "$cmd" | grep -Eq -e "$git_commit" || exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
deny='(^|/)(docs/private|\.notes|scratch)/|(^|/)PLANNING\.md$'
hit="$(git diff --cached --name-only --diff-filter=ACMR -z 2>/dev/null |
  tr '\0' '\n' | grep -E -e "${DENY_REGEX:-$deny}")" || exit 0
reply hookSpecificOutput.hookEventName PreToolUse \
  hookSpecificOutput.permissionDecision deny \
  hookSpecificOutput.permissionDecisionReason "Internal-only paths are staged: $(printf '%s' "$hit" | tr '\n' ' ')- unstage them before committing."
exit 0
```

These are two scripts, not one script wired twice, and they work together:
the `PreToolUse` guard answers Claude before the command runs, and the
`pre-commit` hook checks every `git commit`, including the ones the guard
cannot see.
