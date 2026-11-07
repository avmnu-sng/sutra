---
description: Use when authoring a Claude Code hook -- a PreToolUse, PostToolUse, SessionStart, UserPromptSubmit, or Stop checker -- to get the fail-open skeleton, which events can block, and advisory-vs-blocking recipes so a hook reports without ever breaking the user's flow.
---

# Hooks cookbook

A hook runs on every matching event, in the user's critical path, with the
user's full permissions. The rule that makes hooks safe to ship: **a hook
reports, but it never breaks the flow when its tooling is absent.** No `jq` or
`perl`, a malformed payload, the wrong tool or target, an unreadable file --
each is a clean `exit 0`. Block only for a rule you are certain about, on an
event that can block, and answer with a structured reply, never a crash.

## When to use

- Authoring a hook (PreToolUse, PostToolUse, SessionStart, UserPromptSubmit,
  Stop) or a git pre-commit script, or hardening an ad-hoc checker to run on
  every edit.
- Deciding whether a check should warn or block, and on which event.

Not for wiring a finished hook (a settings.json edit; see
`examples/hooks/README.md` in the sutra repository) or a one-off manual check.

## 1. The contract

A command hook reads one JSON event on stdin and answers with its exit code,
stderr, and stdout. Every event carries `session_id`, `cwd`, and
`hook_event_name`; `PreToolUse` and `PostToolUse` add `tool_name` and
`tool_input`, `UserPromptSubmit` adds `prompt`, and `Stop` adds
`stop_hook_active` and `last_assistant_message`. Exit 0 is success, and stdout
counts as a reply only when it is one JSON object and nothing else. Exit 2 is
a blocking error whose effect depends on the event, with stderr as its
message. Any other code is a non-blocking error: the flow proceeds.

Per the hooks reference (https://code.claude.com/docs/en/hooks):

| Event | Can it stop something? | How | `additionalContext` |
|---|---|---|---|
| `PreToolUse` | Yes: the tool call | `permissionDecision: "deny"` with `permissionDecisionReason`, or exit 2 | yes, next to the tool result |
| `UserPromptSubmit` | Yes: the prompt never reaches Claude | exit 2, or `decision: "block"` with `reason` | yes, with the prompt |
| `Stop`, `SubagentStop` | Yes: Claude keeps working instead of stopping | `decision: "block"` with `reason`, or exit 2; return early when `stop_hook_active` is true | yes, and it also keeps Claude working |
| `PreCompact` | Yes: compaction does not run, and a blocked automatic one can fail the request, so never block here | exit 2, or `decision: "block"` | no; plain stdout instructs the summary |
| `PostToolUse` | No: the tool already ran | feedback only: `additionalContext`, `decision: "block"` with `reason`, or exit 2 | yes, next to the tool result |
| `SessionStart` | No | exit 2 only shows stderr to the user | yes, before the first prompt |
| `SessionEnd` | No | JSON output is discarded; 1.5 second default budget | no |
| `Notification` | No | exit code and stderr are ignored | no |

Other events have their own rules (`PermissionRequest` ignores exit 2 and
denies only through its `decision` object); check the reference first. Plain
stdout on `SessionStart` and `UserPromptSubmit` also reaches Claude.
`systemMessage` is a warning shown to the user; `hookSpecificOutput` carries
`hookEventName` plus the event's own fields; `continue: false` stops Claude
outright, so an advisory hook never sets it.

## 2. The fail-open skeleton

Every hook starts the same way. Copy this shape; replace steps 2-5.

```bash
#!/usr/bin/env bash
set -u   # not -e: an ordinary nonzero must not abort the hook mid-run

# 0. No stdin (run by hand) or an empty payload: nothing to check.
[ -t 0 ] && exit 0
payload="$(cat 2>/dev/null)" || exit 0
[ -n "$payload" ] || exit 0

# 1. Pick a JSON tool: jq, else perl's core JSON::PP, else a silent no-op.
if command -v jq >/dev/null 2>&1; then json=jq
elif perl -MJSON::PP -e 1 >/dev/null 2>&1; then json=perl
else exit 0
fi

# json_get a.b prints that payload field as text; nothing when absent.
json_get() {
  if [ "$json" = jq ]; then
    printf '%s' "$payload" |
      jq -r --arg p "$1" 'getpath($p | split("."))? | scalars | values' 2>/dev/null
  else
    printf '%s' "$payload" | perl -MJSON::PP -e '
      my $v = eval { JSON::PP->new->utf8->decode(do { local $/; <STDIN> }) };
      $v = ref $v eq "HASH" ? $v->{$_} : undef for split /\./, $ARGV[0];
      $v = $v ? "true" : "false" if JSON::PP::is_bool($v);
      if (defined $v && !ref $v) { utf8::encode($v); print $v }' -- "$1" 2>/dev/null
  fi
}

# reply KEY VALUE... prints one JSON object; a dotted KEY nests.
reply() {
  if [ "$json" = jq ]; then
    jq -nc '$ARGS.positional as $a | reduce range(0; $a | length; 2) as $i
      ({}; setpath($a[$i] | split("."); $a[$i + 1]))' --args -- "$@"
  else
    perl -MJSON::PP -e '
      my %o;
      while (my ($k, $v) = splice @ARGV, 0, 2) {
        my @path = split /\./, $k;
        my $leaf = pop @path;
        my $h = \%o;
        $h = $h->{$_} //= {} for @path;
        utf8::decode($v);
        $h->{$leaf} = $v;
      }
      print JSON::PP->new->ascii->canonical->encode(\%o), "\n";' -- "$@"
  fi
}

# 2. Early-return unless THIS event is relevant. Cheapest test first.
file="$(json_get tool_input.file_path)"
case "$file" in *.rb|*.go|*.ts) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0

# 3. The checker is absent? No-op: never block on a tooling gap.
command -v mychecker >/dev/null 2>&1 || exit 0

# 4. Run the checker. Clean result: succeed silently.
report="$(mychecker "$file" 2>&1)" && exit 0

# 5. Translate the failure into a reply (an advisory to the user here).
reply systemMessage "mychecker flagged $file:
$(printf '%s\n' "$report" | tail -n 3)"
exit 0
```

Why each guard exists:

- `set -u` without `-e`: catch unset variables, but never let an ordinary
  nonzero abort the hook and surface as a spurious error.
- `[ -t 0 ]` and the empty check: the hook is runnable by hand for testing
  and never hangs on a terminal.
- jq, else `JSON::PP` (core perl), else `exit 0`: degrade, do not depend.
  Never parse JSON with `sed` or `grep`; an escaped quote, or the next
  field's text, shifts the match.
- `reply` hands values to jq or `JSON::PP` as data, so a quote, backslash,
  newline, or trailing ` |` in a file name or message cannot break the JSON
  or add a field. Never `printf` a value into a JSON template.
- The cheapest disqualifying check runs first: a hook that fires on every
  edit must cost near-zero on the edits it ignores.

## 3. Advisory or blocking

Default to advisory: `systemMessage` warns the user, `additionalContext`
tells Claude. Block only when a false positive costs less than the
violation, the rule is mechanical enough to trust, and the event can block:
on `PreToolUse`, reply `hookSpecificOutput.permissionDecision` `deny` with a
`permissionDecisionReason`; on `UserPromptSubmit` or `Stop`, reply `decision`
`block` with a `reason` (on `Stop`, once, and never while `stop_hook_active`
is true). A `PostToolUse` hook only gives feedback, because the tool already
ran. A warning at the wrong moment is noise; a block at the wrong moment is
lost work, so run a rule in warn mode until its precision is proven.

## 4. Recipes

Each recipe replaces steps 2-5 of the skeleton; the code is in
[reference/recipes.md](reference/recipes.md). Read the one that fits:

- **A. Fail-open guard wrapper** -- the skeleton itself; nothing more to read.
- **B. Post-edit CI parity** (`PostToolUse`, advisory) -- lint only the
  edited file, or run a formatter and tell Claude.
- **C. Newly-introduced-only guard** (`PostToolUse`, advisory) -- flag a
  marker only when this edit added it, compared with `HEAD`.
- **D. Structural-ledger validator** (`PostToolUse`, after-the-fact
  feedback) -- require parts in new Markdown ledger entries; how to refuse on
  `PreToolUse` instead.
- **E. Repo freshness** (`SessionStart`, context) -- behind/ahead as of the
  last fetch, without fetching.
- **F. Session-close checklist** (`UserPromptSubmit`, context) -- add a
  checklist when the prompt says to wrap up.
- **G. Internal-file commit guard** (git `pre-commit`, plus `PreToolUse` on
  `Bash`) -- keep denylisted paths out of commits.

## Wiring and opt-in

Enforcement belongs to the user, not the plugin: a hook that fires unasked,
even one that only warns at the wrong moment, is a surprise.

- **What sutra ships.** Advisory hooks (the session-start contract, rule
  cards, hidden-Unicode warnings, a compaction brief) plus, under the
  `strict` profile only, one bounded verify-before-stop nudge: a `Stop` hook
  that asks Claude once to run the project's checks when code changed and no
  check ran since. It never fires while `stop_hook_active` is true, never
  twice for the same edits, never when Claude ends on a question, and
  `SUTRA_GATE=off` turns it off. Sutra never blocks a tool call and makes no
  network calls.
- **Blocking or mutating hooks are opt-in.** The user wires them in their own
  `settings.json`, or the hook does nothing unless a switch the user sets
  turns it on.
- **Quote the path and set a timeout.** Shell form quotes the placeholder:
  `"command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/check.sh"` in a plugin, or
  `"\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/check.sh"` in project settings,
  with `"timeout": 10`. The default is 600 seconds (30 on
  `UserPromptSubmit`), and a hung hook holds the session that long.
- **No network calls with the user's credentials.** A hook runs unattended
  on every matching event: a fetch, push, or API call would spend the user's
  credentials without a prompt, add latency, and fail offline. Read local or
  cached state, as recipe E reads the last fetch.
- **One wiring per script.** Never register the same script as both a git
  `pre-commit` and a Claude Code hook; it would run twice.
- **Templates.** `examples/hooks/` in the sutra repository
  (`source-change-requires-test.sh`, `empty-test-detector.sh`) encodes the
  fail-open contract, with every knob an environment variable.

## Checklist

- [ ] `set -u`, not `-e`.
- [ ] Empty stdin, no `jq` and no `JSON::PP`, a missing checker, the wrong
      tool or target, an unreadable file: each is a silent `exit 0`.
- [ ] The payload is parsed with jq or `JSON::PP`, never `sed` or `grep`.
- [ ] Every reply is built from data by jq or `JSON::PP`, and stdout holds
      that one object.
- [ ] The cheapest disqualifying check runs first.
- [ ] Advisory by default; any block is deliberate, on an event that can
      block, for a rule you trust.
- [ ] A `PostToolUse` hook gives feedback and does not claim to stop the
      tool; a `Stop` hook returns early on `stop_hook_active`.
- [ ] A file-mutating hook tells Claude and uses only an idempotent
      formatter.
- [ ] "Newly introduced" checks compare against `HEAD`.
- [ ] Blocking is opt-in, never on by default.
- [ ] The hook command quotes its path and sets a `timeout`, and the hook
      makes no network calls.
