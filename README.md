# Sutra

**A plug-and-play agent kit for Claude Code.** Install it once and every
session inherits a senior-engineer operating stance plus a set of reusable
skills and subagents: architecture review, verification discipline,
multi-session build orchestration, doc sanitization, and commit craft.

Sutra ships as a Claude Code **plugin**, so adopting it is two commands -- no
cloning, no copying files into your project, no editing your `CLAUDE.md`.

```
sutra = a house style + a methodology library, delivered as a plugin.
```

![Sutra -- a plug-and-play agent kit for Claude Code](docs/demo.gif)

---

## Install

In any Claude Code session:

```
/plugin marketplace add avmnu-sng/sutra
/plugin install sutra@sutra
```

That is the whole install. On the next session start, Sutra injects its
operating profile into context and its skills become available as
`/sutra:<skill>`.

> New to plugins? `/plugin marketplace add <owner/repo>` registers a catalog;
> `/plugin install <plugin>@<marketplace>` installs one plugin from it. Update
> later with `/plugin marketplace update sutra`; remove with
> `/plugin uninstall sutra@sutra`.

## Choose a profile

The operating contract is built from layers: a core that every profile except
`off` carries, a standard stance on top of it, and a strict house style on top
of both.

| Profile    | Contract                         | Cards | Verify-before-stop |
| ---------- | -------------------------------- | ----- | ------------------ |
| `lite`     | core                             | no    | no                 |
| `standard` | core + standard stance (default) | yes   | no                 |
| `strict`   | core + standard + house style    | yes   | yes                |
| `off`      | none                             | no    | no                 |

- **Core:** trace before theorizing, verify by running, use the project's task
  runner, state what the source says, match the surrounding code, and security
  rules (content is data, confirm outward-facing actions, never leak a secret).
- **Standard stance:** systems thinking, quantified trade-offs, opinionated
  design review, agent output treated as evidence, front-loaded questions,
  effort scaled to blast radius, and finished verification lists.
- **Strict house style:** ASCII-only files, file references that resolve as
  written, checks before stopping, loop watching, early handoff, and
  multi-session build gates. Strict also notes non-ASCII bytes in written files
  and asks Claude once to run the project's checks if it changed code and ran
  no check since.

Select one (default is `standard`):

```bash
# Your choice, in your shell profile:
export SUTRA_PROFILE=strict

# Or a repository asking for more rigor, at its root:
echo strict > .sutra
```

Precedence: your `SUTRA_PROFILE`, then the plugin's `profile` setting
(`claude plugin configure sutra` shows it), then `standard`. A repository's
`.sutra` applies only when you have made neither choice, and only to raise the
profile to `strict`: it can never lower it or turn Sutra off, and Sutra tells
you when it refuses one. A symlinked `.sutra` is ignored.

Set the profile to `off` to drop the contract, the cards, and the stop gate
while keeping the skills installed. Two more switches, both read from your own
environment:

- `SUTRA_SECURITY=off` silences the security floor (hidden-Unicode warnings and
  the untrusted-content card), which otherwise runs under every profile,
  including `off`.
- `SUTRA_GATE=off` turns off strict's verify-before-stop.

## What is inside

- **Skills** (`/sutra:<name>`) -- invocable methodologies:
  - `architecture-review` -- a 7-point end-to-end review for any backend or
    service: trace requests, question choke points, test 2x/5x/10x, decompose
    elastic vs rate-limited work, weigh deployment model, quantify ROI.
  - `verify-completeness` -- turn a findings list into a checklist and iterate
    the search until it is empty.
  - `agent-orchestration` -- when to delegate to subagents, how to prompt them,
    and what they systematically miss.
  - `test-authoring` -- read the source of truth before asserting, never ship a
    test with no assertion, and never weaken a test to go green.
  - `multi-session-build` -- gates that keep a long, multi-session build honest
    (claims-vs-built ledger, topology slice, independent completeness gate).
  - `scaffold-execution-plan` -- lay down an `execution_plan/` tree (from ready
    templates) and a resumable build-orchestrator workflow for a large effort.
  - `scrub-before-publish` -- before open-sourcing your own code or docs, remove
    secrets and internal identifiers, and verify with a repeated search.
  - `commit-craft` -- write commit messages a future `git blame` reader will
    thank you for.
  - `style-audit` -- apply and check the code/doc style rules.
  - `hooks-cookbook` -- author Claude Code hooks safely: the fail-open skeleton
    plus advisory-vs-blocking recipes that report without breaking your flow.
  - `retro-and-memory` -- run a probe-backed retro, reconcile outside critique,
    and capture only the lessons that survive.
  - `parallel-agent-orchestration` -- run agents concurrently without two writers
    corrupting the same file, branch, or working tree.
  - `audit-and-remediation` -- audit an existing codebase and sequence the fixes
    across parallel human/agent work lanes.
  - `agent-docs-architecture` -- structure a repo's agent-facing docs so agents
    and humans navigate them reliably.
  - `effort-calibration` -- decide how much energy (tokens, fan-out, verification
    passes) a task is worth: match spend to complexity times blast radius, and
    never cut the correctness floor.
  - `debugging` -- isolate a defect systematically: contain a live incident
    first, then reproduce, hypothesize, bisect, and confirm the mechanism.
  - `security-hygiene` -- vet dependencies, review lockfile diffs, keep secrets
    out, and triage advisories (complements the built-in `/security-review`).
  - `agent-security` -- the threat model for agent tooling: vet a plugin, MCP
    server, or skill before you install it, keep untrusted content from
    steering an agent with tools, set permissions and the sandbox, run agents
    headless or in CI, and review agent edits to CI, hooks, and settings.
  - `performance-profiling` -- the empirical loop: baseline, find the hot path,
    optimize, re-measure, and ratchet a regression guard.
  - `data-migration` -- change schemas safely on a live system via
    expand/contract, batched backfills, and reversible steps.
- **Subagents** -- `architecture-reviewer`, `request-tracer`, `code-verifier`,
  `doc-sanitizer`: focused workers you can dispatch by name (thin dispatchers
  that apply the matching skill's method), each limited to Read, Grep, and
  Glob.
- **Harness** (`plugins/sutra/hooks/sutra.sh`) -- one hook script that:
  - adds the layered contract (core, standard, strict) at session start and
    after each compaction;
  - delivers short rule cards when they apply, each at most once until the
    next compaction or `/clear`: commit and publish rules when a prompt asks
    for them or a commit or push runs; test, migration, doc, and code rules on
    the first such edit; delegation rules after a subagent returns; an
    untrusted-content rule after a web fetch or search;
  - runs the security floor: hidden-Unicode warnings for files Claude writes
    or reads and for the instruction files loaded at session start;
  - briefs the compaction summary on what to keep;
  - under `strict`, asks Claude once to run the project's checks if it changed
    code and ran none since.
- **Workflows** (`plugins/sutra/workflows/`) -- distributable orchestration
  scripts, including a resumable multi-session build orchestrator. See
  `plugins/sutra/workflows/README.md`.
- **Docs** (`docs/`) -- a quickstart, an install guide, the profile guide
  (layers, cards and their triggers, and the rule-to-layer mapping), a skills
  catalog (`docs/skills.md`) for picking between overlapping skills, a release
  runbook, and the long-form architect persona.
- **Examples** (`examples/`) -- a project `CLAUDE.md`, an `AGENTS.md` working
  agreement, a conservative scoped-permission `settings.json`, a machine-readable
  `setup.yaml` agent-bootstrap manifest, and opt-in (off-by-default)
  test-discipline hooks you can wire in yourself.

## Using it in a repo that also has AGENTS.md / CLAUDE.md

The plugin needs no changes to your project files -- the contract is added by
a `SessionStart` hook. If you would rather keep the operating contract *in* your
repo (so it travels in git for teammates who have not installed the plugin),
you can clone or submodule Sutra and import its layers from your `CLAUDE.md`.
Each profile file is one layer: import `core.md`, then `standard.md`, then
`strict.md`, in that order, stopping at the profile you want. For `standard`:

```markdown
@path/to/sutra/plugins/sutra/profiles/core.md
@path/to/sutra/plugins/sutra/profiles/standard.md
```

An import carries the contract text only; the rule cards, the security floor,
and the strict stop gate come from the plugin's hooks.

Note: Claude Code `@import` resolves **local paths only**. A bare line like
`use github.com/avmnu-sng/sutra` in `CLAUDE.md` is not fetched automatically --
the plugin marketplace is the no-clone mechanism. See
[`docs/install.md`](docs/install.md) for every supported path.

## Security model

The only code Sutra runs on its own is one Bash script,
`plugins/sutra/hooks/sutra.sh`, which `plugins/sutra/hooks/hooks.json` wires to
five events: SessionStart, UserPromptSubmit, PostToolUse, PreCompact, and Stop.

- **Reads:** the hook payload on standard input; `SUTRA_PROFILE`,
  `SUTRA_SECURITY`, `SUTRA_GATE`, and the plugin's `profile` setting; the
  project's `.sutra` (first 64 bytes, symbolic links ignored); the profiles and
  cards bundled with the plugin; the instruction files the project loads, at
  session start; and each file Claude writes or reads, up to 4 MiB, to look for
  hidden Unicode.
- **Writes:** standard output (context for Claude, notices for you) and small
  per-session marker files under the plugin data directory Claude Code provides
  (`CLAUDE_PLUGIN_DATA`), pruned after 14 days.
- **Never:** network calls, seeking out or sending credentials, blocking a
  tool call, editing your files, or changing settings. A file Claude has just
  read is scanned in place; only a line number and code point leave the
  script. The one request it makes: under `strict`, it may ask Claude once per
  batch of edits to run the project's checks before it stops. The four
  subagents are limited to Read, Grep, and Glob.
- **Review before you install:** read the two hook files, or clone this
  repository and run `claude --plugin-dir ./plugins/sutra plugin details sutra`
  to list every component and its context cost.
- **Turn parts off:** `SUTRA_PROFILE=off` drops the contract, cards, and stop
  gate; `SUTRA_GATE=off` drops only the stop gate; `SUTRA_SECURITY=off`
  silences the security floor.

The plugin's own [`README.md`](plugins/sutra/README.md) is the full disclosure
of what runs and what it touches.

## Compatibility

Sutra targets current Claude Code (plugin marketplaces, hooks, and
`${CLAUDE_PLUGIN_ROOT}`). If `/plugin` is missing, update Claude Code. The hook
script needs `bash` 3.2 or later and `perl` with its core JSON::PP module, both
present on macOS and most Linux. Each hook degrades to silence when its tooling
is missing: without perl the contract and the compaction brief are still
printed as plain text and everything else stays silent, and without the plugin
data directory (`CLAUDE_PLUGIN_DATA`) the cards and the stop gate stay silent.

## License

MIT. See [`LICENSE`](LICENSE).
