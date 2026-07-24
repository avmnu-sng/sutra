---
description: Use when writing or revising a git commit message, splitting work into commits, or structuring a branch so a future engineer running git blame understands the change.
---

# Commit craft

Write the message for the engineer who lands on this line six months from
now with `git blame`, no context, and a production incident. Describe the
codebase-observable change and why it exists. Strip everything that only
made sense inside the session that produced it.

## When to use

- You are about to write or amend a commit message.
- You are deciding how to split a pile of changes into commits.
- You are structuring a branch (or a stack of dependent branches).

## When not to use

- Trivial mechanical noise the reader will never blame (leave it, or fold
  it into the logical commit it belongs to).

## Subject line

- Imperative mood, plain English, under ~72 characters. "Add retry to
  upload client", not "Added" or "Adding".
- If your project uses a commit convention (Conventional Commits
  `feat:`/`fix:`/..., gitmoji, an `area:` summary scope, or a ticket-key
  prefix), follow it consistently. Absent one, a plain imperative subject
  naming the symbols is enough.
- Use `fix(scope):` only when the scope is genuinely narrower than the
  files touched. If the fix spans the files it names, drop the scope --
  a scope wider than reality misleads.
- Name the codebase-observable delta and the symbols involved: the
  function, type, constant, or file. "fix(auth): reject empty token in
  verify_session", not "fix: bug in auth".
- Never cite line numbers. They rot on the next edit. Name the symbol
  instead; a symbol survives a reformat, a line number does not.

## Body

- Lead with WHAT the commit ships, in plain prose. Open with a verb on the
  delta: "Move `parse_headers` to `http/headers.rb`.", "Raise the
  connection pool cap from 8 to 32.", "Delete the unused `LegacyEncoder`
  path."
- Keep the WHY only when it is not obvious from the WHAT. Non-obvious
  reasons worth a sentence:
  - a constraint (an upstream API caps page size at 100).
  - a correctness or compliance reason (values must be redacted before
    logging).
  - dead-code removal (no caller since the v2 client shipped).
  - an operational precondition (requires the new column to be backfilled
    first).
- Optionally name who depends on this and one short pointer to verify it:
  "Consumed by the image-upload endpoint; run the upload smoke suite."
- Keep the body wrapped and readable. One blank line between subject and
  body.

## Strip from every message

- Session and process narration: "per review", "rebased onto main",
  "see handoff", "as discussed", "second attempt".
- Audit metadata: dates written in prose, tracker or ticket IDs, "12/12
  pass", diff stats, and lint-clean enumerations. The commit is not a
  status report.
- Internal-only tokens or shorthand a future reader outside your team
  cannot decode: private milestone codes, internal service nicknames,
  local branch names.

If a fact is not observable in the code or needed to understand the
change, it does not belong in the message.

## Structure

- One logical change per commit. If you need "and" to describe it, it is
  probably two commits.
- One feature per branch.
- When features depend on each other, keep each independently reviewable
  -- either as separate PRs merged in order, or as a branch stack if your
  team uses one. The reviewer reads a coherent story instead of one
  megadiff.

## Opening a pull request

- Give the PR a semantic title with the same discipline as a subject line:
  imperative, following your project's subject convention (or a plain
  imperative naming the symbols), scope narrower than the files touched,
  symbols named. On a squash merge the title becomes the commit subject --
  write it as one.
- If the repo has a PR template, fill it. Otherwise a What / Why / How /
  Testing structure is a solid default:
  - **What** -- the codebase-observable delta, in plain prose. The same
    WHAT you would lead a commit body with.
  - **Why** -- the constraint, correctness reason, or precondition that
    made the change necessary. Skip it only when the What makes it obvious.
  - **How** -- the approach and any non-obvious design choice a reviewer
    needs to follow the diff.
  - **Testing** -- what you ran and how a reviewer reproduces it: the
    suite, the command, or the manual steps.
- Preview the PR before you create it. Read the rendered title and body,
  confirm the diff is the one you intend, and check the commit list tells
  the branch's story.
- Pass the base branch explicitly. Do not rely on the tool's default --
  name the branch you are targeting so the PR opens against the intended
  base, not whatever the tool guesses.

## Branch and commit hygiene audit

- Before any history rewrite -- rebase, amend, force-push -- audit the
  branch first. List its commits and read them; know exactly what is
  about to change before you change it.
- Confirm per branch what the rewrite will do, then run it. Audit,
  then confirm, one branch at a time. Never blind-rewrite.
- For a stack of dependent branches, audit each branch on its own. A
  rewrite that looks correct on one branch can silently reorder or drop
  commits on the branch built above it.
- A force-push overwrites remote history others may have pulled. Confirm
  the branch is yours to rewrite and that the audited commit list is the
  one you mean to publish.

## Encoding

- Match the project's encoding policy (sutra's strict profile is
  ASCII-only). When it is ASCII, use `--` for an em dash, `->` for an
  arrow, and straight quotes. Non-ASCII bytes break older tooling and
  blame viewers.

## Quick checklist

- [ ] Subject is imperative, under ~72 chars, and follows the project's
  subject convention (or plain imperative).
- [ ] Scope (if any) is narrower than the files touched.
- [ ] Symbols named; no line numbers.
- [ ] Body leads with WHAT; WHY present only when non-obvious.
- [ ] No process narration, audit metadata, or undecodable internal tokens.
- [ ] One logical change; branch scoped to one feature.
- [ ] Encoding matches the project's policy (ASCII on strict).

## Example

```
fix(cache): expire entries on write, not just on read

Move eviction from the read path into `Cache#set` so a key that is
overwritten while its TTL is already past does not serve the old value
for one extra read. The read-path check stays as a backstop.

Reasons entries could outlive their TTL: a hot key was written but never
re-read, so the lazy read-path sweep never ran.

Consumed by the session store; the ttl_expiry spec covers the new path.
```
