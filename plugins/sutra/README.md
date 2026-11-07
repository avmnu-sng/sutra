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

Full documentation, the threat model, and the release notes live in the
repository: https://github.com/avmnu-sng/sutra

## License

MIT. See the LICENSE file in this folder.
