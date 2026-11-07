# Examples

Copy-and-adapt templates for wiring `sutra` into a real project.

**Everything in this directory is optional.** The sutra plugin works on its
own once installed -- none of these files are required to use it. They exist
to solve the next set of problems: making the profile travel with a repo,
layering project-specific rules on top of it, and locking down what an agent
may run. Treat each file as a starting point: copy it out, delete what you do
not need, and replace every placeholder with real values for your project.

## What is here

| File | Purpose | You need it when... |
| --- | --- | --- |
| `CLAUDE.md.example` | In-repo import of the sutra profile | Teammates or CI check out the repo without the plugin installed |
| `AGENTS.md.example` | Project-specific guardrails that compose with the profile | You want repo-local commands and invariants an agent cannot guess |
| `settings.json` | Conservative scoped-permission allowlist + task-runner entrypoint | You want to cap what Claude Code may run in this repo |
| `hooks/` | Opt-in, off-by-default enforcement hooks | You want automated gates that block on violations, not just guidance |

## `CLAUDE.md.example`

An optional way to adopt the sutra profile *in the repository itself*, so that
teammates who have **not** installed the plugin still pick up its guidance when
they open the project in Claude Code.

You usually do not need this. If a teammate has the sutra plugin installed, the
profile is already active for them globally -- no `CLAUDE.md` change required.
Reach for the in-repo approach only when you want the profile to travel *with*
the repository: for contributors on a clean checkout, or for CI and agent runs
that start from bare source.

The template documents two mutually exclusive ways to wire it up:

- **Option A -- vendored `@import`.** Vendor the sutra repo into your project
  (submodule, subtree, or a plain clone under `vendor/`) and `@import` its
  profile layers in order, stopping at the profile you want: `core.md`
  (`lite`), then `standard.md` (`standard`), then `strict.md` (`strict`).
  `@import` resolves **local paths only** -- it cannot fetch a URL or a remote
  git ref, so the vendored copy must be checked in and present on disk. This
  works for everyone, plugin or not.
- **Option B -- a `.sutra` marker.** If everyone on the team already has the
  plugin and you want `strict`, drop a one-line `.sutra` containing `strict`
  at the repo root. It raises the profile to `strict` for teammates who have
  not chosen one themselves (`SUTRA_PROFILE` or the plugin's `profile`
  setting); a `.sutra` naming `lite` or `off` is refused, and `standard` is
  already the default. Lightest touch, but it does nothing for a checkout
  without the plugin.

Pick one, not both, so there is a single source of truth for which profile
applies. Below the wiring, the template leaves a **Project specifics** section
for the build/test/lint commands, conventions, and layout an agent needs.

## `AGENTS.md.example`

Project-specific guardrails that **compose with** sutra rather than restating
it. The profile -- general working style, review posture, and safety defaults
-- comes from the plugin (or a local `@import` if you vendor a copy). This file
stays focused on what is unique to one repository:

- The exact task-runner entrypoints (`check`, `test`, `lint`, `build`) and why
  to prefer the runner over raw commands.
- Non-negotiable invariants a newcomer could not guess -- never weaken a test
  to make it pass, one feature per branch/commit/PR, keep files ASCII, do not
  commit planning or agent-only scratch files.
- Edit discipline for existing code -- match surrounding style, keep diffs
  minimal, no drive-by refactors.
- A "where things live" map so an agent can orient without guessing.

Keep generic guidance out of it; that belongs in the profile. The highest-value
lines are the repo-specific invariants -- a required column order, a cache byte
layout, a load-order dependency, an env var that must be unset in a subprocess.

## `settings.json`

A starting-point permission allowlist plus a task-runner entrypoint. Copy it to
`.claude/settings.json` in your repo and adapt the lists to your toolchain.

Be clear-eyed about what it is: a prompt-reduction convenience for a repo you
trust, NOT a security sandbox. It pre-approves read-only git inspection
(`status`, `diff`, `log`, `show`, `branch`), directory and file reads (`ls`,
`cat`, `rg`, `grep`, `Read`), and your task runners (`task`, `make`). Those last
two run whatever targets your project defines, so allowing them is trusting your
own build, not a read-only grant. The `deny` list (`rm -rf`, force push) is a
coarse backstop that is trivially sidestepped (`rm -fr`, `git reset --hard`) --
do not lean on it. The real boundary is Claude Code's default: anything not on
the allowlist still stops for explicit approval. Trim the allowlist to only what
you are comfortable auto-approving.

**It is strict JSON.** No comments, no trailing commas -- a `//` or `/* */` line
will break parsing. Keep your notes in this README or a separate doc, not in the
settings file. Adapt the `allow` and `deny` lists to your own runner and tools
before relying on it.

## `hooks/`

**Opt-in and off by default.** Hooks are enforcement gates that run
automatically and can *block* an action on a violation -- stronger than the
advisory guidance a profile provides. Nothing here is wired in until you add it
to your own settings, so the plugin never imposes a hook you did not ask for.

See [`hooks/README.md`](hooks/README.md) for the available hooks and how to
wire each one into your settings.

---

None of these files are needed to run sutra. They are here to copy, trim, and
adapt -- start from the one that solves a problem you actually have, and leave
the rest.
