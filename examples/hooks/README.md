# Opt-in hooks

These hooks are **off by default** and are **not part of the sutra plugin**.
Nothing here runs until you wire it into your own settings or git hooks, so
the plugin never imposes a gate you did not ask for.

Treat every script as a starting template, not a finished tool. The checks
are deliberately coarse and language-agnostic; adapt them to your stack
before relying on them.

## The hooks

### `source-change-requires-test.sh`

Flags a commit that changes product source without changing a test. A path
counts as a test, or as non-source (docs, config, lockfiles, CI, assets), by
regular expression; everything else is source. Refactors, renames, and
pure-doc commits can trip it, so it starts in warn mode.

It runs two ways, told apart by its input:

- **git `pre-commit` hook -- the reliable form.** git runs it for every
  `git commit`, whoever starts it, and it checks the exact index being
  committed, `-a`, `--amend`, and pathspec commits included. It does not run
  under `--no-verify` or a changed `core.hooksPath`, or for the commits that
  cherry-pick, rebase, revert, `am`, or merge create on their own, so CI is
  the backstop.
- **Claude Code `PreToolUse` hook on `Bash`.** It reads `tool_input.command`
  from the payload and stands aside unless the command runs
  `git [global options] commit` in this repository: `git commit`,
  `git -C . commit`, `cd src && git commit`. It checks the index as it
  stands *before* the command runs, adds tracked changes for
  `git commit -a`, and counts the whole working tree when the same command
  also runs `git add`, because what that `git add` will stage cannot be
  known in advance. Quoted text counts as an argument, never as a command.
  It sees only commands Claude runs, and not a commit hidden in `bash -c`,
  a script, a git alias, a command substitution inside double quotes
  (`"$(git commit)"`), or a wrapper that takes arguments of its own, such as
  `timeout 60` or `env -i`.

| Knob | Default | Meaning |
| --- | --- | --- |
| `MODE` | `warn` | `warn` or `block` |
| `TEST_PATH_REGEX` | `spec/`, `test/`, `tests/`, `__tests__/` directories; `_test.`, `_spec.`, `.test.`, `.spec.` names | Paths that count as tests |
| `SOURCE_EXCLUDE_REGEX` | Docs, config, lockfiles, CI, assets | Paths that never trigger the rule |
| `RANGE` | Empty: the index | A revision range to check instead, such as `origin/main...HEAD` |

| Wiring | `warn` | `block` |
| --- | --- | --- |
| git `pre-commit` | Report on stderr, exit 0; the commit proceeds | Report on stderr, exit 1; git aborts the commit |
| `PreToolUse` | `systemMessage` for you and `additionalContext` for Claude; the command runs | `permissionDecision: "deny"`; Claude reads the report as the reason |

### `empty-test-detector.sh`

Warns when a file Claude just wrote looks like a test file that defines a
test but contains no assertion -- a test that passes unconditionally and
gives false confidence. It reads the written path from the `PostToolUse`
payload, so it works only as a Claude Code hook: a git hook gets no payload.

Coarse by design: it matches the path, relative to the project, against
`TEST_FILE_REGEX`, then greps the whole file for a test definition
(`TEST_DEF_REGEX`) and an assertion token (`ASSERT_REGEX`: `assert`,
`expect`, `require`, `should`, and similar). A file where one test asserts
and another does not stays quiet; custom assertion helpers cause false
positives. Tune the three regexes to your framework. It never blocks: it
prints a `systemMessage` for you and `additionalContext` for Claude, and
always exits 0.

## What a hook can do, per event

A command hook answers with its exit code, or with exit 0 and one JSON
object on stdout. Exit 2 blocks only where the event can block. Any other
non-zero exit, 1 included, is a non-blocking error.

| Event | Can block? | Exit 2 |
| --- | --- | --- |
| `PreToolUse` | Yes | Blocks the tool call and shows stderr to Claude. Exit 0 with `permissionDecision: "deny"` blocks with a reason |
| `PostToolUse` | No | Shows stderr to Claude. The tool already ran, so the write is not undone |
| `SessionStart` | No | Shows stderr to you only |
| `UserPromptSubmit` | Yes | Blocks the prompt; Claude never sees it |
| `Stop` | Yes | Keeps Claude working instead of stopping |

A `PreToolUse` hook that prints nothing approves nothing: the command still
goes through your permission rules and prompts.

## Enabling a hook

Pick **one** wiring per hook. Wired both ways, it runs twice.

### As a git pre-commit hook

`source-change-requires-test.sh` only. Copy or symlink it into the
repository's hooks directory (`git rev-parse --git-path hooks` prints it)
and mark it executable:

```sh
cp examples/hooks/source-change-requires-test.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# or a symlink, which follows edits to the template
ln -s ../../examples/hooks/source-change-requires-test.sh .git/hooks/pre-commit
```

git runs it with no arguments and no input, against the index being
committed. To block, set `MODE=block` in the environment of the commit, or
call the script from your own `pre-commit` wrapper:

```sh
#!/bin/sh
MODE=block exec "$(git rev-parse --show-toplevel)/examples/hooks/source-change-requires-test.sh"
```

To run more than one script on commit, chain them from a single
`pre-commit` wrapper rather than overwriting the file.

### As a Claude Code hook

Add the entries to **your own** `.claude/settings.json` (this project) or
`~/.claude/settings.json` (every project):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/examples/hooks/source-change-requires-test.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/examples/hooks/empty-test-detector.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

- `$CLAUDE_PROJECT_DIR` is the project root. Claude Code runs the command
  through a shell (`sh -c` on macOS and Linux), so keep the double quotes:
  they hold a path with spaces together.
- `timeout` is in seconds. Without it, a command hook may run for 600.
- Point the path at wherever you keep your copy, such as `.claude/hooks/`.
- To set a knob, prefix it:
  `"MODE=block \"$CLAUDE_PROJECT_DIR\"/examples/hooks/source-change-requires-test.sh"`.

## Contracts every template honors

### Fail open

If the tooling a hook needs is missing (no `git`, neither `jq` nor perl's
`JSON::PP`, an unreadable path, an invalid regex), the hook **exits 0** and
stays silent. A safety net that breaks the build when it cannot run is worse
than no net. Never let a hook failure become the user's failure.

### Input is data

The payload is parsed with `jq`, or with perl's core `JSON::PP` when `jq` is
missing, and every JSON answer is built the same way, never by pasting
strings into JSON. The command a `PreToolUse` hook inspects is text to read,
never to run: `source-change-requires-test.sh` follows `cd` and `git -C` only
to decide whether the commit is in this repository, and runs git only here,
because another repository's configuration could run a program before you
approve the command.

### Warn before block

Start every rule in warn mode. Switch to block only for a rule whose
precision you trust, on a project where a hard stop is welcome.

## Methodology

These detectors answer "did a test change?" -- not "is the test any
good?" For what makes an assertion meaningful, what to cover, and how to
avoid the empty-test trap in the first place, see the test-authoring
skill. The hooks are a backstop; the skill is the practice.
