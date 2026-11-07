# Sutra

Sutra is a senior-engineer operating system for Claude Code. It gives every
session a short operating contract, delivers focused rules at the moment they
apply, warns about hidden Unicode that can smuggle instructions past a human
reviewer, and ships twenty methodology skills, four read-only subagents, and
a resumable build-orchestrator workflow. Nothing in it calls the network or
seeks out a credential.

## Install

In Claude Code 2.1.275 or later:

```
/plugin install sutra --marketplace avmnu-sng/sutra
```

On older builds, add the marketplace first, then install:

```
/plugin marketplace add avmnu-sng/sutra
/plugin install sutra@sutra
```

## What it adds to a session

- **Operating contract.** At session start Sutra adds a layered contract to
  the context: a core (trace before theorizing, verify by running, a security
  floor), plus a standard stance, plus a strict house style, depending on the
  profile. It is added again after a compaction.
- **Rule cards.** Short rules arrive when they become actionable, each at most
  once until the next compaction or `/clear`: commit and publish rules when a
  prompt asks for them or a commit or push runs, test, migration, doc, and
  code rules on the first such edit, delegation rules after a subagent
  returns, and an untrusted-content rule after a web fetch or search. Each
  card names the skill that holds the depth.
- **Hidden-Unicode warnings.** When Claude writes or reads a file, and at
  session start for the instruction files Claude Code loads (CLAUDE.md,
  CLAUDE.local.md, AGENTS.md, rules files), Sutra looks for bidirectional
  controls, zero-width and invisible characters, and Unicode tag characters,
  and tells both Claude and you where they are.
- **Compaction brief.** Before a compaction, Sutra tells the summarizer what
  to keep: the task, decisions with reasons, files changed, checks run, and
  open or deferred items.
- **Verify-before-stop (strict only).** If Claude changed code and ran no
  check since, Sutra asks it once to run the project's checks or say why they
  do not apply. It never asks twice for the same edits, never when Claude is
  asking you a question, and `SUTRA_GATE=off` turns it off.

## Profiles and settings

| Profile    | Contract                         | Cards | Verify-before-stop |
| ---------- | -------------------------------- | ----- | ------------------ |
| `lite`     | core                             | no    | no                 |
| `standard` | core + standard stance (default) | yes   | no                 |
| `strict`   | core + standard + house style    | yes   | yes                |
| `off`      | none                             | no    | no                 |

The security floor (hidden-Unicode warnings and the untrusted-content card)
runs under every profile, including `off`; set `SUTRA_SECURITY=off` in your own
environment to silence it.

Precedence: your `SUTRA_PROFILE` environment variable, then this plugin's
`profile` setting, then `standard`. A repository's `.sutra` file may raise the
profile to `strict` but can never lower it or turn Sutra off; Sutra tells you
when it refuses one.

## What runs, and what it touches

Sutra ships two scripts. The hook script, `hooks/sutra.sh`, is wired in
`hooks/hooks.json` to five events: SessionStart, UserPromptSubmit,
PostToolUse (Write, Edit, MultiEdit, NotebookEdit, Read, Bash, WebFetch,
WebSearch, Agent, Task), PreCompact, and Stop. Each call has a 5 to 10 second
timeout. The hook script:

- **Reads:** the hook payload on standard input; `SUTRA_PROFILE`,
  `SUTRA_SECURITY`, `SUTRA_GATE`, and the plugin's own profile setting; the
  project's `.sutra` file (first 64 bytes, symbolic links ignored); the
  profiles and cards bundled with the plugin; and the file a tool just wrote
  or read, up to 4 MiB, to look for hidden characters. File paths are opened
  with a three-argument open and never interpreted as commands.
- **Writes:** standard output (context for Claude, notices for you), and small
  per-session marker files under the plugin data directory Claude Code
  provides (`CLAUDE_PLUGIN_DATA`). Markers older than 14 days are pruned.
- **Never:** network calls, seeking out or sending credentials (a file Claude
  has just read is scanned in place, and only a line number and code point
  leave the script), blocking a tool call, editing your files, or changing
  settings.
- **Needs:** `bash` and `perl` with its core JSON::PP module. Without perl,
  the contract and the compaction brief are still printed as plain text and
  every other hook stays silent.

The workflow script, `workflows/build-orchestrator.workflow.js`, runs only
when you invoke `/sutra:build-orchestrator` and approve the run. Its agents
edit your files, run git and your test commands, and commit each validated
slice to the checked-out branch. Every agent is told never to push, switch
branches, or touch the default branch, and the run stops if the checked-out
branch changes.

Review both before you install: read `hooks/hooks.json`, `hooks/sutra.sh`, and
`workflows/build-orchestrator.workflow.js`, or run
`claude --plugin-dir <path-to-this-folder> plugin details sutra` to list every
component and its context cost.

## Skills, agents, and the workflow

- **Skills** (`/sutra:<name>`): architecture review, verification, test
  authoring, debugging, data migration, performance profiling, commit craft,
  multi-session builds and execution plans, parallel agent orchestration,
  security hygiene, agent security, publishing scrubs, style audits, hooks
  authoring, retros, effort calibration, and agent-facing docs.
- **Subagents:** `architecture-reviewer`, `code-verifier`, `doc-sanitizer`,
  and `request-tracer`, each limited to Read, Grep, and Glob.
- **Workflow:** `/sutra:build-orchestrator` drives a value-ranked execution
  plan one slice at a time: build, adversarial review, bounded fix,
  independent validation, then one commit per validated slice. It stops at the
  first slice that does not validate, leaving that work uncommitted, and never
  pushes. `/sutra:scaffold-execution-plan` lays down the plan it reads; see
  `workflows/README.md`.

Full documentation, the threat model, and the release notes live in the
repository: https://github.com/avmnu-sng/sutra

## License

MIT. See the LICENSE file in this folder.
