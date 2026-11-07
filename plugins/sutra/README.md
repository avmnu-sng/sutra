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
  prompt asks for them or after a commit or push runs, test, migration, doc,
  and code rules on the first such edit, delegation rules after a subagent
  returns, and an untrusted-content rule after a web fetch or search. Each
  card names the skill that holds the depth.
- **Hidden-Unicode warnings.** When Claude writes or reads a file, and at
  session start for the project's agent instruction files (`CLAUDE.md`,
  `AGENTS.md`, `GEMINI.md`, and the others listed under **Reads** below),
  Sutra looks for bidirectional controls, zero-width and invisible
  characters, and Unicode tag characters, and tells both Claude and you where
  they are.
- **Compaction brief.** Before a compaction, Sutra tells the summarizer what
  to keep: the task, decisions with reasons, files changed, checks run, and
  open or deferred items.
- **Verify-before-stop (strict only).** If Claude edited a file that is not a
  doc (code, config, or a script) and no check command ran since, Sutra asks
  it once to run the project's checks or say why they do not apply. A check
  command is a recognized test, lint, build, or type-check run, such as
  `make test`, `go test ./...`, `pytest`, or `./scripts/check.sh`; `git`,
  `echo`, and similar commands never count, so a commit message that names a
  tool does not silence it (`is_check` in `hooks/sutra.sh` has the rules). It
  never asks twice for the same edits, never when Claude is asking you a
  question, and `SUTRA_GATE=off` turns it off.

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
`profile` setting, then `standard`. A repository's `.sutra` file applies only
when you have set neither, and then only to raise the profile to `strict`: it
can never lower it or turn Sutra off, and Sutra tells you when it refuses one.

## What runs, and what it touches

Sutra ships two scripts. The hook script, `hooks/sutra.sh`, is wired in
`hooks/hooks.json` to five events: SessionStart, UserPromptSubmit,
PostToolUse (Write, Edit, MultiEdit, NotebookEdit, Read, Bash, WebFetch,
WebSearch, Agent, Task), PreCompact, and Stop. Each call has a 5 to 10 second
timeout. The hook script:

- **Reads:** the hook payload on standard input; `SUTRA_PROFILE`,
  `SUTRA_SECURITY`, `SUTRA_GATE`, and the plugin's own profile setting
  (`CLAUDE_PLUGIN_OPTION_PROFILE`); the project's `.sutra` file (first 64
  bytes, symbolic links ignored); the profiles and cards bundled with the
  plugin; at session start, the project's agent instruction files; and the
  file a tool just wrote or read. The instruction files are `CLAUDE.md`,
  `CLAUDE.local.md`, `.claude/CLAUDE.md`, `AGENTS.md`, `GEMINI.md`,
  `.cursorrules`, `.github/copilot-instructions.md`, `.claude/rules/*.md`,
  and up to 20 `CLAUDE.md` files one or two directories below the project
  root, outside `.git`, `.claude`, and `node_modules`. Each file is scanned in
  place for hidden characters and skipped when it is over 4 MiB. A file Claude
  wrote or read is also skipped as binary when its first 8 KiB holds a NUL
  byte; an instruction file is scanned even then, and the NUL is reported.
  File paths are opened with a three-argument open and never interpreted as
  commands.
- **Writes:** standard output (context for Claude, notices for you), and small
  per-session marker files under the plugin data directory Claude Code
  provides (`CLAUDE_PLUGIN_DATA`). Markers older than 14 days are pruned. A
  file path in a warning is quoted, with every character outside
  `[A-Za-z0-9._/@+-]` replaced by `?` and a long path shortened, so a crafted
  file name cannot add instructions.
- **Never:** network calls, seeking out or sending credentials (a file Claude
  has just read is scanned in place, and only its path, a line number, and a
  code point leave the script), blocking a tool call, editing your files, or
  changing settings.
- **Needs:** `bash` and `perl` with its core JSON::PP module. Without perl,
  the contract and the compaction brief are still printed as plain text and
  every other hook stays silent.

The workflow script, `workflows/build-orchestrator.workflow.js`, runs only
when you invoke `/sutra:build-orchestrator`; depending on your permission
mode, Claude Code asks you to approve the run first. Its agents edit your
files, run git and your test commands, and commit each validated slice to the
checked-out branch. Every agent is told never to push, switch branches, or
touch the default branch, and the run stops if a stage reports a different
branch. That check relies on what the agents report, so it cannot catch an
agent that misreports.

Review both before you install: read `hooks/hooks.json`, `hooks/sutra.sh`, and
`workflows/build-orchestrator.workflow.js`.
`claude --plugin-dir <path-to-this-folder> plugin details sutra` lists the
skills, agents, and hooks, but not the workflow. Its context cost covers only
the skill and agent listings: it counts the hooks as free, although the
contract the SessionStart hook adds costs about 340 to 840 tokens by profile,
and each card adds a few lines when it fires.

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
