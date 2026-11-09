# Changelog

All notable changes to Sutra are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims
to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- `hooks-cookbook/SKILL.md` no longer carries the link to the hooks reference,
  and it and `agent-security/SKILL.md` no longer name the harness's off
  switches, to address a plugin directory hold for using a credential from the
  user's machine. The plugin reads no credential. The switches stay documented
  in the `sutra-harness` README, and the link in
  `agent-security/reference/threats.md`.
- The commit-guard recipes in `hooks-cookbook/reference/recipes.md` take the
  denylist from their `deny=` line and no longer read an override from the
  environment.
- `agent-security/reference/commands.md` describes package launchers and
  download tools by category instead of by command name, because the directory
  warns about those commands in any text it reads. It also describes credential
  files by kind instead of by path.
- `scaffold-execution-plan`, `multi-session-build`, `agent-docs-architecture`,
  and the `sutra` README no longer imply that a directory install includes
  `sutra-harness` or a sample `examples/setup.yaml`.
- `directory-policy` in `scripts/check.sh` keeps launcher and download tool
  names out of every text file in `plugins/sutra`, not only entry files, and
  refuses ICO images, which the checklist holds for a reviewer.
- `docs/releasing.md` covers Warning results, says how to tell whether portal
  Validate reports holds, and says that a merge to `main` starts a new scan.

## [0.3.1] - 2026-11-09

### Fixed

- Removed the `skills:` frontmatter key from `architecture-reviewer` and
  `code-verifier`. The plugin directory refuses frontmatter keys outside its
  list from an organization that is not Verified. Each agent now reads its
  skill file directly and falls back to the summary in its own text.
- Removed `icon`, `documentationUrl`, and `supportUrl` from `sutra`'s
  `plugin.json`. The directory reads them only at the first submission and
  reports them on every later scan. `claude plugin validate` still finds the
  icon at `assets/icon.png`; the listing icon is set at the first submission
  or through **Contact Anthropic**.

### Changed

- `hooks-cookbook` moves its hook skeleton to `reference/skeleton.md`, and
  `agent-security` moves its scan, red-flag list, and permission examples to
  `reference/commands.md`; each `SKILL.md` links to them. Neither `SKILL.md`
  now names a download tool or package launcher or reads an environment
  variable.
- The `retro-and-memory` endpoint example uses a task-runner probe.

### Added

- The `sutra` README has example prompts, a data statement, troubleshooting,
  and support links, as the directory policy requires.
- `directory-policy` in `scripts/check.sh` allows only frontmatter keys that
  have passed a directory scan, keeps launcher names and environment reads out
  of entry files, and refuses the listing keys.
- `docs/releasing.md` validates each release branch in the portal before it
  merges, because the local commands do not run the directory's checks.

## [0.3.0] - 2026-11-07

Sutra is now two plugins, so that its skills can be listed in Anthropic's
plugin directory, which accepts hooks, workflow scripts, and files other than
Markdown, text, JSON, YAML, and a few image types only from Verified
organizations.

### Changed

- **Breaking:** the hooks, the contract layers (`profiles/`), the rule cards,
  and the build-orchestrator workflow moved from `sutra` to a new plugin in
  the same marketplace, `sutra-harness`, which depends on `sutra`. Updating
  `sutra` removes them; install the harness to keep the contract, the cards,
  the security floor, and the stop gate:

  ```
  /plugin marketplace update sutra
  /plugin install sutra-harness@sutra
  ```

  A marketplace pinned to `v0.2.0` stays on that tag, which has no
  `sutra-harness`; move the pin first (`docs/install.md`, Updating).
- **Breaking:** the workflow runs as `/sutra-harness:build-orchestrator`.
- **Breaking:** the `profile` setting moved to `sutra-harness`. If you had set
  it on `sutra`, set it again with
  `claude plugin configure sutra-harness@sutra`. `SUTRA_PROFILE` and `.sutra`
  work as before.
- **Breaking:** the contract layers moved to
  `plugins/sutra-harness/profiles/`. If your `CLAUDE.md` imports them from a
  vendored copy, change each `@<path>/plugins/sutra/profiles/<layer>.md` to
  `@<path>/plugins/sutra-harness/profiles/<layer>.md`; the old paths no
  longer exist, so the contract stops loading until you do.
- `sutra` is Markdown only: twenty skills, four read-only subagents, and the
  icon.
- The harness keeps its markers in its own plugin data directory. The 0.2.0
  markers under `~/.claude/plugins/data/sutra-sutra/` are no longer read and
  can be deleted.
- Reworded hooks-cookbook, agent-security, and session-protocol prose that
  read as code fetching remote scripts or using your credentials; the
  guidance is unchanged.
- `scaffold-execution-plan` and `parallel-agent-orchestration` name the
  harness's workflow README instead of a `${CLAUDE_PLUGIN_ROOT}` path, which
  resolves to `sutra` inside a skill, and no longer link to it on the web.
- `architecture-reviewer` and `code-verifier` preload the skill they apply,
  instead of telling a subagent without the Skill tool to load it.

### Added

- `sutra-harness` has its own README disclosing what it runs, reads, and
  writes, a LICENSE, and the icon.
- `scripts/check.sh` checks `manifests` (each marketplace entry matches its
  plugin folder, each dependency names a plugin in the marketplace, both
  plugins carry one version, and `CHANGELOG.md` has a section for it) and
  `directory-policy` (`plugins/sutra` holds only the file types and names the
  directory accepts, with no hook, workflow, server, load-time shell command,
  or package manager file, and no manifest key that can run code).
- CI validates each plugin, and `sutra` against the directory profile.

### Fixed

- Invoking `/sutra:hooks-cookbook` or `/sutra:agent-security` with arguments
  no longer corrupts their example code: Claude Code replaces `$1` in a skill
  with an argument, so the examples write `${1}`.
- The hooks-cookbook wiring example no longer shows Claude a path into the
  installed `sutra`: Claude Code substitutes the plugin-root variable in a
  skill, so the literal line moved to `reference/recipes.md`.
- The agent-security threat reference credits the hidden-Unicode warnings and
  the untrusted-content card to `sutra-harness`, not to the skills plugin.
- The documented `claude plugin configure` commands use the full plugin id,
  which the command requires.

## [0.2.0] - 2026-11-07

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
- `SECURITY.md` (private vulnerability reporting) and `docs/security.md` (the
  threat model, an OWASP mapping, and a hardening guide).
- `scripts/check.sh`, one gate for contributors and CI: a byte-level ASCII and
  NUL scan with an explicit binary allowlist, JSON and YAML parsing, `bash -n`,
  shellcheck, frontmatter, the plugin directory's file limits, and the hook
  tests.
- CI validates the marketplace and the plugin with a pinned Claude Code CLI,
  and Dependabot keeps the pinned actions current.
- CI runs the hook tests under macOS bash 3.2, and `scripts/check.sh`
  compiles the bundled workflow.

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
- The build orchestrator is a native plugin workflow, `/sutra:build-orchestrator`;
  copying it into a project is optional. It runs slices one at a time,
  commits only slices that pass independent validation, stops at the first
  slice that does not, refuses to start on invalid index rows, and frames plan
  text as data.
- `scaffold-execution-plan` starts only when a person invokes it, and its
  kickoff template allows a closed set of git commands (fetch, status,
  rev-parse, log) and plain
  placeholder values.
- `scrub-before-publish` starts with a deterministic secret scanner (gitleaks
  or trufflehog); `doc-sanitizer` is an advisory third pass that never repeats
  a secret and treats instructions in scanned text as data.
- `hooks-cookbook` gives a per-event table of what can block, builds JSON with
  jq or JSON::PP, matches `git -C` and `git -c` commit variants, and keeps its
  recipes in `reference/recipes.md`.
- `examples/settings.json` drops allow rules that ran arbitrary programs or
  wrote anywhere, and denies secret paths; the example hooks read the command
  and answer with structured decisions.
- CI runs with `contents: read`, a commit-pinned `actions/checkout`, and no
  persisted credentials.

### Removed

- `hooks/inject-profile.sh` and `hooks/ascii-guard.sh`, replaced by
  `hooks/sutra.sh`.

### Fixed

- The CI ASCII gate skipped any file containing a NUL byte as binary, so such
  a file could carry hidden Unicode past it.
- The build orchestrator ran slices concurrently in one working tree, so a
  slice could commit another slice's unreviewed edits, and it committed
  slices that failed validation.
- The strict gate counted commands that only mentioned a check tool (a commit
  message, `cat pytest.ini`) and missed script checks such as
  `bash tests/hooks.sh`; it now matches each simple command's command word.
- The build orchestrator's default-branch refusal compares names after
  Unicode normalization and case folding, so `Main` and `MASTER` are refused
  on case-insensitive file systems.
- The example commit hook runs git only in the project repository with
  `core.fsmonitor` disabled, and follows here-documents and `eval`.

### Security

- Padded instruction files could push the session-start scan past its hook
  timeout, which discarded the contract and the warnings. The scan now matches
  raw bytes and reads at most 20 subdirectory CLAUDE.md files; five 4 MiB
  files scan in about a second.
- A NUL byte no longer exempts an instruction file from the scan, and file
  paths in warnings are quoted and sanitized so a crafted name cannot add
  text Claude might follow.
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
