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

Sutra has three layered profiles. Each is a superset of the one before it.

| Profile    | What you get                                                                 |
| ---------- | ---------------------------------------------------------------------------- |
| `lite`     | A light nudge: trace before theorizing, use build tools, verify by running.  |
| `standard` | The full operating stance: systems thinking, quantified trade-offs, agent and verification discipline, comment/doc style. **(default)** |
| `strict`   | `standard` plus a hard house style: ASCII-only files, commit and branch discipline, copy-pasteable file references, multi-session build gates. Turns on a non-blocking ASCII warning. |

Select one (default is `standard`) either globally or per project:

```bash
# Globally, in your shell profile:
export SUTRA_PROFILE=strict

# Or per project, at the project root:
echo strict > .sutra
```

Set it to `off` to inject nothing while keeping the skills installed.

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
  - `performance-profiling` -- the empirical loop: baseline, find the hot path,
    optimize, re-measure, and ratchet a regression guard.
  - `data-migration` -- change schemas safely on a live system via
    expand/contract, batched backfills, and reversible steps.
- **Subagents** -- `architecture-reviewer`, `request-tracer`, `code-verifier`,
  `doc-sanitizer`: focused workers you can dispatch by name (thin dispatchers
  that apply the matching skill's method).
- **Profiles** -- the `lite` / `standard` / `strict` operating contracts above.
- **Workflows** (`plugins/sutra/workflows/`) -- distributable orchestration
  scripts, including a resumable multi-session build orchestrator. See
  `plugins/sutra/workflows/README.md`.
- **Docs** (`docs/`) -- a quickstart, an install guide, the profile guide (with
  the full rule-to-profile mapping), a skills catalog (`docs/skills.md`) for
  picking between overlapping skills, a release runbook, and the long-form
  architect persona.
- **Examples** (`examples/`) -- a project `CLAUDE.md`, an `AGENTS.md` working
  agreement, a conservative scoped-permission `settings.json`, a machine-readable
  `setup.yaml` agent-bootstrap manifest, and opt-in (off-by-default)
  test-discipline hooks you can wire in yourself.

## Using it in a repo that also has AGENTS.md / CLAUDE.md

The plugin needs no changes to your project files -- the profile is injected by
a `SessionStart` hook. If you would rather keep the operating contract *in* your
repo (so it travels in git for teammates who have not installed the plugin),
you can clone or submodule Sutra and reference a profile from your `CLAUDE.md`:

```markdown
@path/to/sutra/plugins/sutra/profiles/standard.md
```

Note: Claude Code `@import` resolves **local paths only**. A bare line like
`use github.com/avmnu-sng/sutra` in `CLAUDE.md` is not fetched automatically --
the plugin marketplace is the no-clone mechanism. See
[`docs/install.md`](docs/install.md) for every supported path.

## Compatibility

Sutra targets current Claude Code (plugin marketplaces, `SessionStart` hooks,
and `${CLAUDE_PLUGIN_ROOT}`). If `/plugin` is missing, update Claude Code. The
hook scripts are `bash` and use `perl` (present on macOS and most Linux)
for the strict ASCII check.

## License

MIT. See [`LICENSE`](LICENSE).
