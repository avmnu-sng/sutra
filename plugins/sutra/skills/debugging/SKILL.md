---
description: Use when isolating a defect or root-causing a failure -- contain a live incident first, then reproduce, instrument, form one falsifiable hypothesis at a time, bisect, and prove the mechanism before calling it fixed.
---

# Debugging

Find the defect by evidence, not by intuition. A bug is a gap between what the
code does and what you believe it does; debugging is the disciplined closing of
that gap. Trace before you theorize -- read the actual behavior first, and let
every step be driven by an observation you can point at, never by a hunch about
which layer "feels wrong."

Work the steps in order. The order is load-bearing: reproduce before you change
anything, localize before you explain the mechanism, and prove causation before
you declare victory.

## When to use / When not to

- **Use** when a test is red for an unknown reason, a system is misbehaving in
  production, output is wrong, something is intermittent, or a change broke
  something and you do not yet know what.
- **Do not use** for known, mechanical fixes (a typo, a clear null check a
  reviewer already pointed at) where there is no isolation work to do. This is
  for defects whose cause is not yet established.

---

## 0. If it is on fire, stop the bleeding first

A live production incident is not a debugging session. A running system serving
users is not a debugger -- you cannot single-step it, and every minute spent
root-causing is a minute of user-facing damage. Contain first, investigate
after.

**Contain.** Reach for the fastest reversible lever that stops the harm:

- Roll back to the last known-good release.
- Flip the feature flag off for the broken path.
- Divert or shed traffic (drain the bad instance, fail over, rate-limit).
- Disable the offending job, consumer, or integration.

Pick the lever with the smallest blast radius that actually stops the bleeding.
Rollback is usually safest because it is reversible and well-understood; a
forward "quick fix" pushed under pressure is itself an unreviewed change.

**Preserve evidence before you wipe state.** Capture logs, a stack trace, the
current config, and a snapshot of the bad state *before* the rollback erases it.
You still have to root-cause afterward, and the incident is your best
reproduction.

**Investigate only once contained.** With the bleeding stopped, drop into the
core loop below on a copy of the captured state -- not on the live system.

**Follow up blamelessly.** The fix is not done until the class of failure
cannot recur silently: a regression test (step 6), an alert that would have
caught it sooner, and a short write-up of the causal chain. Blame the missing
guardrail, not the person who tripped it.

---

## The core loop

Once nothing is actively burning, root-cause with a hypothesis-driven loop. The
enemy is flailing -- changing things and re-running to see if the symptom moved.
Each step below replaces a guess with a measurement.

## 1. Reproduce it reliably and minimally

A bug you cannot reproduce, you cannot confirm fixed. Before touching any code,
get a reproduction you can run on demand.

- Nail down the exact trigger: inputs, environment, config, starting state, and
  timing. Write it down as a concrete recipe someone else could follow.
- Shrink it. Strip away everything that is not required to make the bug appear --
  a smaller repro localizes the fault before you have theorized about it.
- For an intermittent bug, find the variable that flips it: concurrency,
  ordering, a clock, a cache, a specific data value. "Intermittent" usually
  means "deterministic in a variable you have not identified yet."

If you truly cannot reproduce it, do not proceed to guess a fix. Add
instrumentation (step 2) to the live path and wait for the next occurrence with
enough captured state to reproduce it offline.

## 2. Observe -- read the truth, do not guess it

Look at what actually happened before forming any theory.

- Read the real error message and the full stack trace, top to bottom. The
  answer is often already printed and skipped over.
- Read the logs and the actual state -- variable values, DB rows, queue depths,
  the request/response on the wire -- at the moment of failure.
- Where the truth is missing, add targeted instrumentation: a log line, an
  assertion, a breakpoint, a dump of the suspect value at the suspect point. Do
  not guess a value you can print.

Rule: do not theorize about a value you have not observed. If a claim in your
head ("the list is empty here") is checkable, check it before building on it.

## 3. Form ONE falsifiable hypothesis at a time

State a single, specific, disprovable claim -- not a vague suspicion.

- Good: "`session.user` is null on the retry path because the auth token is
  cleared before the retry runs."
- Too vague to test: "something is wrong with sessions."

Then design the *cheapest* experiment that would **disprove** it, and run only
that. Change one variable per test. If the experiment does not move the
symptom the way your hypothesis predicts, the hypothesis is dead -- discard it
and form the next one. Chasing two theories at once means you cannot tell which
change mattered.

Keep a short running log of hypotheses tried and ruled out. It stops you
re-testing the same dead theory and shows the shape of the remaining fault
space.

## 4. Bisect to localize the fault

Narrow *where* the bug lives before explaining *why* it happens. Halve the
search space repeatedly instead of reading everything.

- **Across time:** `git bisect` between a known-good and known-bad commit to
  land on the exact change that introduced the defect.
- **Across input:** binary-search the failing input -- delete half, re-test,
  keep the half that still fails.
- **Across the pipeline:** disable or short-circuit half the stages and see
  which half carries the bug. Add a checkpoint at the midpoint and ask "is the
  data still correct here?"

Each halving is one measurement that eliminates half the candidates. Localize
to the smallest region that still reproduces before you reason about mechanism.

## 5. Confirm the mechanism -- prove causation, not correlation

A symptom that stopped is not a root cause found. Before you accept the fix,
explain *why the bug happened* and *why the fix works*, then prove it:

1. Reproduce the failure (step 1 recipe) -- watch it fail.
2. Apply the fix -- watch it pass.
3. Revert only the fix -- watch it fail again.
4. Re-apply the fix -- watch it pass again.

Toggling the fix on and off while everything else is held constant is what
distinguishes "my change caused the pass" from "the pass happened to coincide
with my change." If you cannot articulate the causal chain from root cause to
symptom in one or two sentences, you have not found the root cause -- you have
found a coincidence that quiets the symptom. Keep going.

Beware the fix that changes timing (a log line, a sleep, a reorder) and makes an
intermittent bug "go away." That is masking, not fixing -- the race is still
there.

## 6. Guard against regression

Close the hole so this defect cannot return unnoticed.

- Add a test that **fails on the old code and passes on the new** -- the
  fail-first discipline from the test-authoring skill. A regression test never
  observed to fail proves nothing.
- Fix the class, not just the instance, when it is cheap: if the null came from
  one unchecked path, check whether sibling paths have the same gap. Search for
  the pattern, not only the one line.
- Confirm the broader surface is actually clean rather than assuming it -- use
  the verify-completeness discipline to check that no adjacent case is still
  quietly broken.

---

## Anti-patterns -- name them and stop

- **Shotgun edits.** Changing several things at once and re-running. When it
  goes green you cannot tell which change fixed it -- or whether you introduced
  a second bug that masks the first. One variable per test (step 3).
- **Trusting a fix you never saw fail.** If you did not watch the reproduction
  fail before the fix and pass after, you have not confirmed anything. Correlation
  dressed as a fix (step 5).
- **"It works now" with no repro.** Declaring victory because the symptom did
  not appear on the last run. Absence of the symptom is not proof of the fix,
  especially for anything intermittent (step 1).
- **Blaming the layer you understand least.** Pinning the bug on the framework,
  the network, the database, or "flakiness" without evidence, because it is the
  part you can least easily read. Trace into it before you accuse it (step 2).
- **Debugging by rewrite.** Replacing the confusing code wholesale instead of
  understanding it. The bug often survives the rewrite, now hidden in new code.

---

## Checklist

- [ ] If live, contained the incident with a reversible lever and preserved
      evidence *before* root-causing.
- [ ] Have a reliable, minimal reproduction with an exact trigger recipe.
- [ ] Read the actual error, stack trace, logs, and state; added instrumentation
      where the truth was missing instead of guessing.
- [ ] Working one falsifiable hypothesis at a time, changing one variable per
      test, logging what was ruled out.
- [ ] Localized the fault by bisecting (commits / input / pipeline) before
      theorizing about mechanism.
- [ ] Proved causation: failed, fixed, reverted-and-failed-again; can state the
      causal chain in one or two sentences.
- [ ] Added a regression test that fails on the old code and passes on the new;
      fixed the class where cheap.
