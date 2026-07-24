---
description: Use when auditing an existing codebase and sequencing fixes -- produce a structured audit doc, prioritize findings across three lenses, and split remediation work so humans and agents can proceed in parallel; not for greenfield planning.
---

# Audit and remediation

Audit code that already exists and turn findings into a sequenced, owned
remediation plan. This is distinct from greenfield planning: you are not
designing a system from scratch (the execution-plan templates cover that),
you are assessing what is there, ranking what is wrong, and deciding who
fixes what, in what order, gated by explicit exit criteria.

Use this skill when asked to review a codebase for health, tech debt, or
risk; to triage a backlog of known defects; or to produce a remediation
roadmap someone can execute against.

## 1. Produce the audit doc

An audit is documentation, not a single wall of text. Produce an audit doc
-- split it into multiple files when the audit is large, so each part can
be updated independently as remediation proceeds -- covering three things:

1. **Scope + method.** What was and was not examined, the HEAD SHA the
   audit was run against, and the audit date; plus how the audit was
   conducted so it is reproducible (paths/layers/subsystems inspected,
   tools/commands run, what was explicitly out of scope, and the severity
   rubric used). A finding is only as trustworthy as the method that
   produced it. A one-paragraph executive summary up top helps a reader
   orient.
2. **Findings ranked across the three lenses.** The findings themselves,
   each with a stable ID, a location (path + anchor), evidence, and its
   three-lens ranking (Step 2). Group by subsystem or theme to keep a long
   list navigable. Where it helps, capture the system as it actually is
   today -- components, boundaries, data flow, load-bearing invariants --
   and note where reality diverges from the intended design.
3. **A sequenced action list with exit criteria.** Findings converted into
   discrete, actionable items -- one item = one deliverable -- each carrying
   its three-lens priority, a cost/effort class and ownership (Step 3), and
   a work lane (Step 5), then sequenced into phases gated by written exit
   criteria (Step 6).

Keep IDs stable across the whole doc: a finding ID maps 1:1 to its
action-item ID so cross-references never rot. If you split into multiple
files, an INDEX that links them and states scope/SHA/date up front makes a
good entry point.

## 2. Prioritize with three lenses held separately

Rank every finding along three independent axes. Do not collapse them into
one number -- record all three, because they carry different information
and different owners care about different ones.

| Lens | Question it answers | Owned by |
| --- | --- | --- |
| Intrinsic severity | How bad is this in isolation? (data loss, security, correctness, crash, cosmetic) | Engineering judgment |
| Business priority | How much does fixing this matter to the goals right now? | Product/stakeholder |
| Today's ordering | Given dependencies and in-flight work, what makes sense to do next? | Whoever sequences the plan |

**When the lenses diverge, business priority wins.** A critical-severity
bug in a subsystem nobody uses yet can rank below a medium-severity bug on
the critical revenue path. That is correct, not a mistake.

**Record the divergence -- never silently override.** When today's
ordering or business priority demotes a high-severity item, write a one-
line justification next to the item ("Sev: high; Biz: low -- feature is
behind a disabled flag, revisit at launch"). The audit must show its
reasoning so a reader can challenge the call, not just the outcome.

## 3. Tag every item: cost/effort and ownership

Before an item goes on the action list, attach two classifiers:

- **Cost/effort class** -- a rough size so phase-bounding and lane
  assignment stay tractable. Any consistent scale works; one example is
  `trivial` (< 1 hr), `small` (< 1 day), `medium` (1-3 days), `large`
  (multi-day, needs design). Adapt the buckets and thresholds to your
  team's cadence -- what matters is that the scale is consistent across
  items, not the exact cutoffs.
- **Ownership class** -- who is responsible for the domain: which
  team/role/area owns the code. Distinct from the lane (Step 5), which is
  who *does the work*. Ownership survives even when an agent does the fix.

## 4. Remediation picking checklist

Run this every time you pick up an item -- do not batch these checks.

**BEFORE picking:**

- [ ] Re-verify the defect still exists at current HEAD. Code moves;
      audits go stale. Open the exact location and confirm the problem is
      live. If it is already fixed, mark the item resolved with the SHA
      that fixed it and move on -- do not "fix" a non-defect.
- [ ] Confirm the item is still the right next thing per the three lenses
      (priorities shift between audit time and pick time).

**DURING the fix:**

- [ ] Scope strictly to the item. Fix this defect and nothing else.
      Adjacent problems you notice become new action items, not
      opportunistic edits inside this change. Scope creep destroys the
      audit's traceability and inflates review surface.

**AFTER the fix:**

- [ ] Mark the item resolved with the fixing commit SHA. The SHA is the
      proof of closure and the anchor for later verification. "Done"
      without a SHA is not done.
- [ ] Update the INDEX/action-items status so the doc set reflects reality.

## 5. Split the work so humans and agents run in parallel

Sort action items by who does the work, so human and agent effort can
proceed without collision. One example split that works well uses three
lanes:

| Lane | For items that... | Executed by |
| --- | --- | --- |
| `critical-path-human` | block progress and need human judgment, design, or cross-team coordination | A human, prioritized first |
| `optional-human` | benefit from a human but are not blocking; can wait or be dropped | A human, when capacity allows |
| `agent-self-serve` | are well-scoped, low-ambiguity, and mechanically verifiable | An agent, autonomously |

Adapt the lanes to your setup -- the point is a clear who-does-the-work
split, not this exact taxonomy. Whatever scheme you use:

- **Give each item one clear lane.** Aim for no unassigned items and no
  item straddling two lanes. If you cannot decide, the item is usually
  under-specified -- split it or sharpen its scope until the lane is
  obvious.
- Route by ambiguity and blast radius, not just by effort. A trivial fix
  with subtle correctness risk belongs with a human; a large-but-
  mechanical refactor with strong test coverage can be agent-self-serve.
- The lane is orthogonal to the ownership class (Step 3): an agent can
  execute a fix in code a specific team owns. Record both.

## 6. Bound the work in phases with exit criteria

Group lane-assigned items into phases. Every phase is gated -- it does not
end when the items happen to be done; it ends when an explicit, written
condition is met.

Each phase declares:

1. **The items it contains** (by ID).
2. **A gate: a date OR a signal.** Either "complete by <date>" or
   "complete when <observable signal>" (e.g. "error rate on X below
   threshold for 48h", "all `critical-path-human` items in phase resolved
   with SHAs").
3. **A written EXIT CRITERION** -- the unambiguous, checkable statement of
   what "this phase is done" means. If you cannot mechanically check it,
   rewrite it until you can.

Recipe for a phase entry:

```
Phase 2 -- Stop the bleeding
  Items: AI-004, AI-007, AI-011
  Gate (signal): all three resolved with fixing SHAs AND
                 regression suite green on HEAD
  Exit criterion: no open item in this phase; each closed item has a
                  SHA recorded in the action-items list; CI green.
```

Sequence phases so earlier phases unblock later ones. Front-load
`critical-path-human` items whose absence stalls everything else; let
`agent-self-serve` items fill parallel capacity within the same phase.

## Quick checklist

- [ ] Audit doc produced (split into files if large): scope + method,
      findings ranked across the three lenses, sequenced action list with
      exit criteria.
- [ ] Audit records the HEAD SHA and date it was run against.
- [ ] Every finding rated on all three lenses, kept separate.
- [ ] Divergences recorded with a one-line justification; business
      priority wins.
- [ ] Every item tagged with cost/effort class and ownership class.
- [ ] Picking discipline applied: re-verify at HEAD, scope strictly,
      close with a SHA.
- [ ] Every item sorted into a clear work lane (e.g. critical-path-human /
      optional-human / agent-self-serve).
- [ ] Every phase gated by a date or signal with a written, checkable
      exit criterion.
