# Contributing to Sutra

Sutra is a small, opinionated kit. Contributions that keep it sharp, generic,
and honest are welcome.

## Principles

- **Generic and reusable.** Everything here ships publicly. No employer,
  product, internal service, person, host, or private project may appear in any
  file -- not in examples, not in commit messages. Use neutral, invented
  examples.
- **ASCII only.** No non-ASCII bytes in any file. Write `--` for an em dash,
  `->` for an arrow, straight quotes. Verify with `bash scripts/check.sh`,
  which scans every tracked file's bytes.
- **Never block a tool call; degrade to silence.** Sutra never blocks a tool
  call. Under `strict` it may ask the agent, at most once per batch of edits,
  to run the project's checks before it stops. Every hook degrades to silence
  when its tooling is missing.
- **Profile layers compose.** `lite` is `core.md`, `standard` adds
  `standard.md`, and `strict` adds `strict.md` on top of both. A rule in
  `core.md` holds for every profile except `off`, so put each rule in the
  lowest layer where it is always true and never repeat it in a higher one.
- **The skills plugin runs nothing.** `plugins/sutra` goes to Anthropic's
  plugin directory, which refuses hooks, workflow scripts, and files other
  than Markdown, text, JSON, YAML, and a few image types from an organization
  that is not Verified. Anything that runs belongs in `plugins/sutra-harness`.

## Adding a component

- **Skill:** create `plugins/sutra/skills/<name>/SKILL.md` with a
  `description:` frontmatter line (this string drives auto-invocation). It
  becomes `/sutra:<name>`. Example scripts go in the Markdown, in fenced
  blocks, never as files of their own.
- **Subagent:** add `plugins/sutra/agents/<name>.md` with `name`,
  `description`, and a minimal `tools` list in frontmatter. Read-only agents
  must be told not to modify files.
- **Profile rule:** a rule that is always true goes in one layer,
  `plugins/sutra-harness/profiles/{core,standard,strict}.md`. Keep it tight --
  the contract is injected at every session start and compaction.
- **Card:** a rule that matters at one moment (a commit, a kind of edit, a
  tool result) becomes a card instead: `plugins/sutra-harness/cards/<id>.md`
  (plus `<id>.strict.md` for strict-only lines), a `card <id>` call in the
  matching handler of `plugins/sutra-harness/hooks/sutra.sh`, and a case in
  `tests/hooks.sh`.
- **Doc:** long-form reference goes under `docs/`.

## Validate before opening a PR

```
bash scripts/check.sh
claude plugin validate --strict .
claude plugin validate --strict ./plugins/sutra-harness
claude plugin validate --strict --profile directory ./plugins/sutra
```

To try your change, load both plugins from your clone with
`claude --plugin-dir ./plugins`.

`scripts/check.sh` runs the same checks as CI's `checks` job and prints one
line per check:

- **ascii:** no NUL or non-ASCII byte, and no control byte other than tab,
  LF, and CR before LF, in any file except the allowlisted binaries,
  `docs/demo.gif` and each plugin's `assets/icon.png`.
- **json**, **yaml:** every JSON file parses with `jq`, and every YAML file
  with Python's PyYAML.
- **bash-syntax**, **shellcheck:** `bash -n` and `shellcheck -S warning` on
  every `*.sh` file.
- **frontmatter:** inside its `---` block, every skill declares a
  `description`, and every agent a `name` and a `description`.
- **manifests:** each `marketplace.json` entry names a `./plugins/<name>`
  folder whose `plugin.json` has that name, each dependency without a
  marketplace names a plugin in `marketplace.json`, both plugins carry the
  same version, and `CHANGELOG.md` has a section for it.
- **plugin-limits:** the plugin directory's folder limits for each plugin:
  at most 512 files, every file other than an image or font under 256 KiB, no
  symlinks, no `..` or absolute path in a `plugin.json` path, and no `..`,
  absolute path, command substitution, or variable other than a braced
  `${CLAUDE_PLUGIN_ROOT}` in a `hooks.json` command.
- **directory-policy:** `plugins/sutra` holds only Markdown, text, JSON,
  YAML, and complete PNG, JPEG, GIF, WebP, or ICO images, each file under 5
  MiB; every text file is UTF-8 with no NUL byte and does not start with
  `#!`; there is no hook, workflow, `bin/`, server configuration, or package
  manager file, no Markdown frontmatter that declares `hooks` or
  `mcpServers`, and no skill or command that runs a shell command when it
  loads (an inline ``!`...` `` or a ```` ```! ```` block); no name holds a
  colon, ends in a dot or space, is a reserved device name, or differs from
  another only by case; its `plugin.json` declares no key that can run code;
  its `README.md` (at least 40 words outside code blocks) and `LICENSE`
  exist; and no `.gitattributes` uses `export-ignore`, `export-subst`, or
  `filter`.
- **workflows:** each `plugins/sutra-harness/workflows/*.js` compiles, led by
  a plain-literal `export const meta`.
- **hook-tests:** `tests/hooks.sh`, which runs
  `plugins/sutra-harness/hooks/sutra.sh` through its behavior cases in a clean
  environment, and runs them again under `/bin/bash` when that is a different
  bash from the one on your `PATH`, so macOS bash 3.2 is always covered.

It checks tracked files plus untracked files git does not ignore, so a new
file is checked before you stage it. It needs `git`, `jq`, and `perl`.
Without `shellcheck`, `python3` with PyYAML, or `node`, it prints a `skip`
line for that check; CI sets `CI=true`, which turns a skip into a failure.
While working on the hook, `bash tests/hooks.sh` runs the behavior cases
alone.

`--strict` fails on warnings, and `--profile directory` adds the subset of the
plugin directory's checks the CLI can run (README, license, icon). The
directory's portal runs more checks, plus a security scan, after you push.

CI (`.github/workflows/ci.yml`) runs `scripts/check.sh`, the hook tests under
macOS bash 3.2, and the `claude plugin validate` commands, with Claude Code
pinned to one version, on every push to `main` and every pull request.

## Commits and branches

- One logical change per commit; one feature per branch.
- Subject: imperative, a conventional prefix (`feat:`/`fix:`/`docs:`/...),
  under ~72 characters, naming the symbols touched.

The `commit-craft` and `style-audit` skills describe the full conventions this
project holds itself to.
