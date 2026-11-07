# Examples

Copy-and-adapt templates for wiring `sutra` into a real project.

**Everything in this directory is optional.** The sutra plugin works on its
own once installed -- none of these files are required to use it. They exist
to solve the next set of problems: making the profile travel with a repo,
layering project-specific rules on top of it, and locking down what an agent
may run. Treat each file as a starting point: copy it out, delete what you do
not need, and replace every placeholder with real values for your project.

## What is here

| File | Purpose | You need it when... |
| --- | --- | --- |
| `CLAUDE.md.example` | In-repo import of the sutra profile | Teammates or CI check out the repo without the plugin installed |
| `AGENTS.md.example` | Project-specific guardrails that compose with the profile | You want repo-local commands and invariants an agent cannot guess |
| `settings.json` | Exact-command allowlist, secret-file denies, and the sandbox turned on | You want Claude Code to ask before anything unexpected and stay out of secrets |
| `setup.yaml` | Machine-readable bootstrap manifest: setup steps, commands, ports, doc pointers | An agent should learn how to build, test, and navigate the repo without guessing |
| `hooks/` | Opt-in, off-by-default hooks: a commit gate and an empty-test warning | You want automated checks, not just guidance |

## `CLAUDE.md.example`

An optional way to adopt the sutra profile *in the repository itself*, so that
teammates who have **not** installed the plugin still pick up its guidance when
they open the project in Claude Code.

You usually do not need this. If a teammate has the sutra plugin installed, the
profile is already active for them globally -- no `CLAUDE.md` change required.
Reach for the in-repo approach only when you want the profile to travel *with*
the repository: for contributors on a clean checkout, or for CI and agent runs
that start from bare source.

The template documents two mutually exclusive ways to wire it up:

- **Option A -- vendored `@import`.** Vendor the sutra repo into your project
  (submodule, subtree, or a plain clone under `vendor/`) and `@import` its
  profile layers in order, stopping at the profile you want: `core.md`
  (`lite`), then `standard.md` (`standard`), then `strict.md` (`strict`).
  `@import` resolves **local paths only** -- it cannot fetch a URL or a remote
  git ref, so the vendored copy must be checked in and present on disk. This
  works for everyone, plugin or not.
- **Option B -- a `.sutra` marker.** If everyone on the team already has the
  plugin and you want `strict`, drop a one-line `.sutra` containing `strict`
  at the repo root. It raises the profile to `strict` for teammates who have
  not chosen one themselves (`SUTRA_PROFILE` or the plugin's `profile`
  setting); a `.sutra` naming `lite` or `off` is refused, and `standard` is
  already the default. Lightest touch, but it does nothing for a checkout
  without the plugin.

Pick one, not both, so there is a single source of truth for which profile
applies. Below the wiring, the template leaves a **Project specifics** section
for the build/test/lint commands, conventions, and layout an agent needs.

## `AGENTS.md.example`

Project-specific guardrails that **compose with** sutra rather than restating
it. The profile -- general working style, review posture, and safety defaults
-- comes from the plugin (or a local `@import` if you vendor a copy). This file
stays focused on what is unique to one repository:

- The exact task-runner entrypoints (`check`, `test`, `lint`, `build`) and why
  to prefer the runner over raw commands.
- Non-negotiable invariants a newcomer could not guess -- never weaken a test
  to make it pass, one feature per branch/commit/PR, keep files ASCII, do not
  commit planning or agent-only scratch files.
- Edit discipline for existing code -- match surrounding style, keep diffs
  minimal, no drive-by refactors.
- A "where things live" map so an agent can orient without guessing.

Keep generic guidance out of it; that belongs in the profile. The highest-value
lines are the repo-specific invariants -- a required column order, a cache byte
layout, a load-order dependency, an env var that must be unset in a subprocess.

## `settings.json`

A conservative starting point for a repository's `.claude/settings.json`. Copy
it there and edit it for your project. It does four things:

- **Allows two exact commands**, `make test` and `make lint`. Replace them with
  your project's own check commands (`npm test`, `task check`,
  `go test ./...`). An exact rule matches only that command line: `make test`
  runs without a prompt, while `make test V=1` or `make deploy` still asks.
  The command still runs whatever your build file defines for that target, so
  allowing it means trusting that file. Keep allow rules exact: `Bash(rg *)`
  would also approve `rg --pre <program>`, which runs any program, and
  `Bash(git diff *)` would approve `git diff --output=<path>`, which writes a
  file anywhere.
- **Allows nothing else.** Claude Code already reads files in the project and
  runs a built-in set of read-only commands (`ls`, `cat`, `grep`, `find`,
  read-only forms of `git`) without a prompt, so allow rules for them add
  nothing. Everything else asks.
- **Denies** reads of secrets: `.env` and `.env.*` at any depth in the project
  (`.env.example` stays readable), any `secrets/` directory, `*.pem`, `id_rsa*`
  and `id_ed25519*` files in the project, and `~/.ssh`, `~/.aws`, and
  `~/.config/gh`. A `Read` deny also blocks Claude's Edit and Write tools on
  the same path. Add your own credential stores (`~/.netrc`, `~/.npmrc`,
  `~/.kube`, `~/.docker/config.json`). `*.pem` also matches public certificate
  bundles, such as the `certifi/cacert.pem` in a virtualenv inside the project.
  A `!` rule listed after it, such as `Read(!cacert.pem)`, carves one out for
  Claude; for a sandboxed command that needs one, narrow `*.pem` to the
  directories that hold your keys. The `rm -rf` and force-push denies stay as a
  coarse backstop: a rule matches command text, so `rm -fr`,
  `git push origin --force`, and `git push origin +main` all get past it.
- **Turns on the sandbox** for Bash commands: OS-level isolation (macOS, Linux,
  WSL2) that confines writes to the working directory and the temp directory,
  asks before a command reaches a new network host, and here also blocks reads
  of `~/.ssh`, `~/.aws`, and `~/.config/gh` by any sandboxed command. Claude
  Code merges the `Read` deny rules above into the sandbox as well, so a
  sandboxed command, `make test` included, cannot read those files either; if
  your tests load `.env`, give them their settings another way or drop that
  deny. `"autoAllowBashIfSandboxed": false`
  keeps the permission prompts, which the sandbox otherwise skips for sandboxed
  commands. `"allowUnsandboxedCommands": false` stops Claude from retrying a
  blocked command outside the sandbox; with the retry on, an allow rule such as
  `Bash(make test)` would also approve running that command unsandboxed without
  a prompt. A tool that cannot run sandboxed, such as a container CLI, goes in
  `sandbox.excludedCommands`, and then runs with your full access.

The permission rules are not a substitute for the sandbox. They decide what
Claude may start without asking, by matching the command text and the paths
Claude's own file tools touch; they do not see what a program does once it
runs. `Read` denies cover Claude's file tools and the file commands Claude Code
recognizes in Bash (`cat`, `head`, `tail`, `sed`), but not `grep -r` over a
directory or a script that opens files itself. The sandbox enforces its limits
on every Bash command and the processes it starts, and on nothing else:
Claude's file tools, hooks, and MCP servers run outside it. When the sandbox
cannot start (native Windows, a missing dependency on Linux), Claude Code would
run commands without it, so this file sets `sandbox.failIfUnavailable` to
`true` and Claude Code refuses to start instead. Drop that key only if a
teammate works where the sandbox cannot run and unsandboxed commands are
acceptable there.

Allow rules in a committed `.claude/settings.json` apply only after each
teammate trusts the folder; deny rules apply right away.

**It is strict JSON.** No comments, no trailing commas -- a `//` or `/* */` line
will break parsing. Keep your notes in this README or a separate doc, not in the
settings file.

## `setup.yaml`

A machine-readable manifest an agent reads first to learn how to set up, run,
test, and navigate the repository: prerequisites with pinned versions, ordered
setup steps, canonical commands, ports, dependent repos, and pointers to the
authoritative docs. Copy it to your repo root and replace every
`<placeholder>`. The commands it lists are documentation, not approval: an
agent still runs each one through its permission prompts, and only the
built-in read-only commands and the exact commands you allow in
`.claude/settings.json` skip them.

## `hooks/`

**Opt-in and off by default.** Two templates that run automatically once
wired, which makes them stronger than the advisory guidance a profile provides:

- `source-change-requires-test.sh` warns about, or blocks, a commit that
  changes source without a test. It runs as a git `pre-commit` hook (the
  reliable form) or as a Claude Code `PreToolUse` hook that acts only on
  `git commit`.
- `empty-test-detector.sh` warns when Claude writes a test with no assertion.
  It is a `PostToolUse` hook, which runs after the write and cannot undo it.

Nothing here is wired in until you add it to your own settings, so the plugin
never imposes a hook you did not ask for. See [`hooks/README.md`](hooks/README.md)
for what each hook event can block and how to wire each script.

---

None of these files are needed to run sutra. They are here to copy, trim, and
adapt -- start from the one that solves a problem you actually have, and leave
the rest.
