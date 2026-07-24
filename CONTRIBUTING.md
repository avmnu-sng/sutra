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
- **Degrade to silence, never to obstruction.** Nothing in Sutra may block or
  break a user's own work. Hooks warn at most; they never fail a write.
- **Layered profiles stay supersets.** A rule in `standard` must also hold in
  `strict`. Adding a rule to a lower profile adds it to every higher one.

## Adding a component

- **Skill:** create `plugins/sutra/skills/<name>/SKILL.md` with a
  `description:` frontmatter line (this string drives auto-invocation). It
  becomes `/sutra:<name>`.
- **Subagent:** add `plugins/sutra/agents/<name>.md` with `name`,
  `description`, and a minimal `tools` list in frontmatter. Read-only agents
  must be told not to modify files.
- **Profile rule:** edit `plugins/sutra/profiles/<level>.md`. Keep it tight --
  profiles are injected every session.
- **Doc:** long-form reference goes under `docs/`.

## Validate before opening a PR

```
claude plugin validate .
claude plugin validate ./plugins/sutra
find . -type f ! -path './.git/*' -exec file {} \; | grep -v 'ASCII text' || echo "all ASCII"
```

CI (`.github/workflows/ci.yml`) runs the ASCII, JSON/YAML, shell-syntax, and
frontmatter checks on every push and pull request. Run `claude plugin validate`
locally (a schema check) before opening a PR.

## Commits and branches

- One logical change per commit; one feature per branch.
- Subject: imperative, a conventional prefix (`feat:`/`fix:`/`docs:`/...),
  under ~72 characters, naming the symbols touched.

The `commit-craft` and `style-audit` skills describe the full conventions this
project holds itself to.
