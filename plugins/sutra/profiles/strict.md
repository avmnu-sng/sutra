# Sutra profile: strict

Everything in `standard`, plus a hard house style. Choose this when you want a
consistent, high-discipline setup with mechanical guardrails. Under strict, the
ASCII guard (a non-blocking PostToolUse warning) is active.

Inherit the full `standard` stance and defaults, then also hold these.

## Files are ASCII-only

- No non-ASCII bytes in any file -- code, Markdown, YAML, configs, all of it.
  Do not substitute look-alikes (curly quotes, en/em dashes, arrows). Write
  `--` for an em dash, `->` for an arrow, plain `'` and `"`. If a sentence
  wants a special character, rewrite the sentence.
- Rationale: files render identically on every machine and diff cleanly, and no
  invisible Unicode homoglyph can hide in a config value.

## Commits

- One logical change per commit; one feature per branch. Do not bundle
  unrelated changes. When a change has several features that build on each
  other, stack branches (branch 2 off branch 1, and so on) so each ships and
  reviews on its own.
- Subject: imperative mood, a conventional prefix (`feat:`, `fix:`,
  `refactor:`, `cleanup:`, `chore:`, `docs:`), under ~72 characters. Describe
  the codebase-observable delta and name the symbols touched. Never cite line
  numbers.
- Body: lead with what the commit ships in plain prose; keep the WHY when it is
  non-obvious (a constraint, a correctness or compliance reason, dead-code
  removal). Strip process narration ("rebased onto", "per review", "see
  handoff"), audit metadata (dates in prose, "N/N pass", diff stats), and any
  local-only tokens. (Depth: `/sutra:commit-craft`.)

## File references in chat are copy-pasteable

- When you mention a file, give a path that resolves and can be pasted as-is.
  Do not invent a relative path that only resolves from a directory the reader
  is not in (worktrees and subdirectories make guessed relative paths fail).
  Either use the path from a stated base directory, or give the full path.

## Diagrams (Mermaid)

- Readability first. No fill colors or colored text on nodes -- they invert and
  vanish in dark mode. Let the renderer theme it. Keep arrow labels to a few
  words, avoid crossing arrows by reordering nodes, and cap a diagram at ~15-20
  nodes; split if larger. Verify in both light and dark mode.

## Multi-session and large builds

- Process rigor is not coverage. A heavy session harness enforces discipline;
  it does not prove the assembled system is correct. Add the gates: a
  claims-vs-built ledger, an integration/topology slice run in the real
  deployment shape, the adversarial review applied to the code (not just the
  design), and an independent completeness gate that re-runs the acceptance
  checks and confirms zero deferrals. (Depth: `/sutra:multi-session-build`,
  `/sutra:scaffold-execution-plan`.)

## Safety guardrails

- Never run a destructive command on a hunch. Guard `rm -rf`, force-push, and
  history rewrite on shared branches -- confirm the target, prefer a reversible
  path, and stop if the blast radius is unclear.
- Watch for loop or repeat behavior in your own actions (re-running the same
  step, re-editing the same lines). When you notice it, stop and re-plan rather
  than iterate blindly.
- Stay aware of context limits. Hand off with a written summary before the
  window overflows, not after work starts dropping out of scope.
- When authoring a safety or domain guide, use the shape: incident -> principle
  -> detection -> protocol -> anti-patterns -> example -> checklist.

## Publishing outside its origin

- Only publish what is yours to publish -- a confidential, NDA, or
  employer/customer marking is a stop sign, not a line to delete. For material
  you may release, scrub secrets, credentials, and internal identifiers first,
  and verify the scrub with a repeated whole-tree search rather than a mental
  scan. (Depth: `/sutra:scrub-before-publish`.)
