# Session protocol

<!-- TEMPLATE: fill in every <placeholder> and TODO for your own project, then delete these notes. -->

The rules every build session follows. This protocol is the same for
each slice; only the slice-specific inputs change. Adopt it verbatim or
adapt the gate names to your stack -- but keep the shape: build ->
review -> fix -> independent validation -> handoff, with a human gate
between sessions.

## Core principle: every session is stateless

Assume a session remembers nothing from the last one. Any fact that must
survive to the next session lives in a durable artifact, never in a
session's working memory:

- **This plan** -- the operating profile, slice list, and the protocol
  you are reading.
- **The INDEX** (`<path-to-index>`) -- one status row per slice
  (`PENDING` / `IN_PROGRESS` / `DONE` / `BLOCKED`).
- **Per-slice briefs** (`<path-to-briefs>/<slice-id>.md`) -- the
  declared scope and acceptance criteria for one slice.
- **Evidence handoffs** (`<path-to-handoffs>/<slice-id>.md`) -- pasted,
  real output proving the slice is done.
- **Next-session starter** (`<path-to-starter>`) -- the drafted kickoff
  for the following slice.

If it is not written into one of these, it does not exist next session.
Do not rely on chat history, scrollback, or "the previous agent knew."

## The per-slice loop

Run these steps in order for exactly one slice per session. Do not start
a second slice in the same session.

### 0. Resume, sync, and load the operating profile

Every session starts cold, so never assume the local tree is current.
On resume, sync and run a staleness check **before** you start the
slice, then load context in a fixed order:

- **Sync the remote first, as a manual, explicit step.** You run
  `git fetch origin`, or the session runs it in plain view as the
  kickoff's first command. Nothing fetches on its own: no hook,
  scheduled job, or background script fetches behind your back. The
  fetch updates `origin/<build-branch>` and `origin/<default-branch>`;
  compare against those, not a stale local checkout. If
  `<build-branch>` is behind its remote, you fast-forward it
  (`git merge --ff-only origin/<build-branch>`) before the session
  builds; the session does not pull, merge, or reset to sync.
- **Run a staleness check.** Confirm the on-disk INDEX, handoffs, and
  briefs match the synced state. If the local tree is behind or has
  diverged, stop and ask the person to reconcile it before starting --
  do not build against stale artifacts.
- **Load durable context in this fixed order**, each fully before the
  next:
  1. This plan -- the master plan, operating profile, and protocol you
     are reading.
  2. The INDEX row for `<slice-id>` -- confirm it is the next unblocked
     slice.
  3. The prior slice's handoff (`<path-to-handoffs>/<prev-slice-id>.md`)
     -- carried-over context, deviations, and open follow-ups.
  4. This slice's brief (`<path-to-briefs>/<slice-id>.md`) -- the
     declared scope and acceptance criteria.
- TODO: list any project-specific context to load here (coding
  standards, architecture notes, `<domain-glossary>`).

### 1. Build the slice to full declared scope

- Implement everything in the `<slice-id>` brief. No deferrals, no
  "will finish next session," no TODO-for-later left in shipped code.
- If the scope turns out wrong or too large, **stop and renegotiate the
  brief** -- do not silently ship a subset.
- Work on the plan's one dedicated build branch: `<build-branch>` (e.g.
  `build/<plan-name>`). Never work directly on `<default-branch>`.

### 2. Adversarial code review

- Hand the diff to a **different reviewer** than the builder (a separate
  agent or person). Self-review does not satisfy this step.
- The reviewer hunts for correctness bugs, missing edge cases, and scope
  gaps against the brief. Output is a ranked findings list, each tagged
  blocking or non-blocking.
- Command: `<review-command>`.

### 3. Bounded fix

- Fix **only the blocking findings** from step 2. Do not gold-plate and
  do not fold in unrelated refactors.
- Log non-blocking findings as follow-ups in `<path-to-followups>`; do
  not act on them now.
- Re-run the relevant gate(s) after each fix.

### 4. Independent completeness validation

- A **third role** (neither builder nor reviewer) validates the slice.
  This is a gate, not a courtesy pass.
- The validator:
  1. Walks every acceptance criterion in the `<slice-id>` brief.
  2. Re-runs the gates from a clean state: `<gate-command>`.
  3. Confirms zero deferrals -- no stubbed criteria, no "mostly done."
  4. Returns a single verdict: **DONE** or **BLOCKED** (with the failing
     criterion named).
- If **BLOCKED**, return to step 1 or 3 as the finding dictates. Do not
  mark the slice done to "unblock the pipeline."

### 5. Retro and handoff

- Write the evidence handoff at `<path-to-handoffs>/<slice-id>.md`. It
  MUST carry **pasted real evidence** -- actual test output, benchmark
  numbers, or demo transcript -- not a claim that the gates passed.

  ```
  $ <gate-command>
  <paste the real command output here>
  ```

- Draft the next-session starter at `<path-to-starter>` while the
  context is fresh: what shipped, deviations from the brief, and the
  first moves for the next slice. Draft it from the kickoff template:
  fill its placeholders and prose, and add no commands. A person pastes
  it into the next session, where it carries their authority.
- Update the INDEX: set `<slice-id>` to `DONE` (or `BLOCKED`).
- Commit the slice on `<build-branch>` with a message that names the
  slice: `<commit-convention>` (e.g. `<slice-id>: <summary>`).
- **Do not push** unless the human explicitly asks. Committing locally
  is the default; publishing is a separate, requested action.

## The human review gate

Sessions never chain themselves unattended. After step 5, **stop**. A
human reviews the handoff, the INDEX, the drafted starter, and the next
slice's brief -- the starter and the brief read in full before the
starter is pasted, because an agent may have written them and the next
session runs their commands -- and decides whether the next session
starts. Do not auto-advance to the next slice, do not open the next
session, and do not push or merge on your own initiative.

This gate governs sessions run by hand, one slice each. A
`/sutra-harness:build-orchestrator` run replaces it with the workflow's own
rule: the run chains every slice that is not DONE and stops at the first one
that does not validate.

- Between-session owner: TODO name the human who holds this gate.
- Resume signal: TODO define how the next session is authorized to
  start (e.g. an explicit go-ahead referencing the next `<slice-id>`).

## Quick checklist (per session)

- [ ] Synced the remote by hand (explicit fetch; any fast-forward done
      by the person), ran staleness check, loaded plan -> INDEX ->
      prior handoff -> brief for `<slice-id>` in order (step 0)
- [ ] Built full declared scope, zero deferrals, on `<build-branch>`
      (step 1)
- [ ] Adversarial review by a different reviewer (step 2)
- [ ] Fixed blocking findings only; logged the rest (step 3)
- [ ] Independent validator returned DONE / BLOCKED (step 4)
- [ ] Handoff carries pasted real evidence; starter drafted from the
      kickoff template with no added commands; INDEX updated;
      committed, not pushed (step 5)
- [ ] Stopped at the human gate (no unattended chaining); the starter
      and the next brief were read in full before the starter was pasted
