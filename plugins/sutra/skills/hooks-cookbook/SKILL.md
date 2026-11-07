---
description: Use when authoring a Claude Code hook -- writing a PreToolUse/PostToolUse/SessionStart/UserPromptSubmit checker -- to get the fail-open guard skeleton and advisory-vs-blocking recipes so a hook reports without ever breaking the user's flow.
---

# Hooks cookbook

A hook runs on every matching event, in the user's critical path. The one rule
that makes hooks safe to ship: **a hook reports, but it never breaks the flow
when its tooling is absent.** No interpreter, no `jq`, wrong tool, wrong target,
unreadable file -- every one of those is a clean `exit 0`, not an error. Earn the
right to block only for a rule you are certain about, and even then translate
the failure into a structured response instead of a raw crash.

Build every hook in this order: parse the event, early-return unless it is
relevant, run the checker, translate the result into an advisory or a block.
Sections 1-3 are the contract; the recipe gallery applies it.

## When to use

- Authoring a new hook (PreToolUse, PostToolUse, SessionStart, UserPromptSubmit,
  Stop, or a git pre-commit script).
- Turning an ad-hoc checker script into something safe to run on every edit.
- Deciding whether a check should warn or hard-block, and wiring the response.

## When not to use

- Wiring an existing, finished hook -- that is a settings.json edit, not
  authoring. See `examples/hooks/README.md`.
- A one-off manual check you run by hand. Hooks are for the automatic path.

---

## 1. The contract you are coding against

A hook is a command. Claude Code sends it a JSON event on **stdin** and reads
its **exit code** and **stdout**.

Stdin fields you will use (all events carry `session_id`, `cwd`,
`hook_event_name`):

| Event              | Key fields on stdin                                  |
|--------------------|------------------------------------------------------|
| `PreToolUse`       | `tool_name`, `tool_input` (args the tool will run)   |
| `PostToolUse`      | `tool_name`, `tool_input`, `tool_response`           |
| `UserPromptSubmit` | `prompt` (the text the user just submitted)          |
| `SessionStart`     | `source` (`startup`\|`resume`\|`clear`\|`compact`)   |

Exit codes -- the coarse channel:

| Exit | Meaning                | Effect                                                 |
|------|------------------------|--------------------------------------------------------|
| `0`  | success                | flow proceeds; stdout is consumed (see below)          |
| `2`  | blocking error         | stderr is fed back to the agent; the action is stopped |
| other| non-blocking error     | stderr is shown to the user; flow proceeds             |

Stdout -- the structured channel (a single JSON object on exit 0):

- `{"systemMessage": "..."}` -- a non-blocking note shown to the user.
- `hookSpecificOutput.additionalContext` -- text injected into the model's
  context. Valid for `UserPromptSubmit` and `SessionStart`.
- `hookSpecificOutput.permissionDecision` = `"allow"|"deny"|"ask"` with
  `permissionDecisionReason` -- a `PreToolUse`-only structured verdict.
- `{"suppressOutput": true}` -- hide stdout from the transcript.

The two ways to stop an action: **exit 2** (works everywhere; stderr is the
message) or, for `PreToolUse` only, **`permissionDecision: "deny"`** (a clean
structured refusal). Everything else is advisory.

---

## 2. The fail-open guard skeleton

Every hook starts the same way. Copy this shape; fill in step 4.

```bash
#!/usr/bin/env bash
set -u   # NOT -e: a stray nonzero must not abort the hook mid-way

# 0. No stdin (someone ran it by hand)? Nothing to check.
[ -t 0 ] && exit 0
payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

# 1. Parse the event. Prefer jq; fall back to sed so a missing jq is a no-op,
#    not a crash. (For a checker binary you REQUIRE, `command -v it || exit 0`.)
json_get() { # json_get <jq-path> -- e.g. json_get '.tool_input.file_path'
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -r "$1 // empty" 2>/dev/null
  else
    key="${1##*.}"   # last dotted segment; forgiving, good enough for a path
    printf '%s' "$payload" \
      | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" \
      | head -n1
  fi
}

# 2. Early-return unless THIS event is relevant.
file="$(json_get '.tool_input.file_path')"
[ -n "$file" ] && [ -f "$file" ] || exit 0
case "$file" in *.rb|*.go|*.ts) ;; *) exit 0 ;; esac   # only files we handle

# 3. The checker it needs is absent? No-op -- never block on a tooling gap.
command -v mychecker >/dev/null 2>&1 || exit 0

# 4. Run the checker. Clean result -> succeed silently.
report="$(mychecker "$file" 2>&1)" && exit 0

# 5. Translate the nonzero result into a response (advisory here).
msg="$(printf '%s' "$report" | tail -n 3 | sed 's/\\/\\\\/g; s/"/\\"/g')"
printf '{"systemMessage":"mychecker flagged %s:\\n%s"}\n' "$file" "$msg"
exit 0
```

Why each guard exists:

1. `set -u` without `-e` -- catch unset vars, but never let an ordinary nonzero
   command abort the hook and surface as a spurious blocking error.
2. `[ -t 0 ]` / empty payload -- the hook is runnable by hand for testing; do
   not hang on a terminal or choke on empty input.
3. `jq`-or-`sed` -- degrade, do not depend. A machine without `jq` still gets a
   silent no-op, never a stack trace in the user's face.
4. The `case` and `command -v` early-returns -- do the cheapest disqualifying
   check first. A hook that fires on every edit must cost near-zero on the 99%
   of edits it does not care about.

---

## 3. Advisory or blocking -- pick deliberately

Default to advisory. Reach for a block only when a false positive costs less
than letting the violation through, and the rule is mechanical enough to trust.

| Intent                         | How                                                     |
|--------------------------------|---------------------------------------------------------|
| Non-blocking warning           | `exit 0` + `{"systemMessage": "..."}`                   |
| Feed a hint into model context | `exit 0` + `hookSpecificOutput.additionalContext`       |
| Hard stop (any event)          | write the reason to stderr, `exit 2`                    |
| Hard stop (`PreToolUse`)       | `permissionDecision: "deny"` + `permissionDecisionReason` |

Advisory is the safe default because a warning at the wrong moment is merely
noise; a block at the wrong moment is lost work. Escalate from warn to block
only after the rule has run in warn mode long enough to trust its precision.

---

## Recipe gallery

Each recipe is a pattern plus a sketch. Runnable, tunable templates live in
`examples/hooks/`; adapt them to your stack before relying on them.

### A. Fail-open guard wrapper

The skeleton in section 2 *is* this recipe: parse, early-return unless relevant,
run the checker, warn or block on failure. Every recipe below is that shape with
step 2 (relevance) and step 4-5 (checker + verdict) specialized. Start here.

### B. Advisory post-edit CI-parity

Run the **cheap** CI subset on **only the edited file** and warn. Do not run the
slow full build in a hook -- lint one file, never compile the world.

```bash
# PostToolUse on Write|Edit. Lint the one file CI would lint; warn, never block.
case "$file" in *.rb) ;; *) exit 0 ;; esac
command -v rubocop >/dev/null 2>&1 || exit 0

report="$(rubocop --force-exclusion --format simple "$file" 2>&1)" && exit 0
tail="$(printf '%s' "$report" | tail -n 3 | sed 's/\\/\\\\/g; s/"/\\"/g')"
printf '{"systemMessage":"CI-parity lint on %s:\\n%s"}\n' "$file" "$tail"
exit 0
```

**Auto-format-then-warn variant.** A `PostToolUse` hook MAY mutate the file it
just saw -- run the formatter, then validate. This is qualitatively different
from a warn-only hook: it *changes the user's file behind the edit*. Only do it
when the formatter is deterministic and idempotent, and always announce the
mutation so the model re-reads before its next edit.

```bash
command -v prettier >/dev/null 2>&1 || exit 0
before="$(cksum "$file" 2>/dev/null)"
prettier --write "$file" >/dev/null 2>&1 || exit 0   # mutate in place
[ "$before" = "$(cksum "$file" 2>/dev/null)" ] && exit 0   # unchanged -> quiet
printf '{"systemMessage":"auto-formatted %s (prettier); re-read before editing further."}\n' "$file"
exit 0
```

### C. Newly-introduced-only guard

Warn only when **this edit** introduced the violation. Do not nag about
pre-existing debt -- compare the working file against its committed `HEAD`.

```bash
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
pattern='TODO|FIXME|binding\.pry|console\.log'

rel="$(git ls-files --full-name "$file" 2>/dev/null)"
now="$(grep -Ec "$pattern" "$file" 2>/dev/null)"; now="${now:-0}"
was="$(git show "HEAD:$rel" 2>/dev/null | grep -Ec "$pattern")"; was="${was:-0}"
[ "$now" -gt "$was" ] || exit 0   # count did not rise -> not this edit's doing
printf '{"systemMessage":"this edit added a debug/TODO marker to %s (%s -> %s)."}\n' \
  "$file" "$was" "$now"
exit 0
```

A count delta is coarse but cheap. For line-precise attribution, diff the added
lines (`git diff -U0 -- "$file" | sed -n 's/^+//p'`) and grep only those.

### D. Structural-ledger validator (blocking)

Parse a Markdown ledger and require every **newly-added** entry to cite a
concrete `` `backticked` `` identifier and a bold **Fix:** line. A finding with
no anchor is not actionable, so this one blocks.

```bash
# PostToolUse on Edit of the ledger. Inspect only the lines this edit added.
case "$file" in */LEDGER.md) ;; *) exit 0 ;; esac
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

added="$(git diff -U0 -- "$file" | sed -n 's/^+//p')"
bad=""
while IFS= read -r line; do
  case "$line" in
    '- '*)   # a new entry bullet must name a concrete identifier
      printf '%s' "$line" | grep -q '`[^`]\+`' || bad="missing backticked id" ;;
  esac
done <<EOF
$added
EOF
printf '%s' "$added" | grep -q '\*\*Fix:\*\*' || bad="missing **Fix:** line"
[ -z "$bad" ] && exit 0

echo "LEDGER: new entry needs a \`backticked\` identifier and a **Fix:** line ($bad)." >&2
exit 2   # hard stop; stderr becomes the agent's feedback
```

### E. Repo-freshness / staleness (SessionStart, always exits 0)

Compute ahead/behind versus the upstream ref as of the last fetch, and inject
the result as context. Do not fetch from a hook: a network call on every
session start runs with the user's git credentials, adds latency, and fails
offline. Report the cached state and leave fetching to an explicit step. A
`SessionStart` hook must never gate a session -- detached HEAD and no upstream
both fall through to `exit 0`.

```bash
#!/usr/bin/env bash
set -u
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
[ -n "$upstream" ] || exit 0
set -- $(git rev-list --left-right --count "$upstream"...HEAD 2>/dev/null)
behind="${1:-0}"; ahead="${2:-0}"
[ "$behind" = "0" ] && exit 0

up="$(printf '%s' "$upstream" | sed 's/\\/\\\\/g; s/"/\\"/g')"   # refs may hold a quote
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"As of the last fetch, this branch is %s behind / %s ahead of %s. Fetch and rebase before you start."}}\n' \
  "$behind" "$ahead" "$up"
exit 0
```

### F. Session-close checklist (UserPromptSubmit)

Grep the submitted prompt for a trigger phrase; on a match, inject a close-out
checklist as context. No match -> silent no-op.

```bash
#!/usr/bin/env bash
set -u
[ -t 0 ] && exit 0
payload="$(cat 2>/dev/null || true)"
prompt="$(printf '%s' "$payload" \
  | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p')"
printf '%s' "$prompt" | grep -Eiq 'wrap up|close out|ship it|end of session' || exit 0

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"Session close-out checklist:\\n- [ ] tests green\\n- [ ] lint clean\\n- [ ] changelog / notes updated\\n- [ ] no debug markers left behind\\n- [ ] retro captured"}}\n'
exit 0
```

### G. Planning-doc commit guard (denylist, blocking)

Keep internal-only files out of commits: match a filename denylist against the
staged set, and refuse the commit if any are staged. Wire it as a `PreToolUse`
hook on `Bash` (gate `git commit`) or as a git `pre-commit` script.

```bash
#!/usr/bin/env bash
set -u
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Only act on a commit command (PreToolUse fires on every Bash call).
payload="$(cat 2>/dev/null || true)"
cmd="$(printf '%s' "$payload" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p')"
[ -n "$cmd" ] && ! printf '%s' "$cmd" | grep -q 'git commit' && exit 0

DENY_REGEX="${DENY_REGEX:-(^|/)(docs/private|\.notes|scratch)/|(^|/)PLANNING\.md$}"
hit="$(git diff --cached --name-only 2>/dev/null | grep -E "$DENY_REGEX" || true)"
[ -n "$hit" ] || exit 0

files="$(printf '%s' "$hit" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')"
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Internal-only paths are staged: %s. Unstage them before committing."}}\n' \
  "$files"
exit 0
```

As a git `pre-commit` script instead, drop the command-parsing and swap the JSON
tail for `echo "..." >&2; exit 2`.

---

## Wiring and opt-in

Enforcement belongs to the user, not the plugin. A hook that fires unasked -- even
one that only warns at the wrong moment -- is a surprise, and surprises erode
trust in the tool. So:

- **sutra core ships only advisory hooks.** Anything that mutates or blocks is
  opt-in, wired by the user in their own project or user `settings.json`.
- **Escalate through the profiles.** Model an opt-in blocking rule on the sutra
  profile ladder: silent under `lite`/`standard`, active under `strict` (see
  `plugins/sutra/profiles/`). Read the profile at run time and no-op unless the
  user chose the stricter tier.
- **One wiring per hook.** Do not register the same script as both a git
  `pre-commit` and a Claude Code hook -- it will run twice.
- **Start runnable templates from `examples/hooks/`**
  (`source-change-requires-test.sh`, `empty-test-detector.sh`). They already
  encode the fail-open contract and expose every knob as an env var.

---

## Checklist

- [ ] `set -u` (not `-e`); no ordinary nonzero can abort the hook mid-run.
- [ ] Empty/absent stdin, missing `jq`, missing checker, wrong tool, wrong
      target, unreadable file -- every one is a silent `exit 0`.
- [ ] Cheapest disqualifying check runs first; the hot path is near-zero cost.
- [ ] Advisory by default: `systemMessage` or `additionalContext`, `exit 0`.
- [ ] Any block is deliberate -- `exit 2` (stderr message) or `PreToolUse`
      `permissionDecision: "deny"` -- and reserved for a rule you trust.
- [ ] A file-mutating hook announces the mutation and uses only an idempotent
      formatter.
- [ ] "Newly introduced" checks compare against `HEAD`; they never nag about
      pre-existing issues.
- [ ] Blocking enforcement is opt-in (profile-gated or user-wired), never turned
      on by sutra core.
- [ ] The JSON emitted on stdout is a single valid object; interpolated values
      are escaped for backslash and double-quote.
