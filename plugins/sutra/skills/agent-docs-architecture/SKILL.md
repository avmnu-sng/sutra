---
description: Use when structuring or auditing a repo's agent-facing documentation -- entry docs, a shared rulebook, routing and handoff tables, skill ordering, and a source-of-truth designation -- so agents and humans navigate it reliably.
---

# Agent docs architecture

Agent-facing docs fail in one of two ways: everything is crammed into a
single entry file that no one can navigate, or the guidance is scattered
with no declared order, no source of truth, and no way for an agent to
tell which doc answers its question. Both leave an agent guessing, and a
guessing agent hallucinates.

This skill lays out the structure that prevents that. The goal is a layered
tree where a thin entry doc routes to deeper guides, one rulebook is shared
verbatim across tools, every doc's job is declared, and one doc is named as
ground truth. The machine-readable manifest that binds these pieces together
-- entry-doc path, rulebook path, source-path-to-domain routing, skill
order -- lives in the project's own `examples/setup.yaml`, which you create.
Treat that file as the contract and this skill as the rationale.

## When to use

- Setting up agent docs (`AGENTS.md`, `CLAUDE.md`, a `docs/` tree) in a repo
  that has none, or has an overgrown single file.
- Auditing an existing tree for the failure modes below: inlined entry doc,
  drifted cross-tool rules, no routing table, no declared source of truth.
- Adding a new domain guide and wanting it to match the house shape rather
  than being one more ad-hoc file.

## When not to use

- The repo has no agents and no intent to add them; a plain `README` is
  enough.
- You are writing product or API docs for end users. This skill is about
  docs an agent reads to do work in the repo, not docs a customer reads.

---

## 1. Layer the tree; keep the entry doc thin

The entry doc (`AGENTS.md` or `CLAUDE.md`) is a switchboard, not an
encyclopedia. It states the project in two sentences, names the hard rules,
and links out to deeper docs. It does not inline setup steps, domain
walkthroughs, or troubleshooting -- those live in leaf docs and go stale the
moment they are duplicated at the top.

Target shape:

```
AGENTS.md                 <- thin entry: what this is, STOP-gate, routing table
CLAUDE.md                 <- byte-identical AI footer (see section 2)
docs/
  rules.md                <- the one shared rulebook
  setup.md                <- environment, toolchain, dev loop
  domains/
    <domain>.md           <- one guide per feature area (routing in setup.yaml)
  guides/
    <topic>.md            <- safety / domain guides (authored per section 8)
  ground-truth.md         <- the source of truth (see section 6)
examples/
  setup.yaml              <- machine-readable manifest binding all of the above
```

Rules of thumb:

- If the entry doc is longer than one screen, content has leaked in that
  belongs in a leaf. Move it and leave a link.
- Every leaf doc opens with one line stating its job ("This doc covers X;
  for Y see Z"). An agent should be able to reject a doc in one line.
- Depth over breadth. A three-level tree an agent can walk beats a flat pile
  of twenty sibling files with no ordering.

## 2. One rulebook, shared verbatim across tools

Humans and agents follow the same rules. Maintain a single `docs/rules.md`.
Different agent tools look for their guidance in different filenames
(`AGENTS.md`, `CLAUDE.md`, and others), so the AI-instructions footer must be
**byte-identical** across every one of those files -- not paraphrased, not
"kept roughly in sync." Divergence is how one tool ends up operating under
stale rules.

Mechanics:

1. Author the footer once in a canonical block.
2. Copy it verbatim into each tool's entry file.
3. Add a CI check that fails on any byte difference between the copies.

A minimal divergence gate (adapt paths to `setup.yaml`):

```
# fail if the shared AI footer drifts between entry files
diff <(sed -n '/BEGIN-AI-FOOTER/,/END-AI-FOOTER/p' AGENTS.md) \
     <(sed -n '/BEGIN-AI-FOOTER/,/END-AI-FOOTER/p' CLAUDE.md) \
  || { echo "AI footer drifted between AGENTS.md and CLAUDE.md"; exit 1; }
```

Wrap the shared region in stable `BEGIN-AI-FOOTER` / `END-AI-FOOTER`
markers so the check compares the intended span and nothing else. When you
edit the footer, edit the canonical copy and re-propagate; never hand-patch
one file.

## 3. Compliance STOP-gate plus a routing table

The first thing an agent reads in the entry doc is a STOP-gate: a short,
unmissable block that says "before you touch anything, confirm you have read
X and understood Y." It exists to stop an agent from acting before it knows
the rules.

Immediately after the STOP-gate, put a "what you need -> which doc" routing
table so the agent lands on the right doc instead of scanning the tree:

```
STOP. Before making any change:
  1. Read docs/rules.md (the shared rulebook).
  2. Confirm the source of truth for your task (section: Source of truth).
  3. If anything is unclear, ask or read -- do not guess.

What you need                     -> Read this
--------------------------------------------------------------
Set up the environment / dev loop -> docs/setup.md
Rules that gate every change      -> docs/rules.md
Work inside a feature area        -> docs/domains/<area>.md  (map: setup.yaml)
Write a new safety/domain guide   -> this skill, section 8
Resolve a conflict between docs   -> docs/ground-truth.md
```

Keep the table short and outcome-phrased ("Set up the environment", not
"setup.md"). The left column is the question the agent is actually asking.

## 4. Handoff table for multi-step / multi-skill work

When work flows across steps or skills, values get produced in one place and
consumed in another. Undeclared, those handoffs are where an agent invents a
variable name or reads a stale value. Declare them in a
`Variable | Set-by | Consumed-by` table in the relevant doc:

```
Variable            | Set-by                     | Consumed-by
------------------------------------------------------------------------
BUILD_ID            | step 1 (scaffold)          | step 3 (deploy), step 5
ARTIFACT_PATH       | step 2 (build)             | step 3 (deploy)
REVIEW_VERDICT      | review skill               | merge skill
```

- One row per value that crosses a boundary. If a value never leaves the
  step that made it, it does not belong here.
- Name the producer and every consumer. A value with a producer and no
  consumer is dead; a value consumed with no declared producer is a guess
  waiting to happen.

## 5. Skill invocation order, mode guards, and troubleshooting

Skills that run in the wrong order or the wrong state cause the most
confusing failures. Make the intended order explicit and linear:

```
scaffold -> build -> review -> integrate -> verify -> ship
   |          |         |          |           |        |
   plan     source    findings   merged      driven   tagged
```

Then give each skill a **mode guard**: a one-line precondition it checks
before doing anything, so it refuses to run in a state it cannot handle.

```
Skill        | Runs only when                    | Refuses / warns when
----------------------------------------------------------------------------
build        | a plan exists                      | no plan on disk
review       | a diff exists                      | working tree clean
integrate    | review verdict == pass             | verdict missing/failed
verify       | change touches runtime surface     | docs/tests-only diff
```

Pair the order diagram with a symptom-driven troubleshooting table so an
agent can self-diagnose instead of thrashing:

```
Symptom                          | Likely cause                 | Remedy
----------------------------------------------------------------------------
Skill exits "nothing to do"      | ran before its input existed | run prior step
Agent edits the wrong area       | skipped the routing table    | re-read section 3
Value read is stale/empty        | undeclared handoff           | add to section 4
Two docs disagree                | no source of truth honored   | see section 6
```

## 6. Designate one source of truth; wire in anti-hallucination

Every tree needs exactly one doc named as **ground truth** -- the doc that
wins when two docs disagree. Declare it explicitly (in the entry doc and in
`setup.yaml`), because an undeclared conflict is resolved by whichever doc the
agent happened to read last.

```
Source of truth: docs/ground-truth.md
On any conflict between docs, docs/ground-truth.md wins. Fix the other doc;
do not silently follow the loser.
```

Wire an anti-hallucination directive into the agent preflight (it belongs in
the shared footer from section 2, so every tool inherits it):

> When you are uncertain about a name, path, value, or behavior: **ask, read,
> or reference the source -- do not guess.** A guessed field name or file path
> is the dominant failure mode; one verified read costs less than one wrong
> change.

Uncertain means: you cannot point at the doc, schema, or code line that
backs the claim. That is a stop-and-read signal, not a proceed-and-hope one.

## 7. Golden path: "add a feature"

Give newcomers (human or agent) one ordered recipe that names real exemplar
files, so the first change follows the grain of the repo instead of
reinventing it. Point at named files, not abstractions:

1. Read `docs/setup.md`; get the dev loop green before changing anything.
2. Find the feature area in `examples/setup.yaml` (source-path -> domain map)
   and open its `docs/domains/<area>.md`.
3. Copy the nearest exemplar -- e.g. `src/features/<exemplar>.*` and its test
   `test/features/<exemplar>_test.*` -- and adapt it.
4. Run the mode-guarded skills in order (section 5): build -> review ->
   verify.
5. Update the handoff table (section 4) if your change introduces a
   cross-step value.
6. If your change encodes a new rule or hazard, write it up as a guide using
   the template in section 8.

Keep the exemplar filenames current. A golden path that points at a
deleted file is worse than none.

## 8. Authoring template for a new safety or domain guide

New guides drift into ad-hoc shapes unless they share one. This shape is the
transferable value: it turns a one-off incident into reusable, checkable
guidance. Use it verbatim for any `docs/guides/<topic>.md`.

```
# <Guide title>

## Incident
The real event that motivates this guide. Concrete: what happened, what
broke, what it cost. No hypotheticals -- a guide with no incident is an
opinion.

## Principle
The one general rule extracted from the incident. One or two sentences an
agent can hold in its head.

## Detection
How to recognize you are in the hazard zone -- the signal, grep, symptom,
or state that says "this rule applies right now."

## Protocol
The step-by-step safe procedure. Numbered, ordered, each step checkable.
This is what the agent actually does.

## Agent anti-patterns
The specific wrong moves an agent makes here -- guessing a name, skipping a
read, running a skill out of order. Name them so they can be avoided.

## Worked example
One end-to-end pass through the protocol on a real case, showing the inputs
and the correct outputs.

## Checklist
- [ ] Mechanically checkable item
- [ ] ...
Every item is verifiable. If you cannot check it, rewrite it until you can.
```

Section order matters: incident earns the principle, principle drives
detection, detection triggers the protocol, and the checklist makes the
whole thing enforceable. Drop a section and the guide loses the link that
makes it trustworthy.

---

## Checklist

- [ ] Entry doc is one screen and links out; no inlined setup or walkthroughs.
- [ ] One `rules.md`; the AI footer is byte-identical across entry files.
- [ ] CI fails on any divergence between the footer copies.
- [ ] Entry doc opens with a STOP-gate and a "what you need -> which doc"
      routing table.
- [ ] Multi-step work has a `Variable | Set-by | Consumed-by` handoff table.
- [ ] Skill order is drawn linearly; each skill has a mode guard.
- [ ] A symptom -> cause -> remedy troubleshooting table exists.
- [ ] Exactly one doc is named as source of truth, in the doc and in
      `setup.yaml`.
- [ ] The anti-hallucination directive ("ask/read/reference -- do not guess")
      is in the shared footer.
- [ ] A golden-path "add a feature" recipe points at named exemplar files.
- [ ] New guides follow the section-8 template.
- [ ] `examples/setup.yaml` reflects the current entry-doc path, rulebook
      path, source-path-to-domain routing, and skill order.
