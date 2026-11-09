# Sutra

Sutra is a senior-engineer methodology kit for Claude Code: twenty skills and
four read-only subagents for architecture review, verification, test
authoring, debugging, data migration, performance work, commit craft,
multi-session builds, and agent security. This plugin is Markdown only. It
ships no hooks, scripts, or servers, so nothing in it runs on its own.

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

## Skills and agents

- **Skills** (`/sutra:<name>`): architecture review, verification, test
  authoring, debugging, data migration, performance profiling, commit craft,
  multi-session builds and execution plans, parallel agent orchestration,
  security hygiene, agent security, publishing scrubs, style audits, hooks
  authoring, retros, effort calibration, and agent-facing docs.
- **Subagents:** `architecture-reviewer`, `code-verifier`, `doc-sanitizer`,
  and `request-tracer`, each limited to Read, Grep, and Glob.

## What it touches

A skill is a set of instructions. Claude loads one when a task matches its
description or when you run `/sutra:<name>`, and then works only through the
tools your permission settings allow. Some skills include example commands
for you or Claude to run; none runs on its own. The subagents can only read.

`claude --plugin-dir <path-to-this-folder> plugin details sutra` lists every
skill and agent with its context cost: about 1,600 tokens of listings in every
session, and each skill's body only when it is used.

## Examples

Run a skill by name with the task after it, or describe the task and let
Claude pick the skill from its description:

- `/sutra:architecture-review Review the payments service: trace one request
  end to end and tell me what breaks first at 10x load.` Claude traces the real
  code path, works through 2x, 5x, and 10x with numbers, and ranks each fix by
  its return.
- `/sutra:test-authoring Cover the edge cases in the date parser, and show which
  assertion fails if the parser regresses.` Claude reads the source of truth
  first, then writes tests that fail when the behavior breaks.
- `/sutra:debugging The nightly export hangs since yesterday's deploy; find out
  why.` Claude reproduces the problem, narrows it with a bisect, and proves the
  mechanism before it calls the bug fixed.
- `/sutra:commit-craft Write the commit message for my staged changes.` Claude
  writes a message a future reader of `git blame` can use.

## Data

This plugin collects no data. It is Markdown instructions and read-only
subagent definitions, so it stores nothing and sends nothing anywhere. What
Claude does while following a skill happens under your own Claude account and
your permission settings.

## Troubleshooting

- **A skill does not appear.** Run `/reload-plugins` or start a new session.
- **Which version do I have?** `claude plugin list` shows it.
- **A subagent or skill misbehaves.** Skills and subagents are plain Markdown:
  read the one involved under `skills/` or `agents/` in this plugin to see what
  it told Claude to do.

## Support

Report a problem or ask a question in the repository's
[issue tracker](https://github.com/avmnu-sng/sutra/issues). To report a security
issue, follow `SECURITY.md` in the repository.

## The harness

The companion plugin `sutra-harness`, from the same marketplace, adds the
parts that run automatically: a layered operating contract at session start,
short rule cards when they apply, hidden-Unicode warnings, a compaction brief,
a verify-before-stop nudge under the strict profile, and the
`/sutra-harness:build-orchestrator` workflow. It runs a Bash hook script, so
it is installed from the GitHub marketplace rather than Anthropic's plugin
directory:

```
/plugin marketplace add avmnu-sng/sutra
/plugin install sutra-harness@sutra
```

Installing it also installs this plugin from the same marketplace. If you
have this plugin from another source, keep one copy: uninstall a copy from
another marketplace with `claude plugin uninstall sutra@<marketplace>`, or
disable one synced from claude.ai (`sutra@synced`) in the `/plugin` Installed
tab.

The [full documentation](https://github.com/avmnu-sng/sutra#readme), the threat
model, and the release notes live in the repository.

## License

MIT. See the LICENSE file in this folder.
