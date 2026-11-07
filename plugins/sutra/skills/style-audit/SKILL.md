---
description: Audit a code or documentation change against the house style -- why-not-what comments, current-state docs, symbol-based references, theme-safe diagrams, and (when the project's style calls for it) ASCII-only files -- when reviewing or finishing a diff.
---

# Style audit

A field guide to the code and documentation house style, plus a procedure
for auditing a change against it. Run this before you consider a diff done,
or when reviewing someone else's diff.

## When to use

- Finishing a change that touches source comments, docs, or diagrams.
- Reviewing a pull request for style, not just correctness.
- Writing a new doc and deciding what belongs in it.

## When not to

- Mechanical, generated, or vendored files you do not own.
- A pure logic change with no comments, docs, or prose touched -- run your
  normal correctness review instead.

## The rules

### 1. Files are ASCII-only when the project's style calls for it

This rule applies only when the project's style calls for ASCII -- sutra's
strict profile asks for it (the session contract opens with
`Sutra profile: strict.`). If the project does not call for ASCII, skip this
rule and let its own encoding conventions stand.

- No non-ASCII bytes anywhere in a committed text file.
- Write `--` for an em dash, `->` for an arrow, and straight quotes (`'`
  and `"`) instead of curly ones.
- If a sentence seems to need a special character, rewrite the sentence.
  There is always an ASCII phrasing.
- Verify, do not eyeball. Run the `file` command and confirm it reports
  `ASCII text`:

  ```
  file path/to/changed_file
  ```

  If it reports `UTF-8 text` or names another encoding, a non-ASCII byte
  slipped in. Find it and fix it. To locate offending bytes:

  ```
  grep -nP '[^\x00-\x7F]' path/to/changed_file
  ```

Common leaks: pasted smart quotes, a real em dash or en dash, a Unicode
arrow, non-breaking spaces, and accented characters copied from a browser.

### 2. Comments explain WHY, not WHAT

- Comment only where the logic is non-obvious -- an external constraint, a
  workaround, a non-local invariant, a deliberate deviation.
- Delete any comment whose removal loses no information. A comment that
  restates the code it sits above is noise.
- Prefer self-documenting code: a clear name beats a comment that explains
  an unclear one.
- Good: "Retry cap is 3 because the upstream event service rejects a
  fourth attempt within the same minute." Bad: "increment the counter."

### 3. Docs describe the current state for a newcomer

- Write for someone seeing the system for the first time. Describe what is
  true now.
- Include the reasoning behind a decision and the external constraint that
  forced it -- not just the value. Say why a timeout is 10s (the upstream
  image-upload endpoint p99 is 8s, so 10s leaves headroom without hanging
  the request), not merely that it is 10s.
- Keep reference and onboarding docs focused on current state -- migration
  narrative belongs in commit messages or a decision log rather than a
  reference doc. But when a past dead-end still constrains present choices,
  record it deliberately (a decision log or ADR is a good home).
- Separate onboarding docs (current state, stable) from review or action
  docs (findings, transient). Do not mix a list of open issues into a
  reference doc.

### 4. Organize docs by audience and purpose

- One doc, one audience, one purpose. Name it for that purpose.
- Make each doc self-contained: it should stand on its own, with internal
  cross-references to sibling docs for detail rather than duplicating them.
- Break up any wall of text. A reader should scan headings and jump to the
  section they need.

### 5. Reference code by symbol, not line number

- Point at a function, class, constant, or config key by name. Line numbers
  rot on the next edit and silently mislead the next reader.
- Bad: "see line 142." Good: "see `MAX_RETRIES` in the request builder."

### 6. File references in chat must resolve as written

- Any path you hand to a reader must be copy-pasteable and resolve exactly
  as written from where the reader stands.
- Do not guess a relative path that only resolves from a directory the
  reader is not in. When in doubt, give the path from the repository root
  or an absolute path.
- Confirm the target exists before you cite it.

### 7. Diagrams stay theme-safe and readable

For diagrams, prefer defaults that survive a light/dark theme switch --
avoid hard-coded fills/text colors that invert badly, and verify in both
modes. Keep labels short and split very large diagrams. (Examples use
Mermaid; the same applies to whatever renderer you use.)

- Prefer default fills and text colors. Hard-coded colors that look right
  in light mode invert or wash out in dark mode. Rely on shape and layout
  instead.
- Keep arrow labels short -- a word or two.
- Lay nodes out to avoid crossing arrows; a crossing usually means the flow
  can be reordered.
- Cap a single diagram at roughly 15 to 20 nodes. Split a larger flow into
  linked diagrams.
- Verify the rendered diagram in both light and dark mode before shipping.

## Audit procedure

Walk the change one rule at a time and record every violation as a
checklist item. Do not fix as you go on the first pass -- collect first, so
you see the full scope.

1. Enumerate the touched files and diagrams in the change.
2. For each rule (1 through 7), scan the change and list violations. Include
   the file and the symbol or section, never a bare line number. Skip rule 1
   (ASCII-only) unless the project calls for ASCII -- i.e. the Sutra contract
   in context names the strict profile, or the project's own style declares
   ASCII-only.
3. Fix the collected violations.
4. Re-scan from step 2 against the whole change, not just the spots you
   edited -- a fix can introduce a new violation.
5. Repeat until a full re-scan is clean. Treat "no violations found" as a
   result you reached by re-scanning, not an assumption. Apply the same
   verify-completeness discipline you would use to confirm any task is
   done: the loop ends only when an independent pass finds nothing.

### Checklist template

```
[ ] Rule 1  ASCII-only (only if the project calls for ASCII): `file` reports
            ASCII text for every changed file
[ ] Rule 2  Comments explain why; no restate-the-code comments remain
[ ] Rule 3  Docs describe current state; reasoning + constraint present;
            migration narrative kept out unless a past dead-end still
            constrains present choices (then recorded deliberately)
[ ] Rule 4  Docs scoped by audience/purpose; self-contained; no wall of text
[ ] Rule 5  Code referenced by symbol, not line number
[ ] Rule 6  Every file reference resolves as written for the reader
[ ] Rule 7  Diagrams: theme-safe defaults, short labels, no crossings,
            <= ~20 nodes, verified light + dark
```

A change passes the audit only when every box is checked on a clean
re-scan.
