---
description: Use when writing, strengthening, or debugging tests -- enforces read-before-assert discipline, real assertions, and never weakening a failing test to go green.
---

# Test authoring

Write tests that catch regressions, not tests that report false safety. A test
earns its place only if a real defect would make it fail. Follow the steps
below in order; skipping step 1 is the number-one cause of integration-test
churn.

## 1. Read the source of truth before asserting anything

Never guess the name, type, or shape of a value you assert on. Open the
artifact that actually produces it and read it:

- The schema or type definition for a structured payload.
- The handler, controller, or function that builds the response.
- The serializer or formatter that renders the wire/output form.
- The database write (column names, nullability, defaults) behind a persisted
  value.

Guessing field names and shapes is the dominant integration-test failure mode.
Before writing assertions, build a short mapping and keep it next to the test:

```
output surface            -> source artifact
------------------------------------------------------------
response.user.display_name -> serializers/user.*  (field: display_name)
row.status                 -> schema migration    (enum: pending|done)
event.emitted_at           -> handler build step  (unix millis, not ISO)
```

If you cannot find the source artifact, stop and find it. Do not assert against
a value you have only inferred from a variable name.

## 2. Enumerate the case list before writing tests

For a substantial new suite, enumerate the cases (input -> expected) from the
source of truth and confirm them before writing bodies -- especially where a
wrong expectation is expensive. For routine additions, enumerate but don't
block. Enumerate every case as an explicit input -> expected pair -- happy
path, boundaries, and known failure modes -- derived from the source of truth
(step 1), not from whatever the code currently emits.

- One row per case: input/precondition -> expected outcome.
- Include the cases you deliberately leave out, and why, so a reviewer can
  catch a missing branch before any code exists.
- If review changes a case, update the list first; do not silently drift the
  expected values to match the implementation.

```
case                        input                -> expected
------------------------------------------------------------------------
new order starts pending    POST /orders {sku}   -> status pending, 1 row
duplicate sku rejected      POST twice, same sku -> 409, still 1 row
missing sku                 POST /orders {}      -> 422, 0 rows
```

Writing tests first and discovering the case list was wrong wastes the most
expensive work -- the assertions -- and biases every expected value toward the
code as it happens to behave today.

## 3. Author in phased gates: skeleton -> fail-first -> green

Build a new suite in ordered phases and do not advance until the current gate
passes:

1. **Compile-only skeleton** -- test names with empty or pending bodies that
   build (compile, import, resolve) and no assertions yet. Gate: the suite
   compiles and every new test is discoverable by the runner.
2. **Fail-first** -- fill in assertions so every new test runs and FAILS
   against the unimplemented or unfixed code. Gate: each new test is red for
   the expected-vs-actual gap you predicted, not an unrelated setup or import
   error.
3. **Green** -- implement or fix the code until the new tests pass without
   touching the tests to force it. Gate: the whole new suite is green and the
   rest of the suite still passes.

A test that has never been observed to fail proves nothing. The fail-first gate
is what certifies the assertion can actually catch the defect.

## 4. Every test must assert something real

A test whose body sets up state but never checks an outcome is worse than no
test: it advertises coverage that does not exist.

- Each test contains at least one assertion that would fail if the behavior
  under test broke.
- Assert on the specific value or contract, not merely that a call "did not
  throw" (unless not-throwing is the actual contract).
- Prefer explicit want/got failure messages so a red test reads clearly without
  a debugger:

```
assert equal
  want: "pending"
  got:  <actual status>
  context: newly created order should start pending
```

- After writing an assertion, mentally mutate the code under test and confirm
  the assertion would catch the mutation. If nothing breaks it, the assertion
  is decorative -- strengthen it.

## 5. Prove "untestable" before you claim it

"This path cannot be reached from the test harness" is a claim that needs
proof, not a default excuse. Before declaring a path untestable:

1. List every primitive/helper the harness gives you.
2. List every parameter of every primitive.
3. Show that no single variation and no composition of variations reaches the
   path.

Composition of primitives usually reaches paths a single primitive cannot
(e.g. sequencing two operations, or feeding one primitive's output into
another). Only after enumerating and ruling out compositions may you record a
path as genuinely unreachable -- and record why.

## 6. Never weaken a failing test to go green

When a test fails, the test is doing its job. Diagnose the real cause.

Do NOT, to make the bar green:

- Loosen an assertion (exact match -> "contains", specific value -> "truthy").
- Narrow the input so the broken branch is no longer exercised.
- Skip, comment out, or delete the failing assertion.
- Widen an accepted-values set to include the wrong value.

A loosened assertion hides the exact defect it was built to catch. Instead:

- Fix the code if the code is wrong.
- Fix the test only if the expected value in the test was itself wrong -- and
  re-derive that value from the source of truth (step 1), not from the current
  (possibly buggy) output.
- If you cannot resolve it now, mark the work BLOCKED and name the specific
  failing case (inputs, expected, actual). A blocked-with-evidence note is
  honest; a green suite hiding a known defect is not.

## 7. Use golden/snapshot files for large structured output

For outputs too large to assert field-by-field (rendered documents, large JSON
trees, generated code):

- Store an expected "golden" file and compare the produced output against it.
- Keep goldens minimal and human-readable -- trim irrelevant noise so a diff is
  meaningful. Normalize volatile fields (timestamps, ids, ordering) before
  comparison.
- Mask nondeterministic fields (timestamps, ids, hostnames, ordering) at a
  SINGLE point in the pipeline -- one normalization pass applied to every golden
  and every fresh output -- not ad hoc per test. A single mask point keeps the
  producer and the comparison in sync; scattered masking drifts and lets
  volatile data leak into diffs.
- Regenerate goldens with the tool that produces them; never hand-edit a golden.
  Hand-editing bakes in a value no producer emits, so the test can pass on
  output no real run generates.
- Review every golden change as deliberately as source code. An auto-regenerated
  golden that no one read is a rubber stamp, not a test. Regenerate only after
  confirming the new output is correct.

## 8. Test behavior and contracts, not implementation

Assert on the observable contract -- inputs to outputs, side effects a caller
depends on -- not on internal structure that a refactor may legitimately change.

- Good: "given X, the API returns status pending and persists one row."
- Fragile: "the service calls helper A then helper B in that order" (unless
  ordering is the contract).

Behavior-focused tests survive refactors; implementation-coupled tests churn on
every internal rename and train the team to ignore red.

## When to use

- Adding tests for new behavior or a bug fix (write the failing test first).
- Strengthening weak or assertion-free tests.
- Debugging a failing test to decide whether the code or the expectation is
  wrong.
- Adding golden/snapshot coverage for large structured output.

## When not to use

- Throwaway exploratory scripts that will not live in the suite.
- Pure formatting/lint changes with no behavioral surface to assert on.

## Checklist

- [ ] Read the source of truth (schema/handler/serializer/DB) for every value
      asserted; recorded an output-surface -> source-artifact mapping.
- [ ] For a substantial new suite, the case list (input -> expected) was
      enumerated (and confirmed where a wrong expectation is expensive) before
      any test body was written.
- [ ] New tests were observed to FAIL first (skeleton compiled, then red for the
      predicted reason) before the code was made green.
- [ ] Every test has at least one assertion that fails if the behavior breaks.
- [ ] Failure messages state want vs got with enough context to diagnose.
- [ ] Any "untestable" claim is backed by enumerating primitives, their
      parameters, and their compositions.
- [ ] No failing assertion was weakened, skipped, narrowed, or deleted to go
      green; unresolved failures are marked BLOCKED with the specific case.
- [ ] Goldens are minimal, volatile fields masked at a single pipeline point,
      tool-generated (never hand-edited), and every change was reviewed.
- [ ] Assertions target behavior/contracts, not internal call structure.

Note: assertion helpers, snapshot tooling, and runners vary by stack. The
discipline above is language-agnostic; map each rule onto your framework's
idioms.
