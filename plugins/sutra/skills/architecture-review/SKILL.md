---
description: Use when reviewing a backend or service architecture for scalability, resource fit, and cost -- trace requests, stress each component, model 2x/5x/10x load, and produce ROI-quantified recommendations.
---

# Architecture review

Review a backend or service architecture with this 7-point methodology, applied in order. Do not skip ahead: each step feeds the next. The goal is not a component inventory -- it is a judgment about how the system behaves under load, where it breaks, and what is worth changing.

**Scope:** This methodology assumes a horizontally-scaled network service. For a monolith, embedded, or desktop system, apply the request-trace and component-interaction analysis and skip the autoscaling-specific steps (pod budgets, HPA metrics, scale-to-zero).

**Core principle:** system behavior emerges from component *interactions*, not from individual component properties. A per-component analysis that misses shared limits, cascades, and contention is wrong by construction. Two components that each look healthy in isolation can deadlock, starve a shared pool, or amplify each other's retries. Analyze the seams, not just the boxes.

## When to use / When not to

- **Use** when asked to assess scalability, capacity, resource sizing, cost, or reliability of a service or set of services; before a scaling event; when latency or cost is climbing without an obvious cause; when choosing a deployment model.
- **Do not use** for line-level code review, security review, or feature design. This is a systems-behavior review, not a correctness or style pass.

---

## 1. Trace every request end to end

Pick one request type and follow it through every layer. Produce a *trace*, not a summary.

For each distinct request type, walk:

- Entry point (which handler, which route, what triggers it).
- Every downstream call (services, databases, caches, queues, external APIs).
- Every I/O operation (disk read/write, network round trip, serialization).
- Every decision branch (and which branch is the common case vs the tail).
- Every lock, mutex, semaphore, or shared pool it touches, and for how long it holds them.
- Every retry, timeout, and backoff, with the actual values.
- Every error path -- what is caught, what is retried, what propagates, what is silently swallowed.
- The final side effect (the write, the message published, the response returned).

Repeat for each distinct request type before doing any analysis. A read path and a write path can share a bottleneck that neither trace reveals alone. Reference code by symbol name (function, method, class), never by line number -- line numbers rot.

Checklist:

- [ ] One trace per distinct request type.
- [ ] Locks and shared pools named, with hold duration.
- [ ] Retry/timeout/backoff values recorded as configured, not assumed.
- [ ] Error and tail branches traced, not just the happy path.

## 2. Question each component under stress

For every component the traces touch, ask what it does when pushed:

- Which resource does it stress first -- CPU, memory, disk I/O, or network I/O? Name the dominant one.
- How does its failure cascade? If it slows or dies, what backs up behind it and what times out in front of it?
- Is routing to it correct and efficient, or does traffic take an extra hop, cross a zone boundary, or fan out wider than needed?
- What chokes first at scale -- connection count, a thread pool, a memory ceiling, a per-instance rate limit?

A component that is fine at current load can be the first domino at 3x. Write down the failure mode, not just the health status.

## 3. Check the infrastructure and orchestration complement

The code is half the system; the platform it runs on is the other half. Verify they match.

- Does the node/CPU profile match the workload? A memory-heavy service on CPU-optimized nodes wastes money and still OOMs.
- Are resource requests and limits set for the *actual* work? An I/O-bound service should not request heavy CPU -- it will sit idle holding a large reservation while starving neighbors.
- Is the autoscaling metric correct for the workload? CPU-based autoscaling on a wait-bound workload (blocked on network or a downstream API) never triggers -- the instances are busy waiting, not busy computing, so CPU stays low while latency explodes. Scale on the metric that actually moves under load (in-flight requests, queue depth, connection saturation).
- Do replica counts, pod disruption budgets, and connection-pool sizes agree with each other and with downstream capacity?

## 4. Test scale at 2x, 5x, and 10x

For each multiplier, answer three questions in order and show the arithmetic:

1. **What breaks first?** Name the specific limit (e.g. "the connection pool caps at 100; at 2x we need ~160").
2. **What unblocks it?** The minimal change that clears that first limit.
3. **What breaks next?** Once the first limit is gone, the load moves downstream -- find the new bottleneck.

Show the math every time. "It should scale fine" is not an answer; "at 5x, 5000 rps / 200 rps per instance = 25 instances, but the database allows 300 connections and each instance opens 20, so we hit the DB ceiling at 15 instances" is.

Rule of thumb: if the system cannot absorb 2-3x without a change, something is already wrong at current load -- you are running with no headroom.

## 5. Decompose elastic vs rate-limited work

Split the workload into two buckets:

- **Elastic** -- scales with instance count. Add instances, get proportional throughput.
- **Rate-limited** -- gated by an external ceiling (a third-party API quota, a database write throughput, a licensed connection cap). Adding instances does nothing once you hit the ceiling.

Then:

- If a rate-limited part dominates end-to-end time, splitting or scaling the elastic parts buys almost nothing. Fix or negotiate the ceiling, or redesign to need less of that resource.
- If two *different* rate-limited resources sit in the same process with separate ceilings, they belong in separate deployments -- otherwise one saturates and drags the other's headroom down with it, and you cannot scale or tune them independently.

Name each ceiling and its numeric limit. An unnamed rate limit is an unmanaged one.

## 6. Evaluate the deployment model

Assess whether the current runtime shape fits the workload, across these axes:

- **Duration:** long-running service vs short burst of work.
- **Concurrency model:** thread pool, event loop, process-per-request, actor -- and whether it matches the I/O vs CPU profile from step 2.
- **Cold-start tolerance:** does the traffic pattern permit scale-to-zero, or does a cold start blow the latency budget?
- **State:** stateless, session-affine, or stateful? State constrains every scaling and deployment option.
- **Resource profile:** the CPU/memory/I/O shape from steps 2-3.
- **Cost:** what the model costs at current and target load.
- **Operational complexity:** what it takes to run, observe, and debug in production.

Only after all seven axes are on the table should you compare alternatives (long-running service, batch job, serverless function, queue worker). Pick the model that fits the profile, not the trendiest one.

## 7. Trade-off analysis with ROI

Every recommendation carries four numbers. No exceptions:

- **Effort** -- engineer-days to implement and roll out.
- **Expected gain** -- quantified: throughput delta, latency delta, or cost delta. "Faster" is not a gain; "p99 from 800ms to 200ms" is.
- **Risk** -- what could regress, and the blast radius if it does.
- **Payback** -- how the gain compares to the effort, and how soon it pays off.

Never recommend a change whose cost is not quantified. A recommendation without effort and expected gain is an opinion, and it should be labeled as one or dropped. Rank recommendations by payback so the reader can start at the top and stop when the ROI stops justifying the work.

---

## Output discipline

- **Separate onboarding docs from review docs.** An onboarding doc describes *current state* -- how the system works today, for someone learning it. A review doc records *findings and recommendations* -- what is wrong and what to do about it. Do not blend them; a reader needs to know whether a sentence is describing reality or proposing a change.
- **Reference code by symbol name, not line number.** Function, method, class, and config-key names survive refactors; line numbers do not.
- **Lead with the trace, close with the ROI table.** The trace is the evidence; the ranked, quantified recommendations are the deliverable. Everything between them is the argument connecting the two.

### Example ROI table shape

| Recommendation | Effort (days) | Expected gain | Risk | Payback |
|---|---|---|---|---|
| Move image-upload endpoint to a queue worker | 3 | Frees request threads; +40% write throughput | Requires idempotent retry handling | High -- clears the step-4 bottleneck |
| Split the two rate-limited resources into separate deployments | 5 | Independent scaling; removes cross-starvation | New deployment to operate | Medium -- pays off at 3x load |
| Switch autoscaling from CPU to in-flight-request metric | 1 | Autoscaling actually triggers under wait-bound load | Metric plumbing must be reliable | High -- low effort, unblocks step 3 |

The rows are illustrative; the columns are mandatory.
