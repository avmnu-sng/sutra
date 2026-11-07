# Slice index

> Template. Copy this file into your plan directory and fill in the rows for
> your own project. Replace every `<placeholder>` and resolve every `TODO`.

This file is the single source of truth for slice status. It drives resume:
the build orchestrator reads this table before starting work, skips every slice
marked `DONE`, and picks up at the first slice that is not. Re-running the build
therefore resumes where the last run stopped instead of redoing finished work.

Keep it current. Update a slice's `Status` and `Evidence` the moment its state
changes -- a stale row either reruns finished work or strands unfinished work.

## Status values

- `PENDING` -- not started.
- `IN_PROGRESS` -- being worked on now; not yet acceptance-complete.
- `BLOCKED` -- cannot proceed; note the blocker in the slice brief.
- `DONE` -- acceptance criteria met and evidence recorded. Skipped on resume.

## Slices

| Slice id | Title | Status | Brief (path) | Acceptance summary | Evidence (path to handoff) |
| --- | --- | --- | --- | --- | --- |
| <slice-id-1> | <short title> | DONE | briefs/<slice-id-1>.md | <one-line acceptance summary; e.g. `<command>` exits 0> | ../handoffs/<slice-id-1>.md |
| <slice-id-2> | <short title> | IN_PROGRESS | briefs/<slice-id-2>.md | <what must be true to call it done> | TODO: add on completion |
| <slice-id-3> | <short title> | PENDING | briefs/<slice-id-3>.md | <mechanically checkable criterion> | TODO: add on completion |

<!-- Add one row per slice. Order top-to-bottom in intended execution order. -->

## Build branch

Every slice is built and committed on one build branch: `<build-branch-name>`,
created from `<base-branch>`. `/sutra:build-orchestrator` never creates or
switches a branch. It commits each slice that validates to the checked-out
branch, one commit per slice, and that commit also sets the slice's row above
to `DONE`.

## Column notes

- **Slice id** -- stable identifier used in briefs and handoffs.
  Never reuse or renumber an id once work has started.
- **Title** -- short human-readable name; no need to be unique.
- **Status** -- one of the values above. Only `DONE` is skipped on resume.
- **Brief (path)** -- relative path to the slice's brief (scope, plan,
  acceptance criteria). Keep it next to this index.
- **Acceptance summary** -- the one-line, mechanically checkable bar for
  `DONE`. If you cannot check it from a command or artifact, rewrite it.
- **Evidence (path to handoff)** -- relative path to the handoff written when
  the slice reaches `DONE` (what shipped, how it was verified, followups).
  Leave a `TODO` marker until then.
