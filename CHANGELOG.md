# Changelog

All notable changes to Sutra are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims
to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-07-14

Initial release.

### Added

- Plugin marketplace (`.claude-plugin/marketplace.json`) and the `sutra`
  plugin, installable with `/plugin marketplace add avmnu-sng/sutra` and
  `/plugin install sutra@sutra`.
- Layered operating profiles `lite`, `standard`, and `strict`, injected at
  session start and selected with `SUTRA_PROFILE` or a per-project `.sutra`
  file.
- Skills: `agent-docs-architecture`, `agent-orchestration`,
  `architecture-review`, `audit-and-remediation`, `commit-craft`,
  `data-migration`, `debugging`, `effort-calibration`, `hooks-cookbook`,
  `multi-session-build`, `parallel-agent-orchestration`,
  `performance-profiling`, `retro-and-memory`, `scaffold-execution-plan`,
  `scrub-before-publish`, `security-hygiene`, `style-audit`, `test-authoring`,
  `verify-completeness`.
- Execution-plan templates under `scaffold-execution-plan/templates/` (master
  plan, session protocol, dev loop, slice index, brief/handoff/kickoff).
- Release-milestone planning: a release-milestones section in the master-plan
  template, a "Cutting a release" procedure in the scaffold skill, and a
  per-slice changelog handoff block.
- Examples: a project `CLAUDE.md`, an `AGENTS.md` working agreement, a scoped
  `settings.json` permission allowlist, a `setup.yaml` agent-bootstrap manifest,
  and opt-in test-discipline hooks.
- Subagents (thin dispatchers over the matching skills): `architecture-reviewer`,
  `request-tracer`, `code-verifier`, `doc-sanitizer`.
- A resumable multi-session build-orchestrator workflow.
- Docs: quickstart, install guide, profile guide, a skills catalog
  (`docs/skills.md`), a release runbook (`docs/releasing.md`), and the architect
  persona.
- A CI workflow (`.github/workflows/ci.yml`) enforcing ASCII-only files,
  JSON/YAML validity, shell-script syntax, and skill/agent frontmatter.
