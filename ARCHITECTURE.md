# Architecture

How Sutra is put together, and why it is shaped this way.

## The delivery problem

Claude Code can be extended two ways: standalone `.claude/` files in one
project, or a **plugin** distributed through a marketplace. Only the plugin
path gives you install-once, no-clone, versioned, auto-updating distribution.
So Sutra is a plugin.

But a plugin cannot ship two things people often want to share: a `CLAUDE.md`
(there is no "inject this memory" plugin field) and a saved Workflow. Sutra
works around both:

- **Always-on operating contract** is delivered by a `SessionStart` **hook**
  whose stdout Claude Code adds to the session context. This is the same
  mechanism a user-level memory-loader hook uses, applied from inside a plugin.
  No `CLAUDE.md` edit required.
- **Workflows** ship as plain files under `plugins/sutra/workflows/` (inside
  the plugin, so `${CLAUDE_PLUGIN_ROOT}` reaches them after install). A skill
  (`/sutra:scaffold-execution-plan`) copies the orchestrator into a target
  project's `.claude/workflows/` on request.

## One plugin, profile by environment

Rather than ship several plugins (core, strict, ...) that a user must install
in the right combination, Sutra ships **one** plugin and selects behavior with
a single variable, `SUTRA_PROFILE` (`lite` | `standard` | `strict` | `off`),
overridable per project by a `.sutra` file. This keeps the install to two
commands and makes "turn the rigor up" a one-word change.

The profiles are strictly layered supersets, so moving up never removes a rule,
only adds. `strict` also activates a PostToolUse guard -- but that guard
self-gates on the profile and only *warns*; it never blocks a write. Nothing in
Sutra can fail a user's own work. That is a hard invariant: an operating-style
kit must degrade to silence, never to obstruction.

## Layout

```
sutra/
  .claude-plugin/marketplace.json     # the catalog (name: sutra)
  plugins/sutra/
    .claude-plugin/plugin.json        # the plugin manifest (name: sutra)
    profiles/{lite,standard,strict}.md # injected operating contracts
    hooks/
      hooks.json                      # SessionStart injector + strict ASCII guard
      inject-profile.sh               # prints the active profile to stdout
      ascii-guard.sh                  # strict-only, non-blocking ASCII warning
    skills/<name>/SKILL.md            # invocable methodologies (/sutra:<name>)
    agents/<name>.md                  # dispatchable subagents (thin dispatchers)
    workflows/                        # distributable orchestration scripts
  docs/                               # install guide, profile guide, architect persona
  examples/                           # sample CLAUDE.md, AGENTS.md, settings, opt-in hooks
```

Everything a plugin references at runtime lives inside the plugin directory,
because Claude Code copies a plugin into a cache on install -- paths that reach
outside the plugin (`../`) would not resolve. Hook commands use
`${CLAUDE_PLUGIN_ROOT}` to find their scripts in that cache.

## Skills, profiles, and docs

Guidance appears at layered depths, by design:

- **Profile** -- the one-paragraph always-on version, injected every session.
- **Skill** (`skills/<name>/SKILL.md`) -- the actionable checklist for one
  methodology, pulled in on demand when you invoke it or when the task matches
  its description.
- **Docs** (`docs/`) -- long-form references that stand alone outside Claude
  Code: the architect persona and the profile guide.

This is progressive disclosure: sessions pay only for the profile by default,
and reach for the skill's full procedure when the work calls for it.

## Extending Sutra

- Add a skill: create `plugins/sutra/skills/<name>/SKILL.md` with a
  `description` frontmatter line. It becomes `/sutra:<name>`.
- Add a subagent: drop a Markdown file with agent frontmatter in
  `plugins/sutra/agents/`.
- Add a rule to a profile: edit the profile file; keep the layering (a rule in
  `standard` must also hold in `strict`).
- Validate before publishing: `claude plugin validate --strict .` at the repo
  root, and `claude plugin validate --strict --profile directory ./plugins/sutra`
  for the plugin itself.

## Compatibility notes

- Plugin marketplaces, `SessionStart` stdout injection, and
  `${CLAUDE_PLUGIN_ROOT}` are the load-bearing features. They are current
  Claude Code capabilities; older builds without `/plugin` cannot install Sutra.
- Hook scripts are `bash` (they use `set -o pipefail`) and depend on `perl` for the
  strict ASCII scan. If `perl` is absent, the guard degrades to silence.
