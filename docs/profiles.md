# Profiles

Sutra ships its operating guidance in three layered profiles: `lite`,
`standard`, and `strict`. Each is a strict superset of the one below it.
Moving up a level never drops a principle -- it only adds more rigor.

- **lite** -- the core working habits. The smallest set of principles
  that keep an agent honest: investigate before theorizing, use the
  project's own tooling, verify by running, state facts plainly, and
  match the code already in front of you.
- **standard** (default) -- everything in `lite`, plus judgment and
  collaboration principles: think in systems, quantify trade-offs, hold
  an opinion, delegate mechanical work while owning the call, and write
  comments and docs for the next person.
- **strict** -- everything in `standard`, plus the publishing and
  hygiene rules that matter when work leaves your machine: ASCII-only
  files, commit and branch discipline, copy-pasteable references,
  readable diagrams, multi-session build gates, and sanitizing content
  before it is shared.

Because the layers nest, choosing a lower profile loses nothing except
the higher-tier principles themselves. A `lite` session still traces
before it theorizes; it simply does not carry the strict-tier ASCII or
commit-hygiene rules.

## Selecting a profile

Resolution order, first match wins:

1. **`SUTRA_PROFILE` environment variable** -- set to `lite`,
   `standard`, `strict`, or `off`.
2. **A `.sutra` file** in the project root -- a single line naming the
   profile (`lite`, `standard`, `strict`, or `off`).
3. **Default** -- `standard`.

```sh
# Per shell / per run
export SUTRA_PROFILE=strict

# Per project, checked into the repo
printf 'strict\n' > .sutra
```

Setting the profile to `off` injects nothing. No guidance is added to
the session and no hooks emit output. Use `off` to run a clean baseline
or to hand the session to another tooling layer.

## How injection works

Sutra does not edit `CLAUDE.md` or any file in your repository. Injection
is entirely runtime:

1. A **SessionStart hook** resolves the active profile using the order
   above.
2. The hook prints the resolved profile's Markdown to **stdout**.
3. Claude Code captures that stdout and adds it to the session context.

The guidance therefore lives only in the agent's context for that
session. Nothing is written to disk, nothing is committed, and switching
profiles is just changing an env var or a one-line file and starting a
new session.

## Hard invariant: profiles add guidance, they do not enforce

Profiles are advisory. Injecting a profile only adds text to context --
it never changes what a write, edit, or command is allowed to do.

The single exception is a **strict-profile ASCII warning**. On the
`strict` profile, when a write would introduce non-ASCII bytes, Sutra
emits a **non-blocking** warning. It surfaces the offending content and
keeps going. It never blocks, cancels, or rewrites the write.

Keep this invariant intact when customizing. If you need enforcement,
build it outside Sutra (for example, a pre-commit check or a CI gate);
do not turn a profile into a blocking gate.

## Principle -> profile mapping

Each principle is listed against the **lowest** profile that carries it.
Because higher profiles are supersets, a principle in `lite` is also
present in `standard` and `strict`, and a principle in `standard` is
also present in `strict`.

| Principle | Lowest profile |
| --- | --- |
| Trace before theorizing -- read the actual code path before proposing a cause | lite |
| Use the project's build tools rather than ad hoc commands | lite |
| Verify by running, not by asserting it should work | lite |
| State facts, not hedges | lite |
| Match the surrounding code's style and conventions | lite |
| Think in systems -- account for upstream and downstream effects | standard |
| Quantify trade-offs instead of hand-waving them | standard |
| Be opinionated -- challenge a weak design instead of implementing it silently | standard |
| Delegate mechanical work, but own the judgment calls | standard |
| Finish verification lists -- do not leave checks half-run | standard |
| Comments explain WHY, not WHAT | standard |
| Docs describe current state for a newcomer, not change history | standard |
| Reference code by symbol, not by line number | standard |
| Own corrections transparently when analysis is wrong | standard |
| Apply full rigor regardless of project size | standard |
| Front-load disambiguation -- ask the clarifying questions before building | standard |
| Never weaken a test to go green | standard |
| Honor scoped instructions; fix a red build before running tests | standard |
| Calibrate energy to complexity times blast radius | standard |
| ASCII-only files | strict |
| Commit and branch discipline | strict |
| Copy-pasteable file references | strict |
| Safety guardrails -- guard destructive commands, catch action loops, hand off before context overflow | strict |
| Mermaid diagrams kept readable | strict |
| Multi-session build gates before declaring work done | strict |
| Sanitize content before sharing it beyond the team | strict |

Read this table when deciding which profile to run: pick the lowest one
whose rows cover what you need. Everything below your chosen level comes
along automatically.

## Customizing

The profiles are plain Markdown. To adjust the guidance:

- **Edit the profile Markdown** for the level you want to change. Add,
  remove, or reword principles to fit your team.
- **Preserve the layering.** Keep each profile a strict superset of the
  one below it. If you add a principle to `lite`, it must remain present
  in `standard` and `strict`; if you add one to `standard`, it must
  remain present in `strict`. The mapping table above is only true while
  the supersets hold.
- **Do not add enforcement.** The only enforcement Sutra ships is the
  non-blocking strict ASCII warning. Keep new rules advisory; put any
  blocking behavior in a separate layer you control.

After editing, start a new session so the SessionStart hook re-reads and
re-injects the updated profile.
