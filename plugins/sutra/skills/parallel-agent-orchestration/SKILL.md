---
description: Use when running multiple agents or sessions concurrently against shared state, to pick an isolation regime and coordination protocol that stops two writers from corrupting the same file, branch, or working tree.
---

# Parallel agent orchestration

The rest of sutra's guidance assumes one agent, one session, one working tree
-- a single writer. Fan out concurrent agents against shared state and that
assumption breaks silently: two agents open the same file, both edit, the
second write clobbers the first, and you lose work or produce an un-mergeable
tree with no error raised. Concurrency bugs do not announce themselves; you
discover them at merge time or in production.

Pick an isolation regime BEFORE you fan out. Retrofitting coordination onto
agents that are already running is how state gets corrupted.

## The one hard rule

Never let two agents mutate the same file at the same time without either a
mutex or separate worktrees. Every recipe below exists to enforce this single
invariant. If you cannot name the mechanism that prevents a concurrent
double-write, do not fan out yet -- run the work serially instead.

## Choose the regime

One question decides everything: **do the concurrent agents share a working
tree?**

- **Yes** -- they edit files in the same checkout -> Shared-state regime.
- **No** -- each owns an independent track with its own tree -> Disjoint
  regime.

When unsure, assume shared-state. It is the stricter of the two, and its
machinery is a superset of what the disjoint regime needs.

## Shared-state regime

Agents touch the same repository, so coordination is mandatory. Layer the five
controls below; each closes a different collision path.

### 1. Give each agent its own git worktree

A worktree is the executable form of the hard rule. `git worktree` gives every
agent an isolated checkout -- its own index and working files -- backed by one
shared object store and history. Two agents editing "the same file" now edit
two distinct paths; there is no in-place double-write to lose.

```
git worktree add ../wt-agent-a agent/track-a   # agent A's tree + branch
git worktree add ../wt-agent-b agent/track-b   # agent B's tree + branch
```

Each agent runs entirely inside its own worktree directory and commits to its
own branch. An integrator merges the branches afterward, where real conflicts
surface as ordinary, visible merge conflicts instead of silent clobbers. This
is the default; reach for the finer-grained controls below only when agents
must share one tree.

### 2. Maintain an owned-vs-blocking file map

When agents do share a tree, write down -- before any of them starts -- which
agent may write which paths. One table, single source of truth:

| Path / glob            | Owner (may write) | Blocked (read-only) |
| ---------------------- | ----------------- | ------------------- |
| `src/api/**`           | agent-a           | agent-b, agent-c    |
| `src/store/**`         | agent-b           | agent-a, agent-c    |
| `docs/**`              | agent-c           | agent-a, agent-b    |

Rules:

- Every writable path has exactly one owner. No path is writable by two agents.
- A non-owner may read an owned path but never edit it. If it needs a change
  there, it files the request; the owner makes the edit.
- Hand each agent its own row as an explicit non-goal: "you may edit only
  `src/api/**`; treat every other path as read-only."

### 3. Define named mutex groups

Some files resist single ownership -- a shared lockfile, a manifest, a central
registry, a generated index. For each, define a **named mutex group**: a set of
paths that must never be edited concurrently, plus a token that grants
exclusive write access.

- Name the group and list its paths (e.g. `deps-mutex` = `Gemfile`,
  `Gemfile.lock`, `vendor/manifest.json`).
- An agent acquires the token, edits every path in the group, commits, then
  releases. Only the token holder writes any member of the group.
- Keep groups small and disjoint. Overlapping groups reintroduce the deadlock
  and ordering problems the mutex was meant to remove.

### 4. Insert sequential gates where order matters

Isolation prevents collisions; it does not encode dependency. When agent B's
work is only valid after agent A's has landed -- B consumes an interface,
schema, or migration A produces -- add an explicit gate:

- B does not start until A's output is committed and verified.
- Make the gate a hard precondition in B's prompt, not a hope: "Do not begin
  until branch `agent/track-a` is merged and its tests are green."
- Prefer the fewest gates that capture the real dependency DAG. Every gate
  serializes work and gives back the throughput you fanned out to gain.

### 5. Use the branch name as a lock

The branch name is a free, globally visible mutex. Give every agent a unique
branch and make claiming it the first step:

- Each agent owns exactly one branch; the branch name is its lock token.
- Before starting, an agent checks the branch is unclaimed (does not already
  exist); two agents must never claim the same branch.
- No agent ever commits to another agent's branch, switches branches
  mid-flight, or touches the default branch.

Because a worktree binds one branch to one checkout, controls 1 and 5 reinforce
each other: unique branch, unique tree, no shared mutable state.

## Disjoint regime

The work splits into independent tracks that share no working tree. This is the
cheaper regime -- less coordination -- but only correct when the split is
genuinely dependency-free.

1. **Split into dependency-free tracks.** Carve the work so no track's output
   is another track's input. If a dependency remains, either merge the two
   tracks or move to the shared-state regime and add a sequential gate (control
   4). A hidden dependency across "independent" tracks is the classic disjoint
   failure.
2. **Give every track one shared constraints doc.** All tracks read the same
   single document: conventions, interfaces they must honor, naming, output
   format, sanitization or ASCII rules -- every invariant that must hold across
   the whole result. One doc, so the tracks cannot drift into mutually
   incompatible choices.
3. **Report back to an integrator.** Each track returns its result to one
   integrator agent (or you) who assembles the tracks into the final
   deliverable, resolves any seam mismatch, and owns the merged whole. The
   integrator is the single writer of the combined artifact.

## Advanced layer (optional)

Add these only when the basic regime is not enough -- richer coordination or a
higher correctness bar. They are opt-in, not default.

### File-based boundary channels

Let agents coordinate through the filesystem instead of shared memory. Each
agent reads and writes designated channel files -- a status file, a claims
directory, a results inbox -- and never touches another agent's private state
directly.

- The channel is the only shared surface; treat everything else as sandboxed
  and private to one agent.
- Make writes append-only or single-writer-per-file so the channel itself never
  becomes a contended mutable file (the very failure you are avoiding).
- A dropped or crashed agent leaves its last file state behind, so the protocol
  stays inspectable and recoverable -- you can read the channel to see exactly
  who claimed what.

### Consensus gate

For high-stakes changes, require agreement before anything is written:

1. **Propose.** One agent drafts the change as a proposal, not a commit.
2. **Consult peers.** Independent agents review the proposal and return
   critiques -- ideally agents that did not author it.
3. **Synthesize.** One agent reconciles the critiques into a single revised
   proposal.
4. **Human approves.** A person signs off on the synthesized proposal.
5. **A single committer writes.** Exactly one agent applies the approved change
   to the tree. No other agent writes during this step.

The gate keeps the many-reviewer benefit of fan-out while preserving a single
writer at the moment of mutation -- the hard rule, upheld under consensus.

## Preflight checklist

Before fanning out, confirm:

- [ ] Regime chosen: shared-state or disjoint, decided by the shared-tree
      question.
- [ ] For every file two agents might touch, a named mechanism prevents the
      concurrent write: separate worktree, single owner, or mutex group.
- [ ] Each agent has a unique branch, and claiming it is step one.
- [ ] Real dependencies are encoded as explicit sequential gates, not assumed.
- [ ] One shared constraints doc covers every cross-cutting invariant.
- [ ] An integrator (or the consensus committer) owns the final merge as the
      single writer.
- [ ] No agent's prompt permits switching branches, pushing, or editing the
      default branch.

## Executable primitive

The `/sutra:build-orchestrator` workflow is the sequential reference, not a
parallel fan-out. It keeps a single writer by running one slice at a time: it
takes every slice in `execution_plan/sessions/INDEX.md` that is not DONE, in
INDEX order, and runs each through build, review, fix, validation, and commit
in one working tree on the checked-out build branch. It commits each slice
that validates before it starts the next, and stops at the first slice that
does not. `${CLAUDE_PLUGIN_ROOT}/workflows/README.md` documents its stages and
stop rules.

The serial order is what keeps each commit to one slice. Every stage reads the
slice's changes as the uncommitted changes in that tree, and the commit stage
stages all of them, so a slice running beside it would land unreviewed edits
in its commit. Running its build stage in a separate worktree does not help
either: the review, validation, and commit stages read the session's tree and
would find none of the build's changes.

To run slices in parallel, apply this skill outside the workflow:

1. Group the slices into tracks that do not depend on each other. A slice that
   needs another track's output waits behind a sequential gate (control 4).
2. Give each track its own worktree and branch (controls 1 and 5).
3. Run each track in its own session, started in its worktree. A track can be
   driven by `/sutra:build-orchestrator` when the INDEX on its branch lists
   only that track's slices, so no two runs build the same slice.
4. Merge the branches back yourself as the integrator (control 1), and
   reconcile the INDEX and any other seam there.
