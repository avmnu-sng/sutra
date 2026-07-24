---
description: Use when finishing a verification, cleanup, or find-and-fix sweep across a codebase and a single missed instance would be costly -- enumerate every match, fix each individually, and re-search until empty instead of summarizing and applying once.
---

# Verify completeness

A cleanup or verification pass fails the moment it starts to feel procedural.
The instinct "I fixed all instances of X" is exactly where singletons survive:
the one match that did not fit the mental pattern, the capitalized variant, the
synonym you never searched for. The reliable method is slower per pass and
faster to actually-done. Do not summarize-then-apply. Enumerate, tick off each
spot individually, and iterate the search until it comes back empty.

## When to use

- Removing every occurrence of a token, secret, deprecated API, or debug hook.
- Applying a mechanical fix reported as a list of `file:line` findings.
- Any sweep where one survivor is a real defect: security, compliance, a public
  share, a rename that must be total.

## When not to

- A single, known edit at a known location. There is nothing to enumerate.
- Exploratory work where "good enough for now" is an acceptable stopping point.

## Procedure

1. **Enumerate into atomic checklist items.** Turn the search result into one
   line item per exact spot -- each `file:line`, each match, its own box. Do not
   collapse "12 hits in service A" into a single item. You tick a box only after
   that specific location is fixed and re-read. Twelve hits means twelve boxes.

2. **Fix, then re-run the SAME search.** After a batch of edits, run the
   identical comprehensive search again. If it returns anything at all, you are
   not done -- fix the new items and search again. Repeat until the search
   returns empty. The empty result, not your sense of having handled it, is the
   completion signal.

3. **Search case-insensitively.** A case-sensitive sweep silently skips
   `Token`, `TOKEN`, and `token` when you searched for one form. Pass the
   ignore-case flag (`grep -i`, `rg -i`) by default on cleanup work.

4. **Expand the pattern as variants surface.** Every pass teaches you a new
   spelling: a hyphen vs underscore, an alias, a wrapper name, a comment form.
   Add it to the pattern and re-run from the top. The search you finish with is
   almost never the search you started with.

5. **For shipment-blocking work, add one more pass after it looks clean.** When
   the cost of a survivor is a leaked secret, a compliance miss, or an external
   share, run at least one additional full search AFTER the first clean result.
   "Looks clean" and "is clean" diverge exactly on the item you cannot picture.

6. **Record misses and their cause.** When a later pass finds something an
   earlier pass missed, note why it slipped (case, a variant, a file type
   excluded from the glob) and fold that into the pattern and your defaults so
   the next sweep starts wider.

## Checklist

- [ ] Result enumerated to one atomic item per `file:line` / match.
- [ ] Each item fixed and the exact spot re-read before ticking.
- [ ] Same search re-run after edits; repeated until it returns empty.
- [ ] Search run case-insensitively.
- [ ] Pattern expanded for every new variant discovered mid-sweep.
- [ ] For shipment-blocking work, one extra full pass run after first-clean.
- [ ] Any miss recorded with its cause and folded into the pattern.

## Anti-patterns

- Reading a findings list, making edits from memory, and declaring done without
  re-searching. The list was a snapshot; your edits may have shifted lines or
  revealed neighbors.
- Trusting a single case-sensitive pass on a token that appears in mixed case.
- Stopping at the first clean pass on work that ships externally.
- Treating "I handled that category" as equivalent to "the search is empty."
  Only the empty search is proof.
