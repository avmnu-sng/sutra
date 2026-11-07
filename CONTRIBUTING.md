# Contributing to Sutra

Sutra is a small, opinionated kit. Contributions that keep it sharp, generic,
and honest are welcome.

## Principles

- **Generic and reusable.** Everything here ships publicly. No employer,
  product, internal service, person, host, or private project may appear in any
  file -- not in examples, not in commit messages. Use neutral, invented
  examples.
- **ASCII only.** No non-ASCII bytes in any file. Write `--` for an em dash,
  `->` for an arrow, straight quotes. Verify with `file <path>` reporting
  `ASCII text`.
- **Never block a tool call; degrade to silence.** Sutra never blocks a tool
  call. Under `strict` it may ask the agent, at most once per batch of edits,
  to run the project's checks before it stops. Every hook degrades to silence
  when its tooling is missing.
- **Profile layers compose.** `lite` is `core.md`, `standard` adds
  `standard.md`, and `strict` adds `strict.md` on top of both. A rule in
  `core.md` holds for every profile except `off`, so put each rule in the
  lowest layer where it is always true and never repeat it in a higher one.

## Adding a component

- **Skill:** create `plugins/sutra/skills/<name>/SKILL.md` with a
  `description:` frontmatter line (this string drives auto-invocation). It
  becomes `/sutra:<name>`.
- **Subagent:** add `plugins/sutra/agents/<name>.md` with `name`,
  `description`, and a minimal `tools` list in frontmatter. Read-only agents
  must be told not to modify files.
- **Profile rule:** a rule that is always true goes in one layer,
  `plugins/sutra/profiles/{core,standard,strict}.md`. Keep it tight -- the
  contract is injected at every session start and compaction.
- **Card:** a rule that matters at one moment (a commit, a kind of edit, a
  tool result) becomes a card instead: `plugins/sutra/cards/<id>.md` (plus
  `<id>.strict.md` for strict-only lines), a `card <id>` call in the matching
  handler of `plugins/sutra/hooks/sutra.sh`, and a case in `tests/hooks.sh`.
- **Doc:** long-form reference goes under `docs/`.

## Validate before opening a PR

```
bash tests/hooks.sh
BASH_UNDER_TEST=/bin/bash bash tests/hooks.sh
claude plugin validate --strict .
claude plugin validate --strict --profile directory ./plugins/sutra
find . -type f ! -path './.git/*' -exec file {} \; | grep -v 'ASCII text' || echo "all ASCII"
```

`tests/hooks.sh` runs `plugins/sutra/hooks/sutra.sh` through its behavior
cases in a clean environment and needs `jq`; the second line runs it under
macOS bash 3.2. `--strict` fails on warnings, and `--profile directory` adds
the subset of the plugin directory's checks the CLI can run (README, license,
icon). The directory's portal runs more checks, plus a security scan, after
you push.

CI (`.github/workflows/ci.yml`) runs the ASCII, JSON/YAML, shell-syntax, and
frontmatter checks on every push and pull request. Run `tests/hooks.sh` and
`claude plugin validate` locally before opening a PR.

## Commits and branches

- One logical change per commit; one feature per branch.
- Subject: imperative, a conventional prefix (`feat:`/`fix:`/`docs:`/...),
  under ~72 characters, naming the symbols touched.

The `commit-craft` and `style-audit` skills describe the full conventions this
project holds itself to.
