# Opt-in hooks

These hooks are **off by default** and are **not part of the sutra plugin**.

Enforcement hooks fire on every write or commit. A hook that blocks
your work -- or even just prints a warning at the wrong moment -- is a
surprise, and surprises erode trust in your tools. So sutra core never
installs them and never blocks your work. What lives here are *examples*:
copy one into your own project only when you have decided you want it.

Treat every file in this directory as a starting template, not a
finished tool. The detectors are deliberately coarse and
language-agnostic; you adapt them to your stack before relying on them.

## The hooks

### `empty-test-detector`

Warns when a test appears to have no assertion -- a test body that runs
code but never checks a result. These pass unconditionally and give
false confidence.

Coarse by design: it greps for common assertion tokens (`assert`,
`expect`, `should`, `require.*Equal`, and similar) and warns when a
changed test file has none. It does not parse the language. Expect
false positives on custom assertion helpers and false negatives on
commented-out checks. Tune the token list to your test framework.

### `source-change-requires-test`

Flags a commit (or a command about to run) that changes source files
without a paired change to any test file. The intent is a nudge: if you
touched behavior, touch a test.

Also coarse: it classifies paths as "source" vs "test" by path
convention (a `test`/`spec`/`__tests__` segment, or a `_test`/`.spec`
suffix). Refactors, renames, and pure-doc commits will trip it. Adjust
the path rules, or run it in warn mode so it never stands in your way.

## Enabling a hook

Pick **one** wiring per hook. Do not wire the same hook both ways --
it will run twice.

### As a git pre-commit hook

Copy or symlink the script into your repo's hooks directory and mark it
executable. Symlinking keeps it in sync if you edit the template.

```sh
# copy
cp examples/hooks/empty-test-detector.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# or symlink (tracks edits to the template)
ln -s ../../examples/hooks/empty-test-detector.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

To run more than one script on commit, chain them from a single
`pre-commit` wrapper rather than overwriting the file.

### As a Claude Code hook

Add an entry to **your own** `.claude/settings.json`. Choose the event
that matches what the hook inspects:

- `empty-test-detector` -> `PostToolUse` on `Write|Edit` (inspect a
  file the moment it is written).
- `source-change-requires-test` -> `PreToolUse` on `Bash` (inspect a
  commit before the command runs).

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "examples/hooks/empty-test-detector.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "examples/hooks/source-change-requires-test.sh"
          }
        ]
      }
    ]
  }
}
```

Use an absolute path or one your settings file can resolve. Keep these
entries in your personal or project settings -- they are yours to
enable, not something sutra turns on for you.

## Contracts every template honors

### Graceful degradation

If the tooling a hook needs is missing (no `git`, no `grep`, an
unreadable path), the hook **exits 0** and stays silent. A safety net
that breaks the build when it cannot run is worse than no net. Never
let a hook failure become the user's failure.

### Warn vs block

Each template supports two modes:

- **Warn** (default): print the finding to stderr and exit 0. The write
  or commit proceeds. Start here.
- **Block**: exit non-zero to reject the write or commit. Opt into this
  only for a rule you are certain about, on a project where a hard stop
  is welcome.

Flip the mode with the variable at the top of each script. When in
doubt, warn.

## Methodology

These detectors answer "did a test change?" -- not "is the test any
good?" For what makes an assertion meaningful, what to cover, and how to
avoid the empty-test trap in the first place, see the test-authoring
skill. The hooks are a backstop; the skill is the practice.
