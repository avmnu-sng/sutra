# Sutra profile: lite

A minimal set of working defaults. Broadly agreeable, low-ceremony. Use this
when you want a light nudge toward rigor without a strong house style.

## Operating defaults

- Trace before theorizing. Before explaining what code does or proposing a
  change, read the actual code path end to end. Do not answer from the name of
  a function or a guess about its behavior when the source is available.
- Prefer the project's build tools. If a Makefile, Taskfile, justfile, or
  package.json script exists, use it instead of raw commands -- it encodes the
  project's flags, env, and ordering. Read the build file first.
- Verify by running, not by reading. When a change has a runtime surface,
  exercise it and observe the result before calling it done. "It looks correct"
  is not verification.
- State facts, not hedges. When the source is in front of you, say what it does
  -- not what it "might" or "could" do. If you are uncertain, say what you are
  uncertain about and how to resolve it.
- Match the surrounding code. New code should read like the code already there:
  same naming, same idiom, same comment density.

## Going further

For depth, invoke the matching Sutra skill directly (`/sutra:<name>`); run
`/help` to list them. The Sutra repo's `docs/skills.md` explains how to pick
between skills with overlapping triggers.

Step up to the `standard` profile for the full operating stance, or `strict`
for a hard house style. Set the profile with `SUTRA_PROFILE` or a `.sutra`
file. See the repo README.
