# Security model

This page is for deciding whether to install Sutra and how to run it safely:
what Sutra protects, where it takes input it does not control, what its hook
script does at each of those boundaries, and what it leaves to you. To report a
vulnerability, follow [SECURITY.md](../SECURITY.md).

Sutra is two plugins. `sutra`, the skills plugin, is Markdown only: skills,
subagents, and an icon, with nothing that runs on its own. `sutra-harness`
holds the only code Sutra runs on its own, one Bash script,
[`plugins/sutra-harness/hooks/sutra.sh`](../plugins/sutra-harness/hooks/sutra.sh),
which [`hooks.json`](../plugins/sutra-harness/hooks/hooks.json) runs at
SessionStart, UserPromptSubmit, PostToolUse, PreCompact, and Stop. One
workflow script, also in the harness, runs only when you invoke it, and the
rest is text Claude reads as instructions (profiles, rule cards, skills,
subagents). Sutra adds rules and warnings to a session; it enforces nothing.
Except where a section names the skills plugin, this page is about the
harness.

## Assets

- **Your machine and credentials.** Plugin hooks run with your full user
  permissions, outside the sandbox and the permission rules. So the script
  makes no network calls, builds no command from its input, and writes only
  to paths inside its own data directory, which it trusts (see
  [The plugin data directory](#the-plugin-data-directory)). It never seeks
  out a credential: it scans only the instruction files listed under
  [Repository files](#repository-files), at session start, and each file
  Claude has just read or written, and only the file's name, a line number,
  and a code point leave the script.
- **Repository integrity.** Your source, settings, instruction files, and CI.
  Sutra never edits your files, reports hidden characters in the files Claude
  writes, and lets a repository's `.sutra` raise its profile but never lower
  it. A repository's `.claude/settings.json` can still set Sutra's switches
  through its `env` key (see [Residual risk](#residual-risk)).
- **The model's context.** What Claude treats as instructions. Sutra adds
  fixed text from its own files and warnings that name a file, a line, and a
  code point. It never copies a scanned file's content into the context.

## Trust boundaries

### Hook payloads

Claude Code passes each event to the script as JSON on standard input. Parts
of it are shaped by others: your prompt, a tool's file path and command, and
Claude's last message.

- Values are extracted with perl's core JSON::PP (`fields`); a substring check
  on the raw payload only decides whether to parse it. A payload that is not a
  JSON object yields no values, so there is no session, file, or command to
  act on. Empty input, or input from a terminal, ends the script at once.
- The session id becomes a directory name only if it is 1 to 128 letters,
  digits, `_`, or `-` (`open_state`). Any other id, such as `../escape`, gets
  no state, and that session's cards and stop nudge stay silent.
- A file path is opened with perl's three-argument `open` (`scan_file`), so a
  name such as `run-me |` is read as a file, never run. A path that is not a
  regular file is skipped.
- Prompt and command text is only compared with fixed keywords, to choose a
  card or to count a check run. Nothing from the payload is executed or
  evaluated.
- Every JSON object the script prints is built with JSON::PP's ASCII encoder
  (`emit`, `block`), so a quoted file path cannot break out of the JSON, and
  non-ASCII characters arrive escaped.

### Repository files

A repository you open may have been written by someone else. Sutra reads three
kinds of file from it.

- **`.sutra`** (`resolve_profile`). At most its first 64 bytes are read, and
  a symbolic link is ignored. It applies only when you have set neither
  `SUTRA_PROFILE` nor the harness's `profile` setting, and the one value it can
  apply is `strict`. A `.sutra` asking for `lite` or `off` is then refused and
  reported to you at session start; any other content is ignored.
- **Instruction files** (`scan_instructions`). At session start Sutra scans
  `CLAUDE.md`, `CLAUDE.local.md`, `.claude/CLAUDE.md`, `AGENTS.md`,
  `GEMINI.md`, `.cursorrules`, `.github/copilot-instructions.md`, the `*.md`
  files directly inside `.claude/rules/`, and up to 20 `CLAUDE.md` files one
  or two directories below the project root, outside `.git`, `.claude`, and
  `node_modules`. A hit tells Claude to treat that file's instructions as
  untrusted, and tells you the file, line, and code point.
- **Files Claude reads or writes** (`check_hidden`, `post_edit`). After each
  Read, Write, Edit, MultiEdit, or NotebookEdit, Sutra scans the file and
  reports the first hidden character to Claude and to you.

The scan looks for bidirectional controls (U+061C, U+200E, U+200F,
U+202A-U+202E, U+2066-U+2069), zero-width and invisible characters (U+180E,
U+200B-U+200D, U+2060-U+2064, and U+FEFF anywhere but the start of a file),
and Unicode tag characters (U+E0000-U+E007F). It matches the raw UTF-8 bytes
of each listed character rather than decoding the file, so invalid bytes
nearby cannot hide one. It skips a file over 4 MiB, and a file Claude reads or
writes whose first 8 KiB holds a NUL byte; an instruction file is scanned
even then, since Claude Code loads it whatever it holds, and the NUL is
itself reported. It reports only the first hit in each file. A warning names
the file's path, which the repository chose, but never the file's content.
The path is quoted, every character outside `[A-Za-z0-9._/@+-]` becomes `?`,
and a long path is shortened, so a crafted name cannot add instructions.

### Sutra's own files

Installing Sutra means trusting its code and its text with your privileges.

- Of its own files, the script reads only `profiles/` and `cards/` under
  `CLAUDE_PLUGIN_ROOT`, and exits silently when that variable is unset or has
  no `profiles/`. Every command in `hooks.json` quotes `${CLAUDE_PLUGIN_ROOT}`
  and has a 5 to 10 second timeout.
- The four subagents (`architecture-reviewer`, `code-verifier`,
  `doc-sanitizer`, `request-tracer`) are limited to Read, Grep, and Glob.
- The build orchestrator runs only when you invoke
  `/sutra-harness:build-orchestrator`. Its agents edit files in your working
  tree, and its commit stage commits each validated slice to the checked-out
  branch. Its prompts forbid pushing, creating or switching branches,
  touching the default branch, and editing CI, hooks, settings, or
  `.mcp.json` unless a slice's brief requires it, and they hand the agents
  slice fields from `execution_plan/` as data, not instructions. Those rules
  are prompts, and its branch and clean-tree checks rely on what its agents
  report; neither restricts a tool. Your permission rules and sandbox decide
  what the agents can do, so run it only on a plan you wrote or reviewed. See
  [`plugins/sutra-harness/workflows/README.md`](../plugins/sutra-harness/workflows/README.md).
- The hooks in [`examples/hooks/`](../examples/hooks/) are not part of the
  plugin. They run only if you wire them into your own settings; review them
  as you would any hook.

### The plugin data directory

Claude Code gives the plugin a persistent data directory,
`CLAUDE_PLUGIN_DATA`. Sutra keeps per-session markers there and assumes only
your account can write to it.

- It is used only when the variable holds an absolute path (`data_base`).
  Otherwise the cards and the stop nudge stay silent; the hidden-character
  warnings still run.
- Writes go to paths under `sessions/<session id>/`: an empty `card.<id>` file
  for each card already shown; the counters `edits`, `checked`, and `nudged`,
  read back as digits only; and, under `strict`, `lastcheck`, at most 80
  characters: the printable ASCII among the first 80 bytes of the last check
  command.
- On each fresh startup, marker files older than 14 days and empty session
  directories are deleted (`prune_state`). After `/clear` or a compaction, the
  session's card markers are deleted so the cards can fire again.
- Anything that can write this directory can suppress a card, including the
  untrusted-content card, or change the command text the stop nudge quotes to
  Claude. Sutra follows symbolic links there, so a planted link can also
  redirect its small writes (digits, the check command, an empty marker file)
  to another file your account can write, and a linked session directory
  makes the cleanup after `/clear` or a compaction delete the `card.*` files
  in the directory it points to. It cannot make Sutra run anything.

## Residual risk

- **Sutra warns; it never blocks a tool call.** It has no PreToolUse hook, so
  every check runs after the tool call it inspects, or at session start. A
  warning about a file Claude just read arrives after the content is in
  context; it tells Claude to treat that content as data, and what happens
  next is up to Claude and you. The only decision Sutra returns is strict's
  verify-before-stop nudge, which asks Claude once per round of unchecked
  edits to run the project's checks.
- **Detection covers a fixed set of hidden characters.** Anything outside it,
  such as variation selectors (U+FE00-U+FE0F, U+E0100-U+E01EF), passes
  unreported, as does a file in another encoding: a UTF-16 file Claude reads
  or writes has NUL bytes and is skipped as binary (in an instruction file,
  the NUL itself is reported). Injected instructions written in plain,
  visible text are not detected at all.
- **Some content is not scanned when it reaches Claude:** Bash and Grep
  output, web pages, MCP tool results and descriptions, a repository's own
  skills, agents, and commands under `.claude/`, files an instruction file
  imports with `@path`, `CLAUDE.md` files deeper than two directories or past
  the first 20, and rules files in subdirectories of `.claude/rules/`. Of
  these, a file is scanned only if Claude opens it with Read. Save a copy and
  run the scan in section 3 of the agent-security skill.
- **It fails open.** When perl or its core JSON::PP and Encode modules are
  missing, a payload does not parse, or a hook runs past its timeout, Sutra
  skips what it cannot do rather than stopping you. Without perl, its
  warnings, cards, and stop nudge all stay silent, and only the contract and
  the compaction brief still print, as plain text. A missing warning is not
  evidence that a file is clean.
- **It is not a sandbox or a permission system, and does not replace them.**
  The contract and the cards are instructions: Claude can fail to follow them,
  and injected text can argue against them. Only your permission rules, the
  sandbox, and a container or VM limit what a session can do.
- **Its own hook runs outside both.** Like every plugin hook, `sutra.sh` runs
  with your full user permissions, outside the sandbox and the permission
  rules. Review it before you install and again on every update.
- **Its switches live in the environment.** `SUTRA_PROFILE`,
  `SUTRA_SECURITY`, and `SUTRA_GATE` are read from the environment the hook
  runs in. A repository's `.claude/settings.json` can set environment
  variables (its `env` key) and add hooks of its own, and a `claude -p` run
  applies them without asking (section 6 of the agent-security skill). Read it
  before you rely on Sutra in a repository you did not write.

## OWASP mapping

How the [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/)
risks that matter most for an agent kit map to Sutra's controls, and to the
sections of the [agent-security skill](../plugins/sutra/skills/agent-security/SKILL.md)
(`/sutra:agent-security`) that cover what Sutra leaves to you.

| OWASP risk | Sutra control | Left to you | Skill section |
| --- | --- | --- | --- |
| LLM01 Prompt Injection | The core contract's rule that content is data, not instructions; the untrusted-content card after the first WebFetch or WebSearch; hidden-Unicode warnings on files Claude writes or opens with Read, and on instruction files at session start | Injection in visible text and in content Sutra does not scan: remove a leg of the lethal trifecta rather than rely on detection | 1, 2, 3 |
| LLM03 Supply Chain | A skills plugin that ships no code; one hook script with no network calls, in a separate plugin; plain ASCII text files; all reviewable before install. The vetting procedure for plugins, MCP servers, and skills; `/sutra:security-hygiene` for dependencies | Reviewing Sutra itself, and pinning or re-reviewing each update | 4, 7 |
| LLM06 Excessive Agency | Read-only subagents limited to Read, Grep, and Glob; the core rule to confirm an irreversible or outward-facing action first; guidance on deny rules, the sandbox, and scoped tokens | Enforcement: Sutra blocks nothing, while permission rules, the sandbox, and containers do | 1, 5, 6 |

The incidents behind each row are in the skill's
[threat reference](../plugins/sutra/skills/agent-security/reference/threats.md).

## Hardening

1. **Review before you install.** Clone the repository and run
   `claude --plugin-dir ./plugins plugin details sutra` and
   `claude --plugin-dir ./plugins plugin details sutra-harness` to list the
   skills, agents, and hooks; the lists leave out the workflow,
   `plugins/sutra-harness/workflows/build-orchestrator.workflow.js`. Read
   `plugins/sutra-harness/hooks/hooks.json` and
   `plugins/sutra-harness/hooks/sutra.sh`, the only code that runs on its own,
   and read the workflow before you first run it. Confirm every text file is
   plain printable ASCII, so none can hide characters:
   `LC_ALL=C grep -rlI '[^[:print:][:space:]]' plugins` prints nothing.
2. **Pin, and re-review on update.** Sutra's marketplace is a third-party
   one, so Claude Code leaves auto-update off for it unless you turn it on
   (`/plugin`, **Marketplaces** tab). Keep it off, or pin a release when you
   add the marketplace: `/plugin marketplace add avmnu-sng/sutra#vX.Y.Z`. A
   tag can be moved, so note the commit it points to when you review
   (`git rev-parse 'vX.Y.Z^{commit}'` in your clone). Before each update,
   read the release's entry in [CHANGELOG.md](../CHANGELOG.md) and the diff
   of `plugins/` since that commit; repeat step 1 if anything under
   `plugins/sutra-harness/hooks/` or `plugins/sutra-harness/workflows/`
   changed. A pinned marketplace stays on its tag; to move to a newer
   release, remove it and add it again at the new tag, as `docs/install.md`
   shows under Updating.
3. **Start from the example settings, and know their limits.**
   [`examples/settings.json`](../examples/settings.json) denies `rm -rf`,
   force pushes, and reads of `.env` files, `secrets/`, private keys, and the
   SSH, AWS, and GitHub CLI credential directories; turns on the sandbox; and
   allows only `make test` and `make lint`. Bash rules match command text, not
   the program, so `rm -fr` is not matched: treat Bash deny rules as a
   backstop. Read deny rules also stop `cat`-style Bash commands but not
   `grep -r` or scripts; with the sandbox on, Claude Code merges them into
   the sandbox's read restrictions, which cover a sandboxed command and every
   process it starts. An exact allow rule such as
   `Bash(make test)` still runs whatever the Makefile says: keep it to
   repositories you trust, and never allow a prefix that runs arbitrary
   programs (section 5 of the agent-security skill).
4. **Sandbox untrusted work.** With the sandbox on (`/sandbox` or
   `sandbox.enabled`), Bash and its child processes can write only to the
   working, temp, and added directories and reach only the domains you allow.
   Keep `sandbox.allowUnsandboxedCommands` false, as the example does, and set
   `sandbox.failIfUnavailable` to true, or commands run unsandboxed when the
   sandbox cannot start. It does not stop reads of most of the machine and
   does not cover file tools, MCP servers, or hooks, Sutra's included; for
   those, use a dev container or VM.
5. **Keep the security floor on.** Leave `SUTRA_SECURITY` unset: any value
   other than `off`, `0`, `false`, or `no`, ignoring case and spaces, keeps it
   on, under every profile including `off`. `SUTRA_GATE=off` turns off only
   strict's verify-before-stop nudge, which is not a security control. Set
   both in your own shell, not in a repository's settings.

If something gets through, follow section 8 of the agent-security skill: stop
the session, rotate every credential it could reach, and preserve the evidence
before you remove anything.
