# Next-session kickoff

> TEMPLATE -- copy this file, replace every `<placeholder>` and resolve every
> `TODO`, then paste the result as the first message of the next session. The
> previous session drafts it so the next one opens with warm context instead of
> a cold start. Delete this note before use.

---

## Paste-ready prompt

You are picking up an in-flight execution plan. Load the context below, confirm
it against the current tree, then start building.

### Step 0 -- sync, staleness check, context load order

Do this before reading or building anything. Run each snippet in order and match
the expected output; the output is what tells you it is safe to proceed.

1. Fetch the remote and confirm the build branch is not behind:

   ```
   git fetch origin
   git status -sb | head -1
   ```

   Expected: `## <build-branch-name>...origin/<build-branch-name>` with no
   `[behind N]`. If it shows `[behind N]`, fast-forward before touching
   anything: `git pull --ff-only`. A bare `[ahead N]` is the inherited local
   work below -- fine to proceed.

2. Confirm the tree is clean and sitting on the expected commit:

   ```
   git rev-parse --short HEAD
   git status --porcelain
   ```

   Expected: HEAD prints `<short-sha>` (the commit named under "Confirmed state
   you inherit"); the second command prints nothing (empty == clean tree). If
   HEAD differs from `<short-sha>`, this kickoff was drafted against an older
   tree -- STOP and re-derive state from the current `git log` before trusting
   any pointer below.

3. Staleness check -- confirm the inherited pointers still exist:

   ```
   test -f <path/to/briefs/<slice-id>.md> \
     && test -f <path/to/INDEX.md> \
     && test -f <path/to/plan.md> \
     && echo OK
   ```

   Expected: prints `OK`. Silence means a referenced file moved or was renamed
   since this kickoff was drafted; reconcile against the current
   `<path/to/plan.md>` before proceeding.

Then load context in this fixed order -- each item assumes the earlier ones:

1. `<path/to/plan.md>` -- roadmap and slice ordering (the map).
2. `<path/to/INDEX.md>` -- confirm `<slice-id>` is still the next `PENDING` slice.
3. `<path/to/handoffs/<prev-slice-id>.md>` -- what shipped and open followups.
4. `<path/to/briefs/<slice-id>.md>` -- the slice you build now (source of truth
   for scope + acceptance criteria).
5. `<path/to/DEV_LOOP.md>` -- the fast check and pre-merge gate (the operating
   profile itself lives in the master plan).

### Build this slice next

- **Slice:** `<slice-id>` -- <slice-title>
- **Brief:** `<path/to/briefs/<slice-id>.md>`
- **Goal (one line):** <what "done" looks like for this slice>

Read the brief in full before writing any code. It is the source of truth for
scope and acceptance criteria.

### Confirmed state you inherit

The previous session closed with the tree in a known-good state. Trust these
pointers, but re-read the current code before relying on any "we currently do X"
claim -- the plan and the code can drift.

- **Plan:** `<path/to/plan.md>` -- overall roadmap and slice ordering
- **Index:** `<path/to/INDEX.md>` -- per-slice status; `<slice-id>` is marked
  `PENDING`
- **Prior handoff:** `<path/to/handoffs/<prev-slice-id>.md>` -- what shipped,
  deviations, and open followups from the last session
- **Last commit on the build branch:** `<short-sha>` -- <one-line subject>

TODO: confirm the branch is clean (`git status`) and on the expected commit
before starting.

### Operating profile and dev loop

- **Profile:** `<profile-name>` -- defined in the master plan (`<path/to/plan.md>`)
- **Dev loop command:** `<command>` -- must stay green; run it after each change
- **Pre-submit checks:** `<command>` -- the wider gate to run before opening a
  change for review

TODO: list any profile-specific env or tool versions this slice needs.

### First three actions

Each action is a runnable checkpoint: run the snippet, match the expected
output, then move on. This lets you confirm state mechanically instead of
eyeballing prose.

1. Surface the acceptance criteria, then restate them in your own words and flag
   anything ambiguous before coding:

   ```
   sed -n '/[Aa]cceptance/,/^## /p' <path/to/briefs/<slice-id>.md>
   ```

   Expected: prints the acceptance-criteria block. Empty output means the brief
   uses a different heading -- open it in full and locate the criteria by hand.

2. Re-read the current implementation and confirm it is not newer than the tree
   this kickoff was drafted against:

   ```
   git log -1 --format='%h %s' -- <path/to/primary/source/file>
   ```

   Expected: the file exists and its last-touching commit is at or before
   `<short-sha>`. A newer commit means the source changed after this kickoff was
   written -- reconcile against the brief before relying on its description.

3. Write the first failing check for `<first-acceptance-criterion>`, then make
   it pass:

   ```
   <command>
   ```

   Expected: after writing the check but before the fix, `<command>` reports the
   new check failing (red); after the fix it reports all green -- e.g.
   `<expected-green-summary>`.

### Reminders (do not skip)

- **Branch:** work on `<build-branch-name>`; create it from `<base-branch>` if
  it does not exist. Never commit directly to `<base-branch>`.
- **Do not push.** Commit locally only. Opening a remote change is a separate,
  explicit step -- wait for the go-ahead.
- **Keep scope to `<slice-id>`.** No scope creep. If you find work that belongs
  to another slice, note it in the handoff and leave it out of this change.
- **Graceful degradation.** A failure in this slice must not break the wider
  build; fail soft and surface the error.
- **Close the loop.** End the session with a handoff at
  `<path/to/handoffs/<slice-id>.md>`, update `<path/to/INDEX.md>`, and draft the
  next kickoff from this template.

---

## Filler checklist (delete before pasting)

- [ ] Every `<placeholder>` replaced
- [ ] Every `TODO` resolved or removed
- [ ] Slice id/title match the plan and INDEX
- [ ] Branch name and base branch are correct
- [ ] First three actions are concrete for this slice
