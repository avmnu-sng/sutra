---
description: Scaffold a repeatable execution-plan structure (master plan, session protocol, dev loop, slice index, and per-slice templates) for a large, multi-session build that must survive across many sessions, for the /sutra:build-orchestrator workflow to drive.
disable-model-invocation: true
---

# Scaffold execution plan

Lay down a durable, resumable structure for a build too large for one
session, for the `/sutra:build-orchestrator` workflow to drive. The
structure is the source of truth across sessions: what to build next, in
what order, and what "done" means for each unit of work.

This skill copies ready-made skeleton files that carry explicit TODO
placeholders. It does not invent project specifics -- you (or a later
planning pass) fill the placeholders against the real repo. It writes many
files into the repo, so only a person starts it, with
`/sutra:scaffold-execution-plan`; Claude does not start it on its own.

## When to use

- A build that plausibly spans many sessions or many days.
- Work that decomposes into independent, shippable vertical slices.
- Any effort where "where did we leave off?" is a real cost and resume
  must be mechanical, not from memory.

## When not to use

- A single-session change, a bug fix, or a one-slice feature. The
  overhead is not worth it.
- A repo that already has an `execution_plan/` tree. Read it and resume
  instead of re-scaffolding (see Resume below).

## Preconditions

- Run on a dedicated build branch or a worktree. NEVER scaffold or build
  on the default branch. Create the branch/worktree first.
- Confirm the repo root and the local fast-check command before writing
  `DEV_LOOP.md`; if unknown, leave it as a TODO rather than guessing.

## Step 0 -- adversarial pressure-test first

Before writing the plan, pressure-test the intended approach. The goal is
to surface the failure modes that a naive plan silently regresses on, then
encode each one as an explicit "do not regress" invariant in
`MASTER_PLAN.md`.

Walk these prompts and write down every real delta:

- Where does the naive slice ordering create a dependency cycle or force
  a big-bang integration at the end?
- Which slices share hidden state (a schema, a config file, a global) so
  that finishing them in the wrong order corrupts the other?
- What does each slice's acceptance criterion NOT catch? Name the class of
  bug that passes the criterion but breaks the system.
- Which "we will handle it later" is actually load-bearing now?
- What breaks under the real deployment/runtime conditions that a local
  run never exercises?

Every confirmed delta becomes a bullet in the `## Do not regress` section
of `MASTER_PLAN.md`. The plan is only trustworthy once it enforces the
deltas the pressure-test found.

## Step 1 -- lay down the structure

Create these files if absent. Do not overwrite existing ones.

```
execution_plan/
  MASTER_PLAN.md
  SESSION_PROTOCOL.md
  DEV_LOOP.md
  sessions/
    INDEX.md
    BRIEF_TEMPLATE.md
    HANDOFF_TEMPLATE.md
    KICKOFF_TEMPLATE.md
    briefs/          (one brief per slice, created as slices start)
  handoffs/          (one handoff per completed slice)
```

The orchestrator ships with this plugin and runs as
`/sutra:build-orchestrator` (Step 3); there is nothing to copy.
`${CLAUDE_PLUGIN_ROOT}` is this plugin's root at runtime. To change the
orchestrator's prompts, stages, or plan format, follow the Customize section
of `${CLAUDE_PLUGIN_ROOT}/workflows/README.md`; a project copy runs as
`/build-orchestrator` and no longer changes when the plugin updates.

## Step 2 -- copy and adapt the templates

Do not hand-write these files. This skill ships ready-to-copy templates in
its own `templates/` directory -- copy and adapt them rather than
regenerating the structure from scratch:

```
${CLAUDE_PLUGIN_ROOT}/skills/scaffold-execution-plan/templates/
  MASTER_PLAN.md
  SESSION_PROTOCOL.md
  DEV_LOOP.md
  sessions/
    INDEX.md
    BRIEF_TEMPLATE.md
    HANDOFF_TEMPLATE.md
    KICKOFF_TEMPLATE.md
```

Copy each template into the `execution_plan/` tree from Step 1:

- `MASTER_PLAN.md`, `SESSION_PROTOCOL.md`, `DEV_LOOP.md` -> the root of
  `execution_plan/`.
- `sessions/INDEX.md` -> `execution_plan/sessions/INDEX.md`.
- `sessions/BRIEF_TEMPLATE.md`, `sessions/HANDOFF_TEMPLATE.md`,
  `sessions/KICKOFF_TEMPLATE.md` -> `execution_plan/sessions/`. These are
  per-slice stencils: copy one per slice into `briefs/`, `handoffs/`, and
  the next-session kickoff as slices start and finish. An agent drafts each
  kickoff and a person pastes it into the next session, where it carries
  that person's authority, so the kickoff template allows only a closed set
  of four git commands and the person reads every draft before pasting it.

Each template carries explicit `TODO:` placeholders (the slice DAG and
acceptance criteria, the dev-loop commands, the `Do not regress` bullets,
per-slice brief/handoff/kickoff fields). Copy verbatim, then fill only the
placeholders against the real repo -- do not regenerate the surrounding
structure, and do not invent specifics a later planning pass should
supply. Keep every `TODO:` marker obvious so the planning pass finds it.

`MASTER_PLAN.md` also carries the Release-milestones rollup: the grouping
of slices into versioned releases, each with its version/tag scheme and
cut criteria (see Cutting a release). Fill it or leave it as a visible
`TODO:` like any other placeholder.

## Plan phase and implement phase

Split the build into two phases with different tool allowlists, and enforce
the split in each phase's frontmatter rather than trusting intent.

- Plan phase -- run with a read-only tool allowlist (read, search, and
  list only; no write, edit, or mutating shell). This phase reads the real
  repo and fills the templates' `TODO:` placeholders: the slice DAG and
  acceptance criteria in `MASTER_PLAN.md`, the commands in `DEV_LOOP.md`,
  and the `Do not regress` bullets from Step 0. Its only output is the
  completed plan -- no source changes. A read-only allowlist makes it
  impossible for the planning pass to start editing code before the plan
  is agreed.
- Implement phase -- run with write tools enabled (read, edit, write, and
  shell). This phase drives `SESSION_PROTOCOL.md` one slice at a time and
  is the only phase permitted to touch product source.

Convention: declare the allowlist in the frontmatter of each phase's
command/agent definition (an `allowed-tools:` list), so the boundary is
mechanical. The planning agent physically cannot write; the split is
enforced, not merely documented.

## Step 3 -- run it

Run `/sutra:build-orchestrator` in the target project, from the build
branch or worktree (`/build-orchestrator` for a customized copy). It reads
`execution_plan/sessions/INDEX.md`, selects every non-DONE slice in listed
order, and drives each through the build -> review -> fix -> validate ->
retro and commit stages, committing each validated slice to the checked-out
branch and stopping at the first slice that does not validate.

## Resume

Resume is mechanical, driven by INDEX status -- never by recall.

- The INDEX is the source of truth. A run skips every DONE row and takes every
  other row -- PENDING, IN_PROGRESS, or BLOCKED -- in INDEX order, one slice at
  a time. It does not check dependencies, so list the slices in an order that
  satisfies them. A BLOCKED row is retried, not skipped.
- A run stops at the first slice that does not validate, leaves that slice's
  changes uncommitted, and starts no later slice. Finish the slice and commit
  it with its row set to DONE, or discard its changes, then run again; a run
  refuses to start on a dirty tree. The Resume section of
  `${CLAUDE_PLUGIN_ROOT}/workflows/README.md` covers each case.
- After a run that completes, the next run starts at the first row that is not
  DONE -- no bookkeeping beyond keeping the INDEX honest.

## Gates: where a person steps in

A `/sutra:build-orchestrator` run does not pause between slices. It drives
every remaining slice through every stage and commits each one that
validates. A person steps in when the run ends, complete or stopped at a slice
that did not validate: read the run's summary and the stage output in
`/workflows`, make the call it needs, and run it again.

`SESSION_PROTOCOL.md` governs sessions run by hand, one slice each, with a
human gate between them. Under `/sutra:build-orchestrator`, that gate is
replaced by the workflow's rule of stopping at the first slice that does not
validate. Start a run only when each validated slice may be committed without
a person reading it first; to review every slice before the next one starts,
run the sessions by hand instead.

The workflow asks no questions mid-run, so encode each decision in a file the
next run reads -- an INDEX status, a brief -- rather than in an answer you
expect it to wait for.

## Cutting a release

This kit assumes trunk-based releases (a tag on the default branch). If
your project uses release branches (LTS lines, backports), cut from yours
instead -- the gate criteria below are what matter, not the branch they
run on. Cut it in order:

1. Confirm every milestone in the release is `DONE` in
   `execution_plan/sessions/INDEX.md`. A single non-DONE slice blocks the
   cut.
2. Run the full pre-merge gate on the exact release SHA -- the SHA you
   will tag, not "a recent green run". Green is a precondition, not a
   formality.
3. Confirm the defer surface is empty: zero `BLOCKED` slices, zero
   unburned deferrals, zero `BUILT-UNTESTED` claims. Burn them down or
   renegotiate them out of the release first.
4. Rename the CHANGELOG `[Unreleased]` heading to the version and stamp
   the date (`## [X.Y.Z] - YYYY-MM-DD`), then open a fresh empty
   `[Unreleased]` above it.
5. Verify docs are current against the shipped code -- README, usage, and
   any version-pinned references.
6. Independent completeness gate -- a reviewer other than the author signs
   off on the release SHA. This is the eighth release-cut criterion in
   `MASTER_PLAN.md`; do not self-approve a release.
7. Tag `main` `vX.Y.Z` (or the next rung of the pre-release ladder --
   `vX.Y.Z-alpha.N` / `vX.Y.Z-beta.N` / `vX.Y.Z-rc.N`). Tag the gated SHA,
   nothing downstream of it.
8. Announce/publish -- push the tag, publish the artifact, post the notes.

Pre-release ladder (each rung is a real tag on `main`):

```
vX.Y.Z-alpha.N   internal / rough; API may still move
vX.Y.Z-beta.N    feature-complete; hardening + docs
vX.Y.Z-rc.N      release candidate; ship unless a blocker surfaces
vX.Y.Z           final
```

Copy-into-PR release checklist:

```
Release: vX.Y.Z (or -alpha.N / -beta.N / -rc.N)

- [ ] All included milestones DONE in INDEX
- [ ] Full pre-merge gate green on the exact release SHA <sha>
- [ ] Defer surface empty: no BLOCKED, no unburned deferrals, no BUILT-UNTESTED
- [ ] CHANGELOG [Unreleased] renamed to X.Y.Z with date; fresh [Unreleased] opened
- [ ] Docs current against shipped code
- [ ] Independent completeness gate passed (reviewer other than the author)
- [ ] Tag on main points at the gated SHA
- [ ] Announced / published
```

Do NOT:

- Tag a SHA the pre-merge gate has not passed.
- Ship with a non-empty defer surface (`BLOCKED` / deferrals /
  `BUILT-UNTESTED`).
- Hand-edit a changelog section that already shipped. Fix forward in the
  next version's section instead.

## Checklist

- [ ] On a dedicated build branch/worktree, not the default branch.
- [ ] Step 0 pressure-test run; deltas written into `## Do not regress`.
- [ ] All `execution_plan/` files created from `templates/` (none
      overwritten).
- [ ] Plan phase runs read-only; implement phase's write tools are a
      separate frontmatter allowlist.
- [ ] `DEV_LOOP.md` fast check and pre-merge gate filled or explicitly
      marked TODO.
- [ ] INDEX lists every slice as PENDING with a brief path.
- [ ] Release milestones grouped with a version/tag scheme, and cut
      criteria filled or explicitly marked TODO.
- [ ] No project specifics invented -- every unknown is a visible TODO.
- [ ] `/sutra:build-orchestrator` (or a customized copy, run as
      `/build-orchestrator`) launched from the build branch or worktree.
