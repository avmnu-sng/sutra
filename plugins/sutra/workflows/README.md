# Sutra workflows

This directory ships **Claude Code Workflows** -- standalone JavaScript
orchestration scripts you copy into a project and invoke as slash commands.

## What a workflow is

A workflow is a deterministic JS script that Claude Code runs end to end. You
invoke it as `/<name>`, and instead of the model free-styling the whole task,
the script drives the control flow: it decides the order of steps, spawns
sub-agents, checks their output, loops, and stops. The model still does the
judgment-heavy work inside each step; the script guarantees the *sequence* is
repeatable.

Reach for a workflow when a task is long, multi-phase, and you want the same
path taken every time -- not a one-off prompt.

## Why they live here as files

Workflows cannot be bundled inside a Claude Code plugin. The plugin format has
no slot for them, so they cannot be distributed the way skills, commands, or
agents are. The workaround is to ship them as plain files in this directory.
You install a workflow by copying it into the target project.

## Installing a workflow

Two ways to get `build-orchestrator.workflow.js` into a project:

1. **Manual copy.** Copy the file into the project's
   `.claude/workflows/` directory (create the directory if it does not
   exist):

   ```
   mkdir -p .claude/workflows
   cp path/to/sutra/plugins/sutra/workflows/build-orchestrator.workflow.js .claude/workflows/
   ```

2. **Scaffold skill.** Run `/sutra:scaffold-execution-plan`. It drops the
   workflow into `.claude/workflows/` for you and also lays down the
   `execution_plan/` tree the workflow expects to read.

Once the file is in `.claude/workflows/`, invoke it by name, e.g.
`/build-orchestrator`.

## build-orchestrator.workflow.js

A reference orchestrator for executing a planned, multi-slice build without
babysitting it prompt by prompt. At a high level it:

- Reads an `execution_plan/` **INDEX** to discover the ordered list of slices.
- For each slice, runs a fixed pipeline:
  **build -> review -> fix -> independent-validate -> retro.**
- **Commits once per slice** so progress is captured incrementally.
- **Is resumable.** If it is interrupted -- or a slice fails -- re-running the
  workflow picks up where it left off rather than redoing completed slices.
- **Never pushes.** It only commits locally; publishing is left to you.
- **Stays off the default branch.** It expects a dedicated build branch to be
  checked out already and instructs every agent never to switch branches or
  touch the default branch, so orchestrated commits land on your feature
  branch. It does not hard-block -- keep the build branch checked out.

### It is a reference, not a black box

Treat `build-orchestrator.workflow.js` as a starting point to adapt, not a
turnkey tool. The slice pipeline, the validation gates, the commit message
shape, and the branch expectations all encode opinions that may not match your
project. Read it, then edit it. It is deliberately a single self-contained
file so you can.

## Methodology behind it

The workflow is the mechanical half of a larger practice. For the reasoning --
how to decompose work into slices, what belongs in an execution plan, and how
the build/review/validate loop is meant to be run -- see:

- **`multi-session-build`** skill -- the methodology for executing a large
  build across many sessions with independent validation.
- **`scaffold-execution-plan`** skill -- how the `execution_plan/` tree and its
  INDEX are structured, and what each slice entry should contain.

Read those first if you are new to this pattern; the workflow will make more
sense once you understand the plan it consumes.
