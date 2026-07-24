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

## Branch catalog

Each slice does its work on its own branch. This table doubles as the branch
catalog: it maps a slice to its branch, its latest commit, and the base it
branched from without leaving this file. Keep it row-aligned with the slice
table above -- one row per slice id, in the same order.

| Slice id | Branch | SHA | Base |
| --- | --- | --- | --- |
| <slice-id-1> | slice/<slice-id-1> | <merge-sha> | main |
| <slice-id-2> | slice/<slice-id-2> | <head-sha> | main |
| <slice-id-3> | slice/<slice-id-3> | TODO: add on first commit | main |

<!-- One row per slice, same ids and order as the slice table above. -->

- **Branch** -- the git branch the slice's work lives on. Derive it from the
  slice id so the two never drift (e.g. `slice/<slice-id>`).
- **SHA** -- the branch tip, or the merge commit once the slice is integrated.
  Leave a `TODO` marker until the first commit exists.
- **Base** -- the branch or commit this slice branched from. Usually the
  integration branch (e.g. `main`); name another slice's branch when slices
  stack on each other.

## Column notes

- **Slice id** -- stable identifier used in branch names, briefs, and handoffs.
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
