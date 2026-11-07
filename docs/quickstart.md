# Quickstart

See Sutra work once, end to end, in about ten minutes. You will install the
plugin, start a session that picks up its operating contract, run a skill on a
tiny throwaway repo, and watch the strict profile's checks fire without ever
blocking a tool call.

No real project required. We will use a toy service called `snippet-store` --
a single-process HTTP app with two routes (`POST /snippets` to save text,
`GET /snippets/:id` to read it back) sitting on one SQLite file. Invent it as
you read; nothing here depends on code that actually exists.

## 1. Install (2 commands)

Open any Claude Code session and run:

```
/plugin marketplace add avmnu-sng/sutra
/plugin install sutra@sutra
```

The first command registers the Sutra marketplace with your Claude Code
install -- it only tells Claude Code where to find the plugin. The second
installs the `sutra` plugin from that marketplace. That is the whole install:
no clone, no copied files, no edits to your `CLAUDE.md`.

If `/plugin` is not recognized, your Claude Code build is too old -- update it
and retry.

## 2. Start a fresh session and see the profile

Skills and the operating profile register at session start, not mid-session.
So start a new session (or restart Claude Code).

At the top of the new session, Sutra's `SessionStart` hook composes the
operating contract for the active profile and hands it to Claude Code, which
adds it to the session context. You have not set a profile yet, so you get the
default, `standard`: the core layer plus the standard stance. In context you
will see a block that opens like this:

```
Sutra profile: standard.

# Sutra operating contract

This core holds for the whole session. Sutra adds short rules at the moment
they apply (a commit, a test or migration edit, publishing, delegation, web
content); each names the `/sutra:<skill>` that carries the depth.
```

The same hook scans the instruction files the project loads (`CLAUDE.md`,
`AGENTS.md`, rules files) for hidden Unicode and warns both you and Claude if
it finds any.

That block is the contract for the whole session, and Sutra adds it again
after a compaction. Nothing was written to your repo to make it appear -- it
lives only in the session context. To confirm it took hold, ask the agent a
quick question:

```
What operating profile are you running, and name two rules it puts on you.
```

You should get `standard` plus two of its principles (for example: trace the
real code path before theorizing, and quantify trade-offs with numbers).

## 3. Pick a profile

Three profiles ship, built from layers: `lite` is the core, `standard`
(default) adds the standard stance and the rule cards, and `strict` adds a
house style on top of both. Your own choice wins: the `SUTRA_PROFILE`
environment variable, then the plugin's `profile` setting, then the default.

```bash
# Globally, for this shell:
export SUTRA_PROFILE=strict
```

```bash
# Or a project's request for more rigor, checked into the repo root:
echo strict > .sutra
```

The `.sutra` file is a single line -- just the profile name, no quotes. It
applies only when you have not chosen a profile yourself, and it can only
raise the profile to `strict`: Sutra refuses a `.sutra` that asks for `lite`
or `off`, and tells you so. Set `SUTRA_PROFILE=off` to drop the contract while
keeping the skills installed; the hidden-Unicode warnings still run.

For the rest of this walkthrough, turn on `strict` so you can see its checks
later:

```bash
export SUTRA_PROFILE=strict
```

Restart Claude Code from that shell so the hooks see the variable. Now the
context block opens with `Sutra profile: strict.`, and the contract carries the
strict house style after everything in `standard`.

## 4. Invoke a skill on the toy service

Skills are invocable methodologies, addressed as `/sutra:<name>`. Point one at
`snippet-store`. Describe the toy service to the agent, then run:

```
/sutra:architecture-review

Here is snippet-store: a single Node process, two routes -- POST /snippets
writes a row, GET /snippets/:id reads one -- backed by one SQLite file on
local disk. Review it.
```

`architecture-review` runs a 7-point pass rather than a vibe check. Watch it:

1. Trace a request end to end -- HTTP in, the SQLite write, the response out.
2. Question the choke points -- here, every write goes through one SQLite
   file with a single writer lock.
3. Stress it at 2x, 5x, and 10x load. The read path scales; the write path
   serializes on that one lock and is the first thing to fall over.
4. Separate elastic work (stateless reads) from rate-limited work (the
   serialized writer) and propose splitting them.
5. Weigh the deployment model -- one process on local disk means no
   horizontal scale and no durability story.
6. Quantify the fix -- what a move to a networked store with a connection
   pool buys you, at what cost, versus staying put.
7. Land a verdict with numbers, not adjectives.

You end up with a concrete review: the SQLite writer is the ceiling, reads are
fine, and here is the ROI of changing it -- not "looks scalable."

Prefer something smaller? Try a completeness sweep instead. Say you renamed a
helper from `getSnippet` to `fetchSnippet` and want every caller updated:

```
/sutra:verify-completeness

I renamed getSnippet to fetchSnippet. Find every remaining reference and fix
each one.
```

It turns the search into a checklist, fixes each hit, then re-searches until
the list is empty -- so no stray caller survives the rename.

## 5. See the strict checks

Under `strict`, Sutra adds two checks to what every `standard` session gets.
Neither blocks a tool call.

**The ASCII notice.** Ask the agent to write a file that contains a real
non-ASCII character, such as a Unicode em dash (U+2014) or a curly quote,
rather than the ASCII `--`:

```
Write a file notes.md whose first heading uses a real Unicode em dash
character, not two hyphens.
```

The write goes through and the file lands on disk. Then Sutra adds a note like
this to Claude's context (it goes to Claude rather than to you, so ask the
agent what Sutra reported):

```
sutra (strict): notes.md has a non-ASCII byte at line 1. Prefer ASCII: -- for
a dash, -> for an arrow, plain quotes.
```

It names the file and the first offending line and suggests the ASCII
substitutes. It does **not** block, cancel, or rewrite the write -- the file
is already there.

**Verify-before-stop.** Ask for a small code change, such as a size limit in
a new `server.js` for `POST /snippets`. If the agent tries to finish without
having run a check command since the edit, Sutra's Stop hook asks it once to
run the project's checks -- build, tests, lint -- and read the result, or to
say in one line why they do not apply. It asks at most once per batch of edits,
never when the agent ends by asking you a question, and `SUTRA_GATE=off` turns
it off.

That is the invariant: Sutra never blocks a tool call, and under `strict` it
asks for checks at most once per batch of edits. If you want a hard gate,
build it outside Sutra (a pre-commit check or CI).

To drop both checks, go back to `standard` and restart Claude Code from that
shell:

```bash
export SUTRA_PROFILE=standard
```

## 6. Where next

You have seen the whole loop: install, the contract in context, a skill on a
real task, and the strict checks. From here:

- [`docs/skills.md`](skills.md) -- the full skills catalog and a decision map
  that routes each task to the one skill that fits (and names the sibling to
  reach for instead when two overlap).
- [`docs/profiles.md`](profiles.md) -- the layers in depth, the rule cards
  and their triggers, precedence, the security floor, the strict stop gate,
  and the rule-to-layer mapping table.
- [`README.md`](../README.md) -- the overview: what ships in the kit (skills,
  subagents, profiles, workflows, examples) and how it all composes.

When you want the operating contract to travel in git for teammates who have
not installed the plugin, see [`docs/install.md`](install.md) for the
`@import`-a-profile path.
