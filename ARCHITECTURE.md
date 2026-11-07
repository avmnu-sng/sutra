# Architecture

How Sutra is put together, and why it is shaped this way.

## The delivery problem

Claude Code can be extended two ways: standalone `.claude/` files in one
project, or a **plugin** distributed through a marketplace. Only the plugin
path gives you install-once, no-clone, versioned, auto-updating distribution.
So Sutra is a plugin.

But a plugin cannot ship a `CLAUDE.md` (there is no "inject this memory"
plugin field). Sutra works around that, and ships its workflow natively:

- **Always-on operating contract** is delivered by a `SessionStart` **hook**
  whose stdout Claude Code adds to the session context. This is the same
  mechanism a user-level memory-loader hook uses, applied from inside a plugin.
  No `CLAUDE.md` edit required.
- **Workflows** need no workaround: a plugin ships them natively. Claude Code
  loads every script in the plugin's `workflows/` directory and namespaces it
  by plugin name, so the orchestrator whose `meta.name` is
  `build-orchestrator` runs as `/sutra:build-orchestrator`. `meta` must be the
  first statement and a plain object literal (no variables, function calls,
  spreads, or string concatenation), or Claude Code drops the command from `/`
  autocomplete.

## One plugin, layered profiles

Rather than ship several plugins (core, strict, ...) that a user must install
in the right combination, Sutra ships **one** plugin and composes its operating
contract from three layer files under `profiles/`:

| Profile    | Layers                                  |
| ---------- | --------------------------------------- |
| `lite`     | `core.md`                               |
| `standard` | `core.md` + `standard.md` (the default) |
| `strict`   | `core.md` + `standard.md` + `strict.md` |
| `off`      | none                                    |

`compose` in `hooks/sutra.sh` concatenates the layers, so moving up a profile
never removes a rule, only adds a layer, and each rule lives in exactly one
layer. One plugin keeps the install to two commands and makes "turn the rigor
up" a one-word change.

The user chooses the profile: the `SUTRA_PROFILE` environment variable first,
then the plugin's `profile` setting (a `userConfig` option in `plugin.json`,
which Claude Code passes to hooks as `CLAUDE_PLUGIN_OPTION_PROFILE`), then
`standard`. With no user choice, a repository's `.sutra` file may raise the
profile to `strict` but never lower it or turn Sutra off: a repository is
content the user did not write, so it can ask for more rigor but cannot weaken
the contract the user runs under. Sutra reports a refused downgrade to the user
at session start, reads only the first 64 bytes of `.sutra`, and ignores it
when it is a symbolic link, so a repository cannot point Sutra at a file
outside it.

The invariant: Sutra never blocks a tool call. Under `strict` it may ask the
agent, at most once per batch of edits, to run the project's checks before it
stops. Every hook degrades to silence when its tooling is missing. An
operating-style kit must degrade to silence, never to obstruction; enforcement
belongs in a pre-commit check or CI that the project owns.

## Harness

All hook behavior is one Bash script, `hooks/sutra.sh`, which
`hooks/hooks.json` runs with one argument per event and a 5 to 10 second
timeout. Context for Claude goes out as `additionalContext`, notices for the
user as `systemMessage`.

| Event | Role | What `sutra.sh` does |
| --- | --- | --- |
| `SessionStart` (every source) | orient | Adds the composed contract, scans the instruction files for hidden Unicode, and reports a refused `.sutra`. On `startup` it prunes old state; after `compact` or `clear` it re-arms the cards. |
| `UserPromptSubmit` | route | Under `standard` and `strict`, adds the commit, publish, or migration card when the prompt mentions one. |
| `PostToolUse` (Write, Edit, MultiEdit, NotebookEdit, Read, Bash, WebFetch, WebSearch, Agent, Task) | check | Under every profile (the security floor), scans each file Claude writes or reads for hidden Unicode and adds the untrusted-content card after a web fetch or search. Under `standard` and `strict`, adds the test, migration, doc, or code card on the first such edit, the commit or publish card when a commit, push, release, or upload runs, and the delegate card after a subagent returns. Under `strict`, notes a non-ASCII byte in a written file and counts edits and check commands for the stop gate. |
| `PreCompact` | brief | Except under `off`, prints what the compaction summary must keep: the task, decisions with reasons, files changed, checks run, open and deferred items, and security warnings. |
| `Stop` | gate | Under `strict` only, blocks the stop once (`decision: block` with a reason) when code changed and no check command ran since. |

The gate never fires while `stop_hook_active` is true, never twice for the same
edits, and not when Claude's last message ends with a question;
`SUTRA_GATE=off` disables it. A card fires at most once until the next
compaction or `/clear`. That memory, and the gate's counts, are marker files
under `CLAUDE_PLUGIN_DATA/sessions/<session_id>/`, the plugin data directory
Claude Code provides. A session id must match `[A-Za-z0-9_-]{1,128}` before it
becomes a directory name, markers older than 14 days are pruned at startup,
and without `CLAUDE_PLUGIN_DATA` the cards and the gate stay silent.
PostToolUse runs after every matching tool call, so outside `strict`,
`on_post_tool` uses a shell pattern to drop a Bash payload that cannot trigger
a card before it starts perl. Under `strict` every Bash command goes through
to `is_check`, because any of them may be a check the stop gate must count.

### Security floor

Under every profile, `off` included, Sutra looks for hidden Unicode:
bidirectional controls (U+061C, U+200E, U+200F, U+202A-U+202E, U+2066-U+2069),
zero-width and invisible characters (U+200B-U+200D, U+2060-U+2064, U+180E, and
a U+FEFF anywhere but the start of a file), and Unicode tag characters
(U+E0000-U+E007F). These characters render as nothing or reorder text, so a
human reviewer can approve a file whose instructions the model reads
differently. `scan_file` checks every file Claude writes or reads, and at
session start `scan_instructions` checks the instruction files coding agents
load: `CLAUDE.md`, `CLAUDE.local.md`, `.claude/CLAUDE.md`, `AGENTS.md`,
`GEMINI.md`, `.cursorrules`, `.github/copilot-instructions.md`,
`.claude/rules/*.md`, and `CLAUDE.md` files in subdirectories up to two levels
below the project root (at most 50), which Claude Code loads on demand without
a Read that Sutra could see. Files
over 4 MiB and binary files are skipped. The set is fixed: variation selectors
(U+FE00-U+FE0F, U+E0100-U+E01EF) and other default-ignorable characters
outside it are not flagged. A line with invalid UTF-8 is decoded leniently, so
a stray bad byte cannot hide a character after it. A scan reports only the
first hidden character in a file; each finding goes to Claude as context and
to the user as a notice. The floor also includes the untrusted-content card
after WebFetch and WebSearch. Only the user's `SUTRA_SECURITY=off` turns it
off; a repository's `.sutra` cannot.

## Layout

```
sutra/
  .claude-plugin/marketplace.json     # the catalog (name: sutra)
  plugins/sutra/
    .claude-plugin/plugin.json        # the plugin manifest and profile setting
    README.md                         # what the plugin runs, reads, writes
    LICENSE                           # the plugin's license (MIT)
    assets/icon.png                   # the listing icon
    hooks/
      hooks.json                      # wires five events to sutra.sh
      sutra.sh                        # the hook dispatcher (all hook code)
    profiles/                         # contract layers, composed per profile
      core.md                         # carried by every profile except off
      standard.md                     # added under standard and strict
      strict.md                       # added under strict
    cards/<id>.md                     # rule cards (+ <id>.strict.md add-ons)
    skills/<name>/SKILL.md            # invocable methodologies (/sutra:<name>)
    agents/<name>.md                  # dispatchable subagents (thin dispatchers)
    workflows/<name>.workflow.js      # workflows, run as /sutra:<meta.name>
  tests/hooks.sh                      # behavior tests for sutra.sh
  docs/                               # install guide, profile guide, architect persona
  examples/                           # sample CLAUDE.md, AGENTS.md, settings, opt-in hooks
```

Everything a plugin references at runtime lives inside the plugin directory,
because Claude Code copies a plugin into a cache on install -- paths that reach
outside the plugin (`../`) would not resolve. Hook commands use
`${CLAUDE_PLUGIN_ROOT}` to find their scripts in that cache.

## Skills, profiles, and docs

Guidance appears at layered depths, by design:

- **Profile** -- the always-on contract, added at session start and again after
  each compaction. Measured cost: `lite` 1,368 bytes (about 340 tokens),
  `standard` 2,481 bytes (about 620 tokens), `strict` 3,360 bytes (about 840
  tokens).
- **Card** (`cards/<id>.md`) -- a few lines of rule delivered at the moment
  they apply (a commit, a test or migration edit, a subagent result, web
  content), naming the skill that holds the depth. The eight cards and their
  two strict add-ons total 2,726 bytes; each card is paid at most once between
  compactions (cards re-arm after a compaction or `/clear`), and only when its
  trigger fires. `cards/compact.md` (306 bytes) is not a card: PreCompact
  prints it as the compaction brief.
- **Skill** (`skills/<name>/SKILL.md`) -- the actionable checklist for one
  methodology, pulled in on demand when you invoke it or when the task matches
  its description. The skill and agent listings cost about 1,620 tokens;
  `claude --plugin-dir ./plugins/sutra plugin details sutra` prints the cost of
  every component.
- **Docs** (`docs/`) -- long-form references that stand alone outside Claude
  Code: the architect persona and the profile guide.

This is progressive disclosure: sessions pay for the contract by default, for
a card when its moment arrives, and for a skill's full procedure only when the
work calls for it.

## Extending Sutra

- Add a skill: create `plugins/sutra/skills/<name>/SKILL.md` with a
  `description` frontmatter line. It becomes `/sutra:<name>`.
- Add a subagent: drop a Markdown file with agent frontmatter in
  `plugins/sutra/agents/`.
- Add a rule that is always true to one profile layer: `core.md` if every
  profile except `off` should carry it, `standard.md` for `standard` and
  `strict`, `strict.md` for `strict` only. Never repeat it in a higher layer;
  the higher profiles already compose the lower ones.
- Add a rule that matters at one moment (a commit, a kind of edit, a tool
  result) as a card: write `cards/<id>.md` (and `cards/<id>.strict.md` for
  strict-only lines), call `card <id>` from the matching handler in
  `hooks/sutra.sh` (`on_prompt`, `post_edit`, `post_bash`, or `on_post_tool`),
  and add a case to `tests/hooks.sh`.
- Test the harness: `bash tests/hooks.sh`, and
  `BASH_UNDER_TEST=/bin/bash bash tests/hooks.sh` for macOS bash 3.2. The suite
  needs `jq`.
- Validate before publishing: `claude plugin validate --strict .` at the repo
  root, and `claude plugin validate --strict --profile directory ./plugins/sutra`
  for the plugin itself.

## Compatibility notes

- Plugin marketplaces, hook context injection (`additionalContext`, and
  `SessionStart` stdout), `${CLAUDE_PLUGIN_ROOT}`, and `${CLAUDE_PLUGIN_DATA}`
  are the load-bearing features. They are current Claude Code capabilities;
  older builds without `/plugin` cannot install Sutra.
- `hooks/sutra.sh` runs on bash 3.2 or later (the `/bin/bash` macOS ships) and
  uses perl with its core JSON::PP module to read hook payloads and write hook
  output.
- Every hook degrades to silence when its tooling is missing. Without perl or
  JSON::PP, the contract (SessionStart) and the compaction brief (PreCompact,
  which needs no perl) are still printed as plain text, and every other feature
  stays silent; without `CLAUDE_PLUGIN_DATA` the cards and the stop gate stay
  silent; without `CLAUDE_PLUGIN_ROOT`, or with no payload on standard input,
  the script exits without output.
