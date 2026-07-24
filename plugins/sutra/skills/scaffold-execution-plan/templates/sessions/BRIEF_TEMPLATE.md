# Slice brief

<!-- TEMPLATE: copy this file to execution_plan/sessions/briefs/<slice-id>.md and
     fill every placeholder. This is the single document a fresh session reads to
     start the slice cold -- it must stand alone. Replace all <angle-bracket>
     tokens and resolve every TODO before the session begins. Delete this note. -->

- Slice: `<slice-id>` -- <short title>
- Owner session date: <YYYY-MM-DD>
- Source of truth: `execution_plan/MASTER_PLAN.md` (row `<slice-id>`)

## Mission

TODO: one paragraph. State the usable increment this slice ships -- the
observable capability that exists after merge and did not exist before.
Write it as an outcome ("a user can <do X>"), not a task list. If you cannot
name the increment in one sentence, the slice is mis-scoped -- split it in
`MASTER_PLAN.md` first.

## In scope

- TODO: concrete deliverable 1
- TODO: concrete deliverable 2
- TODO: concrete deliverable 3

## Non-goals

Name what a reader might reasonably assume is included but is NOT. Each
non-goal points at the slice or backlog item that owns it.

- TODO: excluded item -- owned by `<slice-id-or-backlog-ref>`
- TODO: excluded item -- deferred, tracked in `<location>`

## Inputs and preconditions

Confirmed facts so the session does not re-derive or re-ask. Every line here
is settled -- if a line is still open, resolve it before the session starts,
do not carry a question into the build.

- Branch/worktree: `<branch-or-worktree-path>` (NOT the default branch)
- Repo root: `<absolute-path>`
- Fast local check: `<command>` (see `execution_plan/DEV_LOOP.md`)
- Language/runtime version: `<version>` -- pinned in `<file>`
- Entry points to touch: `<path>`, `<path>`
- Frozen contracts this slice consumes: `<contract-or-interface>` (see
  Dependencies)
- Fixtures / test data available: `<path-or-command>`
- Known-good baseline: `<command>` passes at `<sha-or-tag>`
- TODO: any other settled fact the session would otherwise re-discover

## Acceptance criteria

Each criterion is verified by a NAMED command or an observable artifact. If a
criterion cannot be mechanically checked, rewrite it until it can. No
criterion may read "works correctly" or "looks right".

| # | Criterion (observable outcome)        | Check (command or artifact)          |
|---|---------------------------------------|--------------------------------------|
| 1 | TODO: outcome                         | `<command>` exits 0                  |
| 2 | TODO: outcome                         | `<command>` prints `<expected>`      |
| 3 | TODO: new behavior covered by a test  | `<test-command>` -- named test green |
| 4 | TODO: artifact exists / has shape     | `<path>` matches `<golden-or-schema>`|
| 5 | TODO: no regression in <area>         | `<command>` still passes             |

Notes:
- Prefer a command that returns a nonzero exit on failure over eyeballing
  output.
- Express each criterion as a runnable shell snippet plus its expected output
  -- a mechanically-checkable checkpoint someone can paste and compare, not a
  prose assertion. State the command and the exact output (or exit status) it
  must produce, e.g.:

  ```
  $ <command-under-test> --flag <arg>
  <expected line of output>
  ```

  The checkpoint passes only when the snippet reproduces that output.
- If a criterion needs a new test to be checkable, writing that test is part
  of this slice's scope.

## Dependencies

- Depends on slices: `<slice-id>`, `<slice-id>` (must be DONE in
  `execution_plan/sessions/INDEX.md` before this slice starts)
- Frozen contracts consumed (do not modify here):
  - `<interface-or-schema>` -- defined by `<slice-id>` at `<path>`
  - `<config-or-env-key>` -- shape fixed; treat as read-only
- Downstream slices waiting on this one: `<slice-id>` (do not break the
  contract they will consume -- see Non-goals)

## Sharp edges / known traps

Failure modes specific to this slice. Pull the relevant constraints from the
`## Frozen contracts` and `## Non-goals` sections of `MASTER_PLAN.md` and add
anything the pressure-test surfaced for this slice.

- TODO: hidden shared state -- `<file-or-global>` is also written by
  `<slice-id>`; order of operations matters.
- TODO: the acceptance check passes but does NOT catch `<class-of-bug>`;
  guard it with `<extra-assertion-or-test>`.
- TODO: runtime/deployment condition a local run never exercises --
  `<condition>`; verify with `<command-or-fixture>`.
- TODO: graceful degradation -- on `<failure>`, the product path must
  `<fallback>`, never propagate the error.

## Definition of done

All true before the slice is DONE. No partial credit, no cross-session
deferral of declared scope.

- [ ] Full slice scope implemented (no silent shrink; scope changes were
      renegotiated in `MASTER_PLAN.md`, not dropped).
- [ ] Every acceptance criterion above passes via its named check.
- [ ] Fast local check green: `<command>`.
- [ ] Pre-merge gate green: `<command(s)>` (see `DEV_LOOP.md`).
- [ ] Adversarial review clean, or remaining findings logged with reason.
- [ ] Independent validation clean, or gaps logged with reason.
- [ ] Handoff written at `execution_plan/handoffs/<slice-id>.md`.
- [ ] `execution_plan/sessions/INDEX.md` row `<slice-id>` set to DONE.
- [ ] Next slice starter brief drafted so the next session opens with
      context, not a cold start.
