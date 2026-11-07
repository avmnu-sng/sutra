---
description: Use when deciding how much energy -- tokens, agent fan-out, verification passes, independent attempts, artifacts -- a task is worth, so spend tracks complexity times blast radius without ever trading away the correctness floor.
---

# Effort calibration

Energy is finite and every task asks for a share of it: tokens, parallel
agents, verification passes, independent attempts, artifacts. Spend too little
on a high-stakes change and you ship a defect; spend a fortune on a typo and you
burn the budget the real work needed. Match the spend to the task -- and never
buy the savings with correctness.

## The two dials

Two independent properties set the budget. Do not collapse them into one.

- **Complexity sets the breadth budget** -- how many agents you fan out, how
  many independent attempts you make, how many artifacts you produce, how wide
  you cast for coverage. More unknowns and moving parts earn more breadth.
- **Blast radius sets the correctness floor** -- which verification is
  mandatory and non-negotiable. How far a wrong answer reaches earns a higher
  floor, regardless of how simple the diff looks.

You trade away breadth to save energy. You never trade away the floor.

## Classify in four questions

1. **Stakes.** Does the change hit an irreversible or public surface -- a
   release, a data migration, a deletion, auth or a secret, money, or a
   cross-component invariant? Any yes forces a T3 floor, whatever the diff size.
2. **Reach.** Does it touch shared or core code beyond the paths you own?
3. **Knowns.** Are the location and the shape of a correct answer already known
   before you start?
4. **Unknowns.** After one read, how many independent unknowns remain -- none,
   a few, or many?

Map: the stakes answer sets the floor tier; reach and unknowns set the breadth
tier; the depth you run is `max(floor, breadth)`. The floor is never lowered to
match the breadth.

## The tiers

| Tier | Depth | Verification | Attempts | Artifacts | Retry / replan |
| ---- | ----- | ------------ | -------- | --------- | -------------- |
| **T0 -- trivial, contained** | Solo inline, no delegation | The change's own check, one pass | 1 | None -- answer in place | 1 replan; a second miss means you misclassified -- escalate |
| **T1 -- standard, localized** | Solo; delegate only mechanical legwork to one helper | Single pass, run the real path | 1 | Change plus its test | 2 attempts, 1 replan |
| **T2 -- complex or shared** | Fan out parallel reads and traces; keep design and trade-offs yourself; one reviewer who did not build it | Adversarial review by a different agent; single verifier | 1 plus review; two independent attempts only if the approach is genuinely uncertain | Change, test, and a short design note if a decision is load-bearing | 3 attempts, 2 replans; front-load disambiguation before building |
| **T3 -- critical, irreversible** | Fan out a workflow; separate builder, adversarial reviewer, and independent completeness validator -- never the same agent | Adversarial multi-vote (two or more independent reviewers, contradictions reconciled) plus an independent gate that re-runs the acceptance checks | 2-3 independent attempts on the uncertain core; choose by evidence, not confidence | Design doc or ledger, tests, an integration/topology slice, a deferred-items ledger | Bounded but every replan logged; human sign-off at the consensus gate |

The per-tier counts -- T2 at 3 attempts and 2 replans, say -- are illustrative
defaults, not fixed numbers to obey. Calibrate them to your own risk tolerance
and budget; what holds across tiers is the ordering (more attempts, replans, and
artifacts as stakes and unknowns rise), not the exact figures.

Two neutral illustrations. Renaming a local variable is T0 even in a large
service -- known location, no reach, reversible. A one-line change to a billing
rate is T3 -- the diff is trivial but the stakes force the full floor.

## The floor rule

Stakes set the floor; complexity only sets breadth. Any one of these in scope
forces the T3 verification floor no matter how small the change looks: a public
API, a data migration, a destructive or deleting command, auth / security /
secrets, money or billing, a release or tag, or a cross-component and
exactly-once invariant. When you need to save energy, cut breadth -- fewer
parallel agents, fewer independent attempts, fewer artifacts. Never cut the
floor. Skipping the review on a high-stakes change to save tokens is the one
trade this skill exists to forbid.

## Remaining-budget guard

Track what you have spent against the tier's cap. When most of the budget is
gone and no correctness check has come back green, stop -- do not silently spend
past the cap. Escalate to the human with the specific blocker, or de-scope, and
mark the work blocked with the failing case. Never reclaim budget by lowering
the floor: a floor that will not fit the budget means the task is blocked or
re-scoped, not shipped weaker.

## Escalate and de-escalate mid-task

Re-classification is cheap; refusing to re-classify is the expensive error --
size is not a proxy for risk.

- **Escalate** when the first trace shows more moving parts than you judged, a
  "contained" edit turns out to touch shared state, a verification pass surfaces
  a contradiction, or you hit the retry cap with no green check. Move up a tier
  and add its depth -- an independent reviewer, a second attempt -- before
  continuing.
- **De-escalate** when the unknowns collapse: the ambiguity resolved, the blast
  radius proved contained. Stand down the extra agents and skip the redundant
  second attempt -- but never drop below the floor the stakes still demand.
  De-escalation frees breadth, not the floor.

## Ties into the rest of sutra

- The `standard` profile carries the one-line default; this skill is its depth.
- The "Scale cost to blast radius" idea in the dev-loop template is the same
  principle specialized to which CI depth to run. This skill generalizes it to
  total energy -- tokens, agents, passes, attempts, artifacts.
- Front-loading disambiguation is the T2+ precondition: spend the clarifying
  tokens before building, because building the wrong thing at high energy is the
  expensive mistake.
- `agent-orchestration` decides how to prompt a delegate; this skill decides
  whether and how much to delegate. `parallel-agent-orchestration` and the
  `/sutra-harness:build-orchestrator` workflow are the T3 fan-out machinery, and
  `multi-session-build` is the T3 gate set.
