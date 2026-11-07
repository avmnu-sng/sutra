# Changelog

All notable changes to Sutra are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims
to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A just-in-time harness: one hook dispatcher, `hooks/sutra.sh`, wired to
  SessionStart, UserPromptSubmit, PostToolUse, PreCompact, and Stop.
- Rule cards (`plugins/sutra/cards/`) delivered once per session at the moment
  they apply -- commit, publish, migration, test edit, doc edit, code edit,
  delegation, and untrusted content -- and re-armed after a compaction.
- A security floor in every profile, including `off`: hidden-Unicode warnings
  (bidirectional controls, zero-width and invisible characters, tag characters)
  for files Claude writes or reads and for the instruction files Claude Code
  loads at session start, plus an untrusted-content card after web fetches and
  searches. `SUTRA_SECURITY=off` disables it.
- Verify-before-stop under `strict`: one nudge to run the project's checks when
  code changed with no check run since. `SUTRA_GATE=off` disables it.
- A compaction brief that tells the summarizer what to keep.
- A `profile` plugin setting, and `documentationUrl` and `supportUrl` for the
  directory listing.
- The `agent-security` skill, with a sourced threat reference.
- A plugin-folder README that discloses everything the hooks run, read, and
  write; a LICENSE in the plugin folder; a 512x512 listing icon.
- `tests/hooks.sh`, behavior tests for the dispatcher on bash 3.2 and 5.

### Changed

- Profiles are composed from layers (`core.md`, `standard.md`, `strict.md`), so
  `strict` now carries the standard stance; `lite.md` became `core.md`.
  Moment-specific rules moved into cards, shrinking the standard contract from
  4,603 to 2,481 bytes.
- A repository's `.sutra` can only raise the profile. `SUTRA_PROFILE` and the
  plugin setting outrank it, and a refused downgrade is reported.
- `architecture-reviewer` runs with Read, Grep, and Glob only.
- Hook commands quote `${CLAUDE_PLUGIN_ROOT}` and set explicit timeouts.
- The hooks-cookbook freshness recipe no longer fetches from a hook.
- Validation docs use `claude plugin validate --strict --profile directory`.

### Removed

- `hooks/inject-profile.sh` and `hooks/ascii-guard.sh`, replaced by
  `hooks/sutra.sh`.

### Security

- The strict ASCII guard read written files through perl's two-argument open,
  so a file name ending in `|` ran as a shell command. Files are now opened
  with a three-argument open, and all hook JSON is parsed and built with
  JSON::PP.

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
