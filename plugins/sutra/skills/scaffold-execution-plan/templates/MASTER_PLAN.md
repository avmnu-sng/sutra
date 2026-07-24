# Master plan

<!-- TEMPLATE: fill this in for your own project. Replace every <placeholder>
     and TODO. Delete guidance comments once the section is real. -->

## Mission

<!-- One paragraph. Describe what "done" looks like in observable terms:
     what a user can do, what the system guarantees, and how you would
     demo it. No implementation detail -- outcomes only. If two people
     read this and picture different finished products, it is not tight
     enough yet. -->

TODO: In one paragraph, state the end state. Example shape: "When this
build is done, <who> can <do what> against <what surface>, and the
system guarantees <property>. Success is demonstrable by <observable
check>."

## Non-goals

<!-- Explicit out-of-scope items. This section keeps scope bounded and
     kills 'while we're in here' creep. Every entry is something a
     reasonable person might expect us to build but we are deliberately
     not building in this plan. -->

- TODO: <thing we are NOT building> -- reason it is out of scope.
- TODO: <adjacent surface we are NOT touching> -- reason.
- TODO: <tempting extension we are declining> -- reason.

## Frozen contracts

<!-- Interfaces, schemas, and boundaries fixed in the foundation slice.
     Later slices consume these but MUST NOT change them. A change here
     is a plan-level event: it invalidates downstream slices and needs
     an explicit re-plan, not a quiet edit. Keep each contract small and
     precise enough to code against. -->

Frozen as of the foundation slice (<slice-id>). Do not edit in later
slices without re-planning.

| Contract | Owner slice | Shape / location | Change policy |
| --- | --- | --- | --- |
| <contract-name> | <slice-id> | `<path-or-signature>` | Frozen -- re-plan to change |
| <contract-name> | <slice-id> | `<path-or-signature>` | Frozen -- re-plan to change |

TODO: For each frozen contract, link the authoritative definition
(schema file, interface, endpoint spec) so there is one source of truth.

## Do not regress

<!-- Invariants the build must never break. This section is fed by the Step 0
     adversarial pressure-test: every confirmed delta becomes a bullet here,
     each owned by the slice responsible for preserving it. Treat this list as
     authoritative on conflict -- a later slice does not get to relax an entry
     without an explicit, recorded decision. -->

- TODO: <invariant the pressure-test surfaced> -- owned by `<slice-id>`.
- TODO: <invariant the pressure-test surfaced> -- owned by `<slice-id>`.

<!-- If the pressure-test found nothing to protect, say so and date it, rather
     than leaving this empty. -->

## Value-ranked slices

<!-- Vertical slices in priority order. Rank by value and de-risking:
     pull the hardest / highest-uncertainty work early so surprises land
     when there is still time to react. Each slice must be independently
     demoable end-to-end (a thin cut through all layers), not a
     horizontal layer. Dependencies form a DAG -- no cycles. -->

Ordering rule: hardest-risk first, then descending value. Every slice
ships something demoable on its own.

| ID | Title | One-line value | Depends on |
| --- | --- | --- | --- |
| <slice-id> | <short title> | <what a user/stakeholder gains> | -- |
| <slice-id> | <short title> | <what a user/stakeholder gains> | <slice-id> |
| <slice-id> | <short title> | <what a user/stakeholder gains> | <slice-id>, <slice-id> |

TODO: Confirm the "Depends on" column is acyclic. If slice A depends on
B and B depends on A, split one of them.

Demo check per slice:

- <slice-id>: demoable by running `<command>` and observing <result>.
- <slice-id>: demoable by running `<command>` and observing <result>.

## Milestones

<!-- Milestones group the value-ranked slices into shippable checkpoints.
     Each milestone bundles one or more slices that together cross a
     meaningful line (first end-to-end demo, feature-complete, hardened).
     A milestone is done only when every slice it groups is done. Keep
     the grouping aligned with the slice DAG -- a milestone must not
     depend on a slice scheduled in a later milestone. -->

Each milestone records an id, a one-line goal, and a status. Group the
value-ranked slices above so every slice belongs to exactly one
milestone.

Status legend:

- `PLANNED` -- scoped; no slice in this milestone started.
- `IN-PROGRESS` -- at least one grouped slice is underway.
- `DONE` -- every grouped slice is done and demoable.

| ID | Goal | Status | Slices |
| --- | --- | --- | --- |
| <milestone-id> | <what shipping this milestone unlocks> | PLANNED | <slice-id>, <slice-id> |
| <milestone-id> | <what shipping this milestone unlocks> | PLANNED | <slice-id> |
| <milestone-id> | <what shipping this milestone unlocks> | PLANNED | <slice-id>, <slice-id> |

TODO: Confirm every value-ranked slice appears in exactly one milestone
and that no milestone depends on a slice grouped into a later one.

- TODO: Each milestone rolls up into exactly one release milestone.

## Release milestones

<!-- Release milestones map completed dev milestones onto shippable
     versions. A dev milestone crosses an internal line (first demo,
     feature-complete, hardened); a release milestone is a public artifact
     carrying a version tag. One or more milestones roll up into each
     release. Every milestone belongs to exactly one release milestone. -->

Versioning follows semver -- MAJOR.MINOR.PATCH -- keyed to the frozen
contracts:

- MAJOR -- a frozen-contract change. Any break of a `## Frozen contracts`
  entry is a MAJOR bump; there is no smaller bump for it.
- MINOR -- new capability that leaves every frozen contract intact.
- PATCH -- fixes and hardening only; no contract or capability change.

Pre-release ladder (walk it in order before the stable tag):

    vX.Y.Z-alpha.N -> vX.Y.Z-beta.N -> vX.Y.Z-rc.N -> vX.Y.Z

- `vX.Y.Z-alpha.N` -- feature-incomplete; internal preview.
- `vX.Y.Z-beta.N` -- feature-complete for the release; stabilizing.
- `vX.Y.Z-rc.N` -- release candidate; ship-or-fix only, no new scope.
- `vX.Y.Z` -- stable tag.

Milestone -> version rollup:

| Release | Version / tag | Milestones included | Status |
| --- | --- | --- | --- |
| <release-name> | <vX.Y.Z or pre-release tag> | <milestone-id>, <milestone-id> | PLANNED |
| <release-name> | <vX.Y.Z or pre-release tag> | <milestone-id> | STAGING |
| <release-name> | <vX.Y.Z or pre-release tag> | <milestone-id>, <milestone-id> | SHIPPED |

Status legend:

- `PLANNED` -- release scoped; no included milestone shipped yet.
- `STAGING` -- included milestones landing; release-cut checklist in progress.
- `SHIPPED` -- tagged and published.

Release-cut criteria (every box must hold on the exact release SHA before
tagging):

- [ ] Every included milestone is `DONE`.
- [ ] Fast feedback + pre-merge gate green on the exact release SHA.
- [ ] Zero `BLOCKED` slices.
- [ ] Zero unburned deferrals owed to this release (`## Defer surface` reconciled).
- [ ] Zero load-bearing claims still `BUILT-UNTESTED` (`## Anti-overclaim ledger`).
- [ ] CHANGELOG `[Unreleased]` section renamed to the version.
- [ ] Docs current with shipped behavior.
- [ ] Independent completeness gate passed (reviewer other than the author signs off).

TODO: Name each release and its target tag, then confirm every milestone
above rolls up into exactly one release.

## Anti-overclaim ledger

<!-- Tag every load-bearing claim with its evidence level so nobody
     mistakes a design sketch for shipped, tested behavior. Update the
     tag when reality changes; a claim is only as strong as its current
     tag. -->

Legend:

- `BUILT+TESTED` -- implemented and covered by a test you can point to.
- `BUILT-UNTESTED` -- implemented but not yet verified by a test.
- `DESIGN-ONLY` -- planned or specified; no code yet.

| Claim | Tag | Evidence (test / file / run) |
| --- | --- | --- |
| <load-bearing claim> | DESIGN-ONLY | TODO: <where the proof will live> |
| <load-bearing claim> | BUILT-UNTESTED | `<path-or-run>` |
| <load-bearing claim> | BUILT+TESTED | `<test-id-or-path>` |

Rule: no slice is "done" while any of its load-bearing claims sit below
`BUILT+TESTED` without an explicit, recorded exception.

## Defer surface

<!-- Work intentionally declined for this plan. An empty list is itself
     a claim: it asserts you looked and found nothing worth deferring.
     Fill it honestly. Each entry names the work, why it is deferred,
     and the trigger that would pull it back in. -->

- TODO: <deferred work> -- deferred because <reason>; revisit when
  <trigger / condition>.
- TODO: <deferred work> -- deferred because <reason>; revisit when
  <trigger / condition>.

<!-- If nothing is deferred, replace the list with: "None. Reviewed on
     <YYYY-MM-DD>; no work intentionally declined." -->

---

Last reviewed: <YYYY-MM-DD> by <owner>.
