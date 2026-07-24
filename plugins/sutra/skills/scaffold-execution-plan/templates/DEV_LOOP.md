# Dev loop

> Template. Fill in the placeholders (`<...>`) and delete the TODO markers
> for your project. Keep it short -- one screen. This is the contract for
> how the team gets fast, trustworthy feedback while building.

## The inner loop

One canonical command. Run it after every meaningful edit.

```
<task check>
```

Prefer the project task runner (`<task check>`, `make check`, `just check`,
`npm run check`, ...) over a raw invocation so the right env, flags, and
guards are baked in and every contributor runs the identical thing.

It runs, in order:

- **Lint** -- `<lint-command>`
- **Fast unit tests** -- `<unit-test-command>` (the subset that runs cold in
  under a second; no network, no containers, no full boot)
- **Smoke check** -- `<smoke-command>` (one end-to-end signal that the build
  is not obviously broken)

### Hard target: a few seconds

The inner loop MUST stay under `<N>s` (target: a few seconds). This budget is
a feature, not an aspiration -- it is what makes running the loop reflexive.

- A regression that pushes the inner loop over budget is the
  **highest-priority fix**, ahead of feature work.
- Keep the loop narrow on purpose. Anything slow (full integration, security
  scans, coverage, mutation) belongs in the pre-merge gate, not here.
- If a check cannot be made fast, move it out of the inner loop rather than
  letting the whole loop slow down.

<!-- TODO: set <N> to your real budget and wire `<task check>` to fail loud
     if it exceeds it. -->

## The pre-merge gate

The inner loop is necessary but not sufficient. Before merging, run the full
gate -- everything CI runs, locally, so red is caught before the PR:

```
<task ci>
```

On top of the inner loop, the gate adds:

- **Full test suite** -- `<full-test-command>` (all units, slow tests,
  property/fuzz)
- **Integration / end-to-end** -- `<integration-command>` (real dependencies,
  subprocess or container boot, cross-component paths)
- **Security** -- `<security-command>` (dependency audit, vulnerability scan,
  secret scan)
- **Coverage / quality gates** -- `<coverage-command>` (TODO: state the
  threshold, e.g. `>= <X>%` patch coverage)

<!-- TODO: list every task the per-PR CI runs so local == CI. A gap here is
     where "passes locally, fails in CI" comes from. -->

## Scale cost to blast radius

Match the depth of checking to how far a change can reach. Do not pay full-CI
cost for a typo fix; do not merge a core-path change on the inner loop alone.

| Change blast radius        | Run before merge                          |
| -------------------------- | ----------------------------------------- |
| Docs / comments only       | `<task check>` (lint may be enough)       |
| Localized, single module   | `<task check>` + targeted `<full-test-command>` |
| Shared / core code path    | Full `<task ci>`                          |
| Public API / release       | Full `<task ci>` + `<extra-gate-command>` |

<!-- TODO: adjust rows to your architecture. The principle is fixed: broader
     reach -> broader verification. -->

## Notes

- Keep this file and the CI config in sync. If CI adds a step, add it here.
- Last reviewed: `<YYYY-MM-DD>`.
