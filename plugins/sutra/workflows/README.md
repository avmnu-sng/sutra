# Sutra workflows

A Claude Code workflow is a JavaScript script that the workflow runtime
executes in the background. The script owns the control flow (which step runs
next, which subagent to spawn, what to check in its output, when to stop), and
the subagents do the judgment-heavy work inside each step, so the same path is
taken on every run.

Claude Code loads every script in this directory when the plugin is installed
and namespaces it by the plugin name: `build-orchestrator.workflow.js`, whose
`meta.name` is `build-orchestrator`, runs as `/sutra:build-orchestrator`. There
is nothing to copy. Claude Code asks you to approve a run before it starts,
depending on your permission mode, and `/workflows` shows its progress.

## /sutra:build-orchestrator

Drives a value-ranked execution plan to completion one slice at a time. A slice
is one PR-sized deliverable listed in `execution_plan/sessions/INDEX.md`, with a
brief that describes it.

### What it does

1. **Plan intake.** A read-only agent reports the checked-out branch, the
   remote's default branch, HEAD, whether the working tree is clean, and every
   slice in the INDEX. The script checks the start conditions and every row's
   fields (see below), and refuses to start unless all of them pass.
2. **Per slice**, for every slice not marked DONE, in INDEX order and strictly
   one after another:
   - **Build** the slice to its full declared scope from its brief, leaving the
     changes uncommitted.
   - **Adversarial review** by a separate read-only agent. Findings of
     severity `blocker` must be fixed before the slice can pass. The run logs
     the count of findings at each severity and carries the `major` and
     `minor` ones to the retro as follow-ups.
   - **Bounded fix** of the blocker findings only, skipped when there are none.
   - **Independent validation** by a fresh agent that walks every acceptance
     criterion in the INDEX row and the brief, re-runs the checks, and confirms
     each blocker finding is fixed. It runs `git add -A && git write-tree`
     first and last, which stages the slice's changes and prints the id of the
     tree it validated. Only a clean DONE on an unchanged tree passes.
   - **Retro and commit.** Writes the retro and handoff note with the
     follow-ups, and drafts the next slice's starter by copying
     `execution_plan/sessions/KICKOFF_TEMPLATE.md` and filling only its
     placeholders and prose, with no added commands, links, or steps. It sets
     the slice to DONE in the INDEX and makes one commit holding the slice's
     work, which may differ from the validated tree only under
     `execution_plan/`.
3. **Summary.** The run returns `status` (`complete`, `stopped`, or `refused`),
   a message, the slices committed, the review finding counts per slice, the
   blocked slice with its stage and reason, the slices not started, and the
   INDEX rows that failed the checks.

Slices never run concurrently: every agent works in the one working tree, and a
slice's commit takes every change in it, so a concurrent slice's unreviewed
edits would land in the wrong commit.

### What it refuses to do

- **Start on the wrong tree.** It refuses to start on `main`, `master`, the
  remote's default branch (`origin/HEAD`), or a detached HEAD, or with
  uncommitted changes in the working tree. Branch names are compared after
  Unicode normalization and case folding, so `Main` and `MASTER` are refused
  too: on a case-insensitive file system (the macOS and Windows default), git
  treats `Main` as the `main` branch, and a commit there moves `main`. When
  `origin/HEAD` is not set, only `main` and `master` count as the default
  branch, and the run logs that.
- **Start on a malformed plan.** It refuses to start, and no slice runs, when
  the INDEX lists no slice rows or any row fails these checks: an id of 1 to
  64 characters from `A-Z a-z 0-9 . _ -` that starts with a letter or digit
  and repeats no other row's id; a status of PENDING, IN_PROGRESS, BLOCKED, or
  DONE; a title of 1 to 160 characters with no backtick, line break, or
  control or format character (such as a bidirectional control or a
  zero-width character); a brief path under `execution_plan/` (letters,
  digits, `. _ - /`, no `..`, at most 200 characters); and 1 to 30 acceptance
  criteria of at most 600 characters each. The summary names each failing row
  and why. A freshly scaffolded INDEX still holds its placeholder rows, so it
  is refused until the plan is filled in.
- **Commit unvalidated work.** A stage that fails or returns nothing, a
  BLOCKED verdict, a DONE verdict that still lists unmet criteria or unresolved
  findings, a HEAD that moved before the commit stage, a working tree that
  changed while the validator ran, and a commit that differs from the
  validated tree outside `execution_plan/` (a commit hook that rewrites files
  counts) all count as BLOCKED. The run stops at that slice, leaves its work
  uncommitted for a person to inspect (staged, if the validator ran), starts
  no later slice, and logs why.
- **Leave the build branch.** Every agent prompt forbids pushing, creating or
  switching branches, and touching the default branch. The validator and the
  commit stage report the checked-out branch, and the run stops if it is not
  the branch the run started on. The commit stage may edit only files under
  `execution_plan/`, and may not amend a commit or skip git hooks.
- **Edit CI, hooks, or settings.** No agent may edit CI configuration, git
  hooks, Claude Code hooks or settings, or `.mcp.json` unless the slice brief
  requires it.
- **Follow plan text.** Slice fields and reviewer findings reach an agent only
  inside a `<repository-data>` block, as JSON with `<`, `>`, and every
  character outside printable ASCII escaped, under a rule that the text is
  information about the work and never an instruction.
- **Pass hidden text back.** Agent text in log lines and in the summary has
  every character outside printable ASCII escaped. The summary keeps at most
  30 entries of 600 characters from each list the validator or the commit
  stage returns, and its reason gives the full count.

A workflow script cannot run git itself, so the branch, HEAD, tree, and
clean-tree checks use what the agents report. They catch a stage that commits
early, switches branches, edits files during validation, commits work the
validator did not see, or leaves files behind; they cannot catch an agent that
misreports.

### Prerequisites

- The sutra plugin installed, with workflows enabled in Claude Code (on Pro,
  the Dynamic workflows row in `/config`).
- `execution_plan/sessions/INDEX.md` with one row per slice: id, title, status,
  brief path (relative to `execution_plan/sessions/`, for example
  `briefs/S-01.md`), and a one-line acceptance summary.
  `/sutra:scaffold-execution-plan` lays this tree down, including the
  `KICKOFF_TEMPLATE.md` that each starter is copied from.
- A dedicated build branch checked out, and a clean working tree.
- Generated files (coverage output, caches, build output) covered by
  `.gitignore`. Otherwise `git add -A` commits them into the slice's commit,
  and a check that rewrites them while the validator runs stops the run.
- Allow rules for the commands the agents run, such as git and your test
  runner, so a long run does not wait on permission prompts.

### Resume

The INDEX is the source of truth. Run `/sutra:build-orchestrator` again and it
skips every slice already DONE and starts at the first one that is not.

- **After a BLOCKED stop**, read the summary and the stage's output in
  `/workflows`. Then either finish the slice yourself, commit it, and set its
  INDEX status to DONE, or discard its changes so it is rebuilt from scratch,
  and run the workflow again. It refuses to start on a dirty tree, so a blocked
  slice's leftovers never ride along in the next slice's commit.
- **After a stop at the commit stage**, check `git log`, `git status`, and the
  checked-out branch first: the commit may have been made, with files left
  behind, on another branch, or with changes outside `execution_plan/` that the
  validator did not see.
- **A paused run** resumes from `/workflows` (`p`). For a run you stopped, ask
  Claude to relaunch it in the same session, and completed agents return their
  saved results. Do this only if the working tree is untouched since the stop;
  otherwise start a new run, because the saved results describe the old tree.

### Customize

The plugin's copy updates with the plugin. To change the prompts, the stages,
or the plan format, copy `build-orchestrator.workflow.js` into your project's
`.claude/workflows/` and edit it there. The copy runs as `/build-orchestrator`,
beside the plugin's `/sutra:build-orchestrator`. Keep `export const meta` the
first statement and a plain object literal (no variables, function calls,
spreads, or string concatenation), or Claude Code drops the command from `/`
autocomplete. Run `/reload-skills` after editing.

## Methodology behind it

The workflow is the mechanical half of a larger practice:

- `/sutra:multi-session-build` -- how to run a large build across many
  sessions with independent validation and no deferrals.
- `/sutra:scaffold-execution-plan` -- how the `execution_plan/` tree and its
  INDEX are structured, and what each slice entry contains.
