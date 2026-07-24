---
description: Use when deciding whether to delegate work to subagents and how to prompt, verify, and integrate their output; covers what agents do well and what they systematically miss.
---

# Agent orchestration

Subagents are a force multiplier for mechanical, parallelizable, and verifiable
work. They are not a substitute for judgment. Treat every agent's output as
evidence you must verify -- not as a finished deliverable. You own every finding
you publish, regardless of which agent produced it.

## When to use

Delegate work that is well-specified, has a checkable answer, and does not
depend on holding the whole problem in your head:

- **Mechanical tracing.** Follow one call path, one data flow, or one config
  chain to its end. "Trace how a request reaches the persistence layer."
- **Point verification.** Confirm one claim at one location. "Does function
  `parse_header` at `src/net/http.rb` handle a missing content-length?"
- **Search and aggregation.** Find every call site, collect all matches of a
  pattern, tally occurrences across a tree.
- **Parallel independent reads.** Fan out N agents to read N files or modules
  for coverage when the reads do not depend on each other.
- **Validation.** Check one agent's claim against the code, or cross-check two
  agents that touched the same surface.

Rule of thumb: if you can state the question, the exact place to look, and the
shape of a correct answer, an agent can do it.

## When not to use

Keep these yourself. Delegating them produces confident, wrong, or shallow
output:

- **Architecture and design thinking.** Agents analyze components in isolation.
  They miss cross-component interactions, shared-state coupling, and cascading
  effects. A design decision lives in the seams between parts, which no
  single-component agent sees.
- **Trade-off weighing.** Agents will list pros and cons, but they do not weigh
  them with real numbers (latency budgets, memory ceilings, blast radius, team
  cost). A list is not a decision.
- **Anything session-dependent.** Agents start fresh with no memory of this
  session -- prior decisions, constraints you discovered, why option B was
  already ruled out. If the answer depends on context you built up, the agent
  cannot reconstruct it.

If the task needs you to hold multiple parts in tension at once, do it yourself.

## How to prompt a subagent

A subagent does not inherit your operating memory, your session context, or the
constraints you have been carrying. Restate everything load-bearing in the
prompt. A good delegation prompt has five parts:

1. **Exact locations.** Give file paths (absolute where it matters) and, where
   known, symbols or line ranges. Do not make the agent rediscover where to look
   -- that is wasted budget and a source of drift.
2. **The specific question.** One claim to verify or one artifact to produce.
   Not "look into X" -- "confirm whether X does Y at Z, answer yes or no with
   the line."
3. **The output format.** State the shape you want back: a yes/no plus
   evidence, a table, a list of call sites with paths, a diff. You have to
   consume this; specify it.
4. **Embedded facts.** Put the key facts the agent needs directly in the prompt.
   If you already know the schema, the invariant, or the naming convention,
   state it. Do not force the agent to rederive what you can hand it.
5. **Explicit non-goals.** Tell it what NOT to do. "Trace the flow; do not
   recommend changes." "Report what the code does; do not judge whether it is
   correct." Scope creep in an agent is silent and expensive.

Restate the rules that constrain a correct answer -- ASCII-only, a naming
convention, a sanitization requirement, "do not touch generated files." The
agent will not apply a rule it was never told.

## After they return

Agent output is an input to your work, not the end of it. Before you act on or
publish anything an agent returned:

- **Verify the top load-bearing claims yourself.** Re-check the handful of facts
  the conclusion actually rests on, at the source. The agent's confidence is not
  evidence.
- **Do not trust line numbers.** Agents routinely misreport line numbers and
  offsets even when the surrounding claim is sound. Re-anchor against the file
  before you cite a location.
- **Cross-check for contradictions.** When two agents touched overlapping
  surface, diff their claims. A contradiction means at least one is wrong and
  both need re-checking.
- **Own every finding.** If you publish it, it is yours. "An agent said so" is
  not a defense for a wrong claim.

## Known blindspots

Agents are strong at some checks and systematically weak at others. Calibrate
how much you trust output by which kind it is.

**Strong -- structural and code-grounded (trust, then spot-check):**

- Count and cross-reference mismatches (declared N, found M).
- Broken links, dangling references, stale paths.
- Mechanical compliance (ASCII-only, formatting, lint-shaped rules).
- Code-grounded facts when given exact paths -- "does this function do X."

**Weak -- judgment and honesty (do not delegate the call):**

- **Priority and severity.** Agents defer to precedent and existing labels
  instead of re-deriving how bad something actually is. They will echo a
  "minor" tag on a real problem. Re-derive severity yourself from impact.
- **Content honesty.** An agent cannot catch when a narrative misrepresents an
  input it never saw. If a summary distorts a source the agent was not given,
  the agent has no way to know. Honesty-of-representation checks require the
  original context, which lives with you.

Bottom line: use agents to widen your coverage and to do the mechanical legwork
fast. Keep the design thinking, the trade-off calls, the severity judgments, and
the final sign-off with yourself. Agent output is evidence; the deliverable is
yours.
