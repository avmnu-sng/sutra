---
description: Use when optimizing runtime performance -- establish a baseline, profile the actual hot path, validate the win on a macro scenario, and lock it in with a regression guard.
---

# Performance profiling

Optimize by measurement, not by theory. This is the empirical loop -- the
runtime counterpart to the design-time load modeling in
`/sutra:architecture-review`. That skill reasons about how a system *should*
behave under 2x/5x/10x load; this one measures how it *actually* behaves right
now and closes the gap. Every step here produces a number. An optimization
without a before-number and an after-number is a guess wearing a diff.

**Core principle:** the bottleneck is almost never where intuition says it is.
Programmers are systematically wrong about where their code spends time --
memory allocation, serialization, a chatty inner loop, and lock contention hide
in places no one suspects. Measure first, and let the measurement, not the
hunch, pick the target.

## When to use

- A workload is too slow and you need to make it faster.
- A latency or throughput regression appeared and you need to find and fix it.
- You are asked to cut cost driven by compute time (CPU-seconds, wall-clock).
- You want to add a performance guard so an existing win cannot silently erode.

## When not to use

- Correctness or logic bugs -- fix behavior first; a fast wrong answer is still
  wrong.
- Design-time capacity questions with no code to run yet -- use
  `/sutra:architecture-review` to model load before there is anything to profile.
- Speculative tuning of code no measurement has flagged as hot (see the
  anti-patterns).

---

## 1. Baseline first -- get a before-number

You cannot claim an improvement without a number to improve on. Before touching
any code, establish a reproducible measurement.

- Pick a representative workload and pin it: same input size, same data, same
  concurrency, same warm/cold state on every run. A moving workload makes every
  later comparison meaningless.
- Run it several times and record the distribution, not a single sample --
  report a stable statistic (median, or p95 for tail-sensitive work), plus the
  spread. One run is noise.
- Control the environment: same machine, quiesced background load, warmed
  caches if the real path is warm. Note anything you could not control.
- Write the baseline down (number, units, workload description, date/commit) so
  the after-number compares against a fixed reference, not a memory.

Checklist:

- [ ] Workload pinned and described precisely enough to reproduce.
- [ ] Multiple runs; reported statistic plus spread, not a lone sample.
- [ ] Baseline recorded against a specific commit.

## 2. Profile to find the ACTUAL hot path

Do not optimize from a hunch. Attach a profiler (sampling or instrumenting) or
add targeted timing, run the pinned workload, and rank where the time goes.

- Rank costs by total time attributable to each region -- a function called a
  million times at 2 microseconds each outweighs one called twice at 200 ms.
- Distinguish self time from cumulative time so you attribute cost to the real
  culprit, not its caller.
- Watch for costs that hide from a naive CPU profile: I/O waits, lock
  contention, garbage-collection pauses, and memory allocation. If CPU time
  does not explain the wall-clock, the cost is in waiting -- profile for that.
- Produce a ranked list: region -> share of total. That list, not intuition,
  names the target for step 4.

## 3. Separate macro signal from micro signal

A microbenchmark measures one function in isolation; a macro scenario measures
the real end-to-end path. They routinely disagree, and the macro one is the
truth.

- A microbench win often shrinks or vanishes end to end: the function was a
  small slice, or the surrounding I/O and allocation dominate, or a warm micro
  loop hides cold-start and cache effects the real path pays.
- Always validate an optimization on a realistic macro scenario -- the same
  pinned workload from step 1 -- not just the isolated function.
- Report the macro delta as the headline result. A microbench number can be
  supporting evidence, but never the claim. "The parser got 8x faster" is
  worthless if parsing is 3% of the request and the request moved 0.2%.

## 4. Optimize the dominant cost first

Attack the biggest slice from the step-2 ranking; ignore the rest until it
dominates. Amdahl's law bounds the payoff before you write a line:

- The most a change can buy is the fraction of total time it touches. Speeding
  up 5% of runtime by 2x saves ~2.5% overall, no matter how clever the change.
  Speeding up a 60% slice by 2x saves ~30%.
- Compute that ceiling from the baseline before committing to an optimization.
  If the ceiling is not worth the effort and risk, do not start -- pick a bigger
  slice or stop.
- Prefer the change that lowers the dominant cost's *complexity or volume*
  (fewer calls, less allocation, a better algorithm, a cache that removes work)
  over micro-tuning a hot line -- algorithmic wins compound; constant-factor
  wins plateau.
- After the dominant cost falls, the next-largest slice becomes the new
  dominant cost. Re-profile before choosing the next target.

## 5. Re-measure -- win real, correctness intact

Re-run the pinned baseline workload and confirm two things independently:

- **The win is real.** Same workload, same statistic, same environment as step
  1. Compare distributions, not best-case cherry-picks. If the improvement is
  inside the run-to-run spread, it is not a win -- it is noise.
- **Correctness did not regress.** Re-run the full test suite against the
  optimized code. A fast wrong answer is worse than a slow right one: it ships
  silently and corrupts downstream. Optimizations that trade accuracy for speed
  (caching, approximation, reordering) are the most dangerous -- test them
  hardest.

If the delta is smaller than step 4's projected ceiling, understand why before
claiming the win -- a mismatch usually means the profile was misread.

## 6. Ratchet -- lock the win in with a budget

A win with no guard erodes: the next refactor, dependency bump, or feature
quietly gives it back and no one notices until the regression is months old.

- Encode the achieved number as a performance budget -- an automated assertion
  (benchmark threshold, timing gate, allocation ceiling) that fails when the
  metric crosses the line.
- Treat a budget breach exactly like a failing test: it blocks merge until
  explained or re-baselined. See `/sutra:test-authoring` for wiring the guard as
  a real, fail-first assertion rather than a decorative check.
- Set the threshold with headroom for measurement noise (a small margin above
  the observed statistic) so the gate flags true regressions, not jitter. A gate
  that cries wolf gets ignored; calibrate it against the step-1 spread.
- When you legitimately move the budget (hardware change, intended trade-off),
  re-baseline deliberately and record why -- never loosen a budget just to make
  a red gate green.

---

## Anti-patterns

- **Optimizing with no baseline.** Without a before-number every claim is
  unfalsifiable. "It feels faster" is not a result.
- **Trusting a microbench that does not move the macro.** A 10x win on 2% of the
  workload is a rounding error the user never feels. Report the end-to-end delta.
- **Premature optimization of cold paths.** Complicating rarely-run code for a
  speedup no workload exercises adds risk and bugs for no measurable gain.
  Optimize what the profiler ranks, not what looks slow.
- **Shipping a speedup with no regression guard.** An unratcheted win is a
  temporary one; assume it will silently erode without a budget defending it.
- **Weakening the guard to pass.** Raising a budget threshold to clear a red
  gate hides the regression the gate exists to catch (mirror of the
  never-weaken-a-test rule in `/sutra:test-authoring`).

## Checklist

- [ ] Baseline captured on a pinned, reproducible workload before any change,
      recorded against a commit with a statistic plus spread.
- [ ] Profiled the real workload and produced a ranked cost list; target chosen
      from the ranking, not from intuition.
- [ ] Every optimization validated on a macro scenario; the reported delta is
      the end-to-end one, not the microbench.
- [ ] Dominant cost attacked first; Amdahl ceiling computed before committing.
- [ ] Re-measured against the baseline AND full correctness suite re-run green.
- [ ] Win locked in with a performance budget that fails like a test on breach,
      calibrated for noise; budget moves are deliberate and documented.
