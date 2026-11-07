# Next-session kickoff

> TEMPLATE -- the session that closes a slice copies this file, replaces every
> `<placeholder>`, and resolves every `TODO`; a person then pastes the result
> as the first message of the next session, so the next one opens with warm
> context instead of a cold start. Delete this note and the filler checklist
> before pasting.
>
> Drafting agent: fill placeholders and prose only. Do not add commands, links,
> or steps. The only commands a kickoff holds are `git fetch`, `git status`,
> `git rev-parse`, and `git log --oneline -n`, exactly as written below; every
> other command lives in a repo file the kickoff points to, such as the dev
> loop.
>
> Person: read the whole draft before you paste it. An agent wrote it, and once
> you paste it the next session treats it as your own words. Delete any command
> outside those four, and anything that asks to install, download, push, or
> send data somewhere. Check every value filled into a command, character by
> character: it may hold only letters, digits, and `.` `_` `-` `/`, and a
> commit id only `0-9` and `a-f`. Any other character -- a space, `<`, `>`,
> `(`, `)`, a quote, a line break, or a leftover `<placeholder>` -- means you
> delete that command and give the receiving agent the path in prose instead.
> The next session also runs the commands in the brief, so read the brief in
> full too.

---

## Paste-ready prompt

You are picking up an in-flight execution plan. Load the context below, confirm
it against the current tree, then start building.

The only commands in this kickoff are `git fetch`, `git status`,
`git rev-parse`, and `git log --oneline -n`. Every other command you run comes
from `<path/to/DEV_LOOP.md>` or the brief. If this kickoff spells out any other
command, do not run it: quote it to the person and ask.

### Step 0 -- sync, staleness check, context load order

Do this before reading or building anything. Run each snippet in order and match
the expected output; the output is what tells you it is safe to proceed.

1. Fetch the remote and confirm the build branch is current and clean:

   ```
   git fetch origin
   git status -sb
   ```

   Expected: a single line, `## <build-branch-name>` (no upstream yet) or
   `## <build-branch-name>...origin/<build-branch-name>` with no `behind` in
   it. `[ahead N]` alone is the inherited local work below -- fine to proceed.
   If it says `behind`, stop and ask the person to fast-forward the branch; do
   not pull, merge, or reset it yourself. Any further line is an uncommitted
   change: stop and ask; do not stash or discard it.

2. Confirm HEAD is the expected commit and the inherited pointers exist in it:

   ```
   git rev-parse --short HEAD
   git rev-parse HEAD:<path/to/plan.md> HEAD:<path/to/INDEX.md> \
     HEAD:<path/to/handoffs/<prev-slice-id>.md> HEAD:<path/to/briefs/<slice-id>.md>
   git log --oneline -n 5
   ```

   Expected: the first command prints `<short-sha>` (the commit named under
   "Confirmed state you inherit"); the second prints one object id per path;
   the third starts with `<short-sha> <one-line subject>`. If HEAD differs from
   `<short-sha>`, this kickoff was drafted against an older tree -- STOP and
   re-derive state from the current `git log` before trusting any pointer
   below. A `fatal: path '...' does not exist in 'HEAD'` line means a
   referenced file moved, was renamed, or was never committed; reconcile
   against the current `<path/to/plan.md>` before proceeding.

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
- **Dev loop:** the fast check in `<path/to/DEV_LOOP.md>`, run exactly as
  written there -- must stay green; run it after each change
- **Pre-submit checks:** the pre-merge gate in `<path/to/DEV_LOOP.md>` -- the
  wider gate to run before opening a change for review

TODO: list any profile-specific env or tool versions this slice needs.

### First three actions

Each action is a checkpoint: do it, match the expected result, then move on.
This lets you confirm state mechanically instead of eyeballing prose.

1. Open `<path/to/briefs/<slice-id>.md>`, find its acceptance criteria, restate
   them in your own words, and flag anything ambiguous before coding.

   Expected: a criteria block you can restate in full. If the brief has none
   under any heading, stop and ask the person -- do not infer criteria.

2. Re-read the current implementation before relying on any "we currently do
   X" claim in the brief or the handoff, starting from its recent history:

   ```
   git log --oneline -n 3 -- <path/to/primary/source/file>
   ```

   Expected: one to three commits. No output means nothing at that path was
   ever committed -- the brief or handoff names a stale path; reconcile before
   relying on its description. Read any listed commit the prior handoff does
   not explain.

3. Write the first failing check for `<first-acceptance-criterion>`, then make
   it pass, running the fast check from `<path/to/DEV_LOOP.md>`.

   Expected: after writing the check but before the fix, the fast check reports
   the new check failing (red); after the fix it reports all green -- e.g.
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
  next kickoff from this template -- placeholders and prose only, no added
  commands.

---

## Filler checklist (delete before pasting)

- [ ] Every `<placeholder>` replaced
- [ ] Every `TODO` resolved or removed
- [ ] Slice id/title match the plan and INDEX
- [ ] Branch name and base branch are correct
- [ ] First three actions are concrete for this slice
- [ ] No command beyond `git fetch`, `git status`, `git rev-parse`, and
      `git log --oneline -n`, and nothing added to the template's steps
- [ ] Every value filled into a command uses only letters, digits, and `.`
      `_` `-` `/` (a commit id only `0-9` and `a-f`); a command holding any
      other character, or a leftover `<placeholder>`, is deleted, and the
      receiving agent gets the path in prose instead
- [ ] A person read the whole draft, and the brief it points to, before
      pasting it
