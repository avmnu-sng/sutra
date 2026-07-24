---
description: Use when planning or running a large build that spans many sessions or agents, to add gates that keep the assembled, deployed system honest -- not just each component -- and to prove "done" instead of assuming it.
---

# Multi-session build

A large build spread across many sessions leans on a harness: per-session
briefs, a definition of done, handoff notes, a pre-build design review. That
harness enforces discipline. It does not prove the assembled, deployed system
is correct or that it matches its own claims.

The core failure: value-ranked vertical slices are per-component by
construction. Each slice owns one component and ships it end-to-end. But
whole-system properties -- global fairness, a global rate limit, N-instance
liveness, failover, back-pressure across services -- belong to no single
slice. Nothing owns them, so nothing tests them. They pass review, pass every
per-slice test, and fail in production the first time the real topology runs.

Process rigor is not coverage. Add the gates below so emergent properties get
an owner, deferrals get burned down, and "done" is validated by someone who
did not build it.

## When to use

- A build planned as more than ~3 sessions or handed across agents.
- Any system with cross-component invariants (multiple instances, shared
  quotas, coordination, failover, ordering, exactly-once).
- Any build where a design doc or brief makes claims the code must honor.

## When not to

- A single-slice change fully covered by its own tests.
- A throwaway spike with no correctness bar and no downstream reader.

## The gates

### 1. Claims-vs-built ledger

Every load-bearing design claim carries one tag, kept in the design doc
itself (the artifact a reviewer opens first), reconciled every session:

- `BUILT+TESTED` -- code exists and a test or invariant exercises it.
- `BUILT-UNTESTED` -- code exists, nothing proves it.
- `DESIGN-ONLY` -- described, no slice will build it.

Rules:

- A claim no scheduled slice will build must read `DESIGN-ONLY` loudly, not
  sit in prose implying it is real.
- `BUILT-UNTESTED` is a standing debt; it must move to `BUILT+TESTED` or get
  an explicit deferral entry (gate 5).
- Reconcile the ledger at the start and end of every session. A claim whose
  tag no longer matches the code is a bug in the ledger; fix it before coding.

### 2. Integration / topology slice before the deploy slice

Schedule a first-class, tested slice that runs the system in its real shape
before the slice that deploys it:

- Real topology: N instances, not one; real coordination path, not a stub.
- Fault injection: kill an instance, partition the network, stall a
  dependency, replay a duplicate, clock-skew a node.
- Assert the whole-system properties directly: fairness across instances, the
  global limit holding under concurrent load, liveness when one node dies,
  correct failover.

Per-component slices cannot catch cross-component bugs by construction. This
slice is where they surface. Treat it as blocking, not optional polish, and
put it before deploy so failures are cheap. Build its assertions phased --
skeleton -> fail-first -> green (see the test-authoring skill) -- so a passing
topology test proves the property held, not that the test never exercised it.

### 3. Adversarial review on the code, every phase

The pre-build design review hardened the plan. Run the same scale-and-failure
review against the implementation each phase -- the bugs live in the code, not
the diagram.

- Re-ask the design-review questions ("what happens at 100x load, on retry
  storm, on partial failure") against the merged code as written.
- One design-time pass does not cover code that drifted from it during
  implementation.

### 4. Cross-slice assumption check

At plan time for each later slice, diff its assumptions against earlier
FROZEN decisions:

- List what the new slice assumes about interfaces, ordering, ownership,
  formats, and limits set by earlier slices.
- Compare against the frozen decisions those earlier slices actually shipped.
- A mismatch is a design bug caught before code, not a merge conflict caught
  after. Resolve it by amending the plan or re-opening the frozen decision
  explicitly -- never by silently coding against the stale assumption.

### 5. Deferred-items ledger, burned down each session

A `# harden later` comment in the code is not tracking. It rots, ships, and is
found by an incident.

- Maintain one deferred-items ledger outside the code (the design doc or a
  tracked list), each entry with an owner and a target slice.
- Every "later" -- a skipped edge case, an untested path, a stubbed
  dependency, a `TODO` -- becomes a ledger entry the moment it is created.
- Burn the ledger down each session. An entry may close (done) or be
  re-scheduled with reason, never silently drop.

### 6. Back-propagate every deviation into the design docs

When implementation diverges from the plan, update the design docs, not only
the handoff note.

- The design doc is what the next reviewer reads first; a deviation recorded
  only in a handoff is invisible there and will mislead.
- Fix the claim, its ledger tag (gate 1), and any dependent frozen decision in
  the same change that lands the deviating code.

### 7. Independent completeness gate

Adversarial review hunts bugs; completeness validation proves done. They are
different jobs -- run both, and never with the same agent. A third party --
not the builder, not the bug-reviewer -- closes each milestone against its
acceptance criteria, confirming zero open deferrals (gate 5) and zero
`BUILT-UNTESTED` claims (gate 1) in scope. Any unmet criterion means the fix
lands in-slice or the milestone is marked `BLOCKED` -- never `DONE` with an
asterisk. That is the whole bar.

This gate, the adversarial-review gate (3), and the ledgers it checks (gates
1 and 5) already ship as running code. The build-orchestrator workflow's
review and validate stages run them as separate agents: a fresh validator
walks each criterion in order, re-runs its tests and invariants firsthand
rather than trusting a green report, and returns DONE only on zero deferrals.
Keeping that validator genuinely independent is an agent-role problem the
parallel-agent-orchestration skill owns. Wire those in rather than re-deriving
the walk-each-criterion procedure here.

## Session checklist

Start of session:

- [ ] Reconcile the claims-vs-built ledger against current code (gate 1).
- [ ] Run the cross-slice assumption check for this slice (gate 4).
- [ ] Review open deferred items; pull this session's into scope (gate 5).

End of session:

- [ ] Re-tag every claim touched this session (gate 1).
- [ ] Back-propagate deviations into the design docs (gate 6).
- [ ] Log every new "later" as a deferred-items entry (gate 5).
- [ ] Run adversarial review on the code landed this phase (gate 3).

Before calling a milestone done:

- [ ] Topology / integration slice ran green in real shape (gate 2).
- [ ] Independent completeness gate passed with zero deferrals (gate 7).
