---
description: Use at the end of a work session, or whenever recording a durable lesson -- run a probe-backed retro, reconcile outside critique, and capture only the lessons that survive.
---

# Retro and memory

A session ends. The instinct is to write "everything is green, shipped X,
tests pass" and move on. That sentence is worthless the moment it is
challenged, because none of it is backed by something a future session can
re-run. The retro loop replaces claims with probes, reconciles outside
critique against what the code actually does, and writes only the durable
residue into whatever notes you keep, kept deliberately small.

The core is the per-session retro: before you call a session done, probe
every health claim, audit what you actually shipped, and reconcile outside
critique. What survives -- and only that -- is worth writing down. Where and
how you persist it is your choice; the appendix sketches one optional shape.

## When to use

- Closing out a work session that produced code, decisions, or findings.
- Recording a lesson you want the next session to inherit.
- Absorbing an outside review, adversarial critique, or reviewer's list of
  concerns.
- Optionally, on a periodic pass that rolls recurring findings into standing
  themes.

## When not to

- Mid-session scratch notes. Retro is a close-out ritual, not a running log.
- A one-off fact with no reuse value. Not every observation earns an entry.

---

## The per-session retro

### 1. Back every health claim with a runnable probe

No bare status claims. Each line that asserts the state of the world carries
the exact command that proves it and the observed result -- so the next
session re-runs the probe instead of trusting your prose.

- Bad: "Test suite passes."
- Good: "Test suite passes -- `task test:unit` -> 214 examples, 0 failures
  (run at close)."

- Bad: "The new endpoint works."
- Good: "New endpoint works -- `task smoke:health` -> `{"ok":true}`;
  drove the full create->read flow, not just the unit test."

Rules:

- A probe is a command anyone can paste, plus its observed output. "I
  checked" is not a probe.
- Prefer end-to-end drives over test-only evidence. A green test proves the
  test is green; it does not prove the feature works. Where it matters,
  exercise the real flow.
- If a claim has no probe, either find one or downgrade the claim to an open
  question. Do not ship an unbacked green.

### 2. Audit shipped-and-used vs shipped-but-only-exercised-by-tests

Architecture lies about usage. A module can be wired, imported, and covered
and still have zero real callers -- exercised only by the tests written to
cover it. Judge every shipped unit by **actual usage**, not by whether it
exists in the design.

For each thing you shipped this session, sort it:

- **Shipped and used** -- a real, non-test call site drives it in a genuine
  flow. Keep.
- **Shipped, tests-only** -- the only callers are specs. Flag it: is it a
  real seam awaiting an integration that is genuinely next, or is it dead
  weight to delete? Name which, with the evidence.

Probe the distinction, do not eyeball it: grep for call sites, exclude the
test tree, and look at what is left.

```
# real callers only -- exclude the test/spec tree
grep -rn "new_helper" src/ | grep -v -E '(test|spec)/'
```

An empty result under a non-empty test-inclusive search is the tell: covered,
not used.

### 3. Reconcile outside critique -- VALIDATED / PARTIAL / CHALLENGED

Self-probing catches what you thought to probe. Adversarial review catches
what you did not. This is a **separate mechanism**: every outside critique --
a reviewer's comment, a linter's complaint, a rival design's claim, a "this
is broken" from a field test -- gets walked against project reality and filed
under exactly one heading.

- **VALIDATED** -- the critique is correct against the current code. Owns a
  fix or a tracked follow-up. Cite the file/symbol that confirms it.
- **PARTIAL** -- correct in part. State the true kernel and the part that
  does not hold, each with evidence.
- **CHALLENGED** -- does not hold against reality. Say why, with the probe or
  file:symbol that refutes it. This is not dismissal-by-assertion; a
  CHALLENGED line without a refuting probe is just an opinion.

Never collapse a critique into a bare "fixed" or "won't fix." The reconciled
verdict plus its evidence is the artifact -- it is what makes the next
reviewer's pass cheaper and stops the same objection from recurring.

### Per-session retro checklist

- [ ] Every health/status line carries a paste-able probe and its observed result.
- [ ] Green claims backed by an end-to-end drive where it matters, not test-only.
- [ ] Each shipped unit sorted: used vs tests-only, by grep evidence not architecture.
- [ ] Tests-only units explicitly labeled real-seam-next or delete.
- [ ] Every outside critique filed VALIDATED / PARTIAL / CHALLENGED with evidence.

The retro is done when those five are done. Persistence is what keeps the
next session from relearning the same thing -- it is not another gate.

---

## Appendix -- persisting what survives (optional)

The retro above is the method. Where the surviving lessons live is a separate,
personal choice. One way to keep durable lessons -- adapt to whatever note
system you already use: a wiki, an issue tracker, a plain file, or nothing.
Two habits travel with any of them:

- **Keep it small; extend, don't proliferate.** Before adding a note, look
  for an existing one that already covers the topic and widen it instead. An
  umbrella note covering several related rules beats a pile of thin ones that
  nobody rereads. When two notes drift toward the same subject, collapse them.
- **Sanitize before anything ships.** Keep a hard line between local-only
  specifics -- private names, internal identifiers, ticket codes, hostnames --
  and the generic, reusable lesson underneath. Strip a rule to its generic
  form before it leaves your notes for a shipped guide. When in doubt, it
  stays local.

If you want more structure, these are optional patterns, not requirements --
pick only what earns its keep:

- A short recall line per note, leading with the trigger, so a future session
  can scan without opening everything. Cross-link related notes instead of
  duplicating them.
- A periodic meta-pass that clusters recurring findings across sessions into a
  few standing themes -- a signal that shows up three times is a rule, once is
  an anecdote.
- A pinned list of settled facts you agree not to re-probe until something
  concrete contradicts them, and a single authoritative source to break
  numeric ties (a threshold, a version, a count).
- A short "what we learned -> what changed" changelog, so a lesson that never
  altered a guide stays visible as an open action rather than quiet journaling.
- An end-of-session summary, if some tooling consumes one -- emit it once.

None of these gate the retro. Reach for a pattern only when the store has
grown large enough that the pattern would save you time.
