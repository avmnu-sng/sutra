# Releasing Sutra

The mechanical cut for this repo. It applies the generic "Cutting a release"
procedure from the `/sutra:scaffold-execution-plan` skill to Sutra itself, so
this file only carries what is specific to Sutra: which files change, in what
order, and the traps unique to a Claude Code plugin.

## The one fact that governs everything

`plugins/sutra/.claude-plugin/plugin.json` -> `"version"` is the **single
source of truth** for the plugin version. Nothing else in the repo sets it.

- `.claude-plugin/marketplace.json` intentionally carries **no** plugin
  version. Claude Code reads the version from `plugin.json`. If the same
  version also lived in `marketplace.json` it would simply be ignored --
  `plugin.json` always wins -- but it invites confusion and drift, so the
  marketplace manifest stays version-free on purpose.
- Plugins auto-update when a user runs `/plugin marketplace update sutra`.
  Claude Code compares the installed version string against `plugin.json`.
  An **unchanged** version string is a **no-op** -- the user keeps the old
  files even after `update`. So you MUST bump `plugin.json` `"version"` on
  every release, or the release never reaches anyone.

If you change nothing else, change that field.

## Versioning a config kit

Semver, read through the lens of "this ships skills and profiles, not a
library API":

- **MAJOR** (`X`): a breaking change to a skill or profile contract --
  renaming or removing a skill, changing what a profile guarantees, altering
  an interface a user's project or automation depends on.
- **MINOR** (`Y`): a new skill, subagent, profile, or capability. Additive;
  nothing existing breaks.
- **PATCH** (`Z`): a fix or wording change -- tightened prose, a corrected
  example, a bug in a hook. No new surface, no broken surface.

When in doubt between MINOR and MAJOR, ask whether an existing user's
workflow could break on update. If yes, it is MAJOR.

## Cut procedure

Run these in order. Do not reorder -- the validate-and-CI gate must pass
before the version bump so you never tag a broken tree.

1. **Stage the changelog.** Confirm `CHANGELOG.md` `[Unreleased]` already
   holds every entry for this release (Added / Changed / Fixed as needed).
   Nothing ships that is not written down here.

2. **Validate locally and confirm CI is green.** Run both:

   ```
   claude plugin validate .
   claude plugin validate ./plugins/sutra
   ```

   `claude plugin validate` is a local schema check -- run it before the
   version bump so you never tag a manifest that fails validation. Then confirm
   `.github/workflows/ci.yml` is green on the exact
   SHA you are about to tag (ASCII-only, JSON/YAML validity, shell syntax,
   skill/agent frontmatter). Green on "a recent run" is not green on this SHA.

3. **Bump the version.** Edit `plugins/sutra/.claude-plugin/plugin.json`
   `"version"` to `X.Y.Z`, chosen per the rules above. This is the change
   that makes the release real.

4. **Roll the changelog.** In `CHANGELOG.md`, rename the `[Unreleased]`
   heading to `## [X.Y.Z] - YYYY-MM-DD` with today's date, then open a fresh,
   empty `## [Unreleased]` heading above it for the next cycle.

5. **Commit.** One commit for the bump plus the changelog roll. Imperative
   subject with a conventional prefix (e.g. `chore: release vX.Y.Z`).

6. **Tag `main`.** Tag the gated SHA:

   ```
   git tag vX.Y.Z
   ```

   Use the pre-release ladder for anything not final:
   `vX.Y.Z-alpha.N` -> `vX.Y.Z-beta.N` -> `vX.Y.Z-rc.N` -> `vX.Y.Z`.

7. **Push the tag.**

   ```
   git push origin vX.Y.Z
   ```

8. **Verify from a clean install.** In a throwaway environment (or after
   `/plugin marketplace remove sutra`), install from scratch and confirm the
   new version lands:

   ```
   /plugin marketplace add avmnu-sng/sutra
   /plugin install sutra@sutra
   ```

   Then confirm an already-installed client picks it up via
   `/plugin marketplace update sutra`. The reported version must be `X.Y.Z`.
   If it still shows the old version, step 3 was skipped or not pushed.

## Do NOT

- **Do NOT** put the version in both manifests. It lives only in
  `plugins/sutra/.claude-plugin/plugin.json`. Leave `marketplace.json`
  version-free.
- **Do NOT** reuse a version number. `update` is a no-op against an unchanged
  string, so a re-cut under the same version silently reaches no one. Bump,
  even for a one-line fix.
- **Do NOT** tag off a non-`main` branch. Sutra is trunk-based; tags live on
  `main` and point at the SHA that passed the gate.
