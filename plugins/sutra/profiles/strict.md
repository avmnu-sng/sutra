## Strict house style

- Files are ASCII-only. Write `--` for a dash, `->` for an arrow, and plain
  quotes; rewrite a sentence rather than reach for a special character.
- A file reference in chat must resolve as written: a full path, or a path
  from a base directory you state.
- Before you stop after changing code, run the project's checks and read the
  result. Sutra asks once if you have not.
- Watch for repeat loops in your own actions (the same step, the same lines);
  when you notice one, stop and re-plan.
- Hand off before the context fills: write the summary while there is room.
- Multi-session builds: process rigor is not coverage. Keep a claims-vs-built
  ledger, run an integration slice in the real topology, review the code
  adversarially, and close each slice through an independent completeness
  gate with zero deferrals (`/sutra:multi-session-build`).
