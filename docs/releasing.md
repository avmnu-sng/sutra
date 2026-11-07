# Releasing Sutra

The mechanical cut for this repo. It applies the generic "Cutting a release"
procedure from the `/sutra:scaffold-execution-plan` skill to Sutra itself, so
this file only carries what is specific to Sutra: which files change, in what
order, and the traps unique to Claude Code plugins.

## The one fact that governs everything

Each plugin's `"version"` lives in its own manifest, and the two always match:

- `plugins/sutra/.claude-plugin/plugin.json` -> `"version"`
- `plugins/sutra-harness/.claude-plugin/plugin.json` -> `"version"`

The plugins release together under one version, and `check_manifests` in
`scripts/check.sh` fails when they differ or when `CHANGELOG.md` has no
section for that version. Nothing else in the repo sets a version.

- `.claude-plugin/marketplace.json` intentionally carries **no** plugin
  version. Claude Code reads the version from `plugin.json`. If the same
  version also lived in `marketplace.json` it would simply be ignored --
  `plugin.json` always wins -- but it invites confusion and drift, so the
  marketplace manifest stays version-free on purpose.
- Plugins auto-update when a user runs `/plugin marketplace update sutra`.
  Claude Code compares the installed version string against `plugin.json`.
  An **unchanged** version string is a **no-op** -- the user keeps the old
  files even after `update`. So you MUST bump both `"version"` fields on
  every release, or the release never reaches anyone.

If you change nothing else, change those two fields.

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

Run these in order. Do not reorder -- the gate runs before the bump, again
on the bumped tree, and in CI on the release commit, so you never tag a
broken tree.

1. **Stage the changelog.** Confirm `CHANGELOG.md` `[Unreleased]` already
   holds every entry for this release (Added / Changed / Fixed as needed).
   Nothing ships that is not written down here.

2. **Validate locally.** Run all four:

   ```
   bash scripts/check.sh
   claude plugin validate --strict .
   claude plugin validate --strict ./plugins/sutra-harness
   claude plugin validate --strict --profile directory ./plugins/sutra
   ```

   All four must pass. `scripts/check.sh` runs the same checks as CI's
   `checks` job (ASCII, JSON and YAML parsing, shell syntax and shellcheck,
   skill and agent frontmatter, the manifests, the plugin folder limits, the
   directory's file rules for `plugins/sutra`, the workflow compile, and
   `tests/hooks.sh`) and exits non-zero on any failure. `check_manifests`
   passes here, because both manifests still carry the released version and
   `CHANGELOG.md` has its section. `--strict` fails on warnings, and
   `--profile directory` runs the subset of the plugin directory's checks the
   CLI can see.

3. **Bump the versions.** Edit `"version"` to `X.Y.Z`, chosen per the rules
   above, in both `plugin.json` files. This is the change that makes the
   release real.

4. **Roll the changelog.** In `CHANGELOG.md`, rename the `[Unreleased]`
   heading to `## [X.Y.Z] - YYYY-MM-DD` with today's date, then open a fresh,
   empty `## [Unreleased]` heading above it for the next cycle.

5. **Re-run the gate on the bumped tree.** Run the four commands from step 2
   again. `check_manifests` must report `one shared version: X.Y.Z`; it fails
   when one `plugin.json` was not bumped or the changelog was not rolled.

6. **Commit and land it.** One commit for the bump plus the changelog roll,
   with an imperative subject and a conventional prefix (e.g.
   `chore: release vX.Y.Z`). Land it on `main`, then confirm
   `.github/workflows/ci.yml` is green on that exact SHA in all three of its
   jobs, `checks`, `hook-tests-macos`, and `plugin-validate`. Green on "a
   recent run" is not green on this SHA.

7. **Tag `main`.** Tag the gated SHA:

   ```
   git tag vX.Y.Z
   ```

   Use the pre-release ladder for anything not final:
   `vX.Y.Z-alpha.N` -> `vX.Y.Z-beta.N` -> `vX.Y.Z-rc.N` -> `vX.Y.Z`.

   `sutra-harness` depends on `sutra` with no version range, so it needs no
   other tag. A plugin that constrains a dependency's version resolves the
   range against `<plugin>--v<version>` tags; if another plugin ever pins
   Sutra, also run `claude plugin tag` in each plugin folder, which creates
   `sutra--vX.Y.Z` and `sutra-harness--vX.Y.Z` after checking the manifest.

8. **Push the tag.**

   ```
   git push origin vX.Y.Z
   ```

9. **Verify from a clean install.** In a throwaway environment (or after
   `/plugin marketplace remove sutra`), install from scratch and confirm the
   new version lands for both plugins:

   ```
   /plugin marketplace add avmnu-sng/sutra
   /plugin install sutra-harness@sutra
   ```

   The second command installs `sutra` as the harness's dependency. Then
   confirm an already-installed client picks the release up via
   `/plugin marketplace update sutra`. `claude plugin list` must report
   `X.Y.Z` for both. If it still shows the old version, step 3 was skipped or
   not pushed.

10. **Re-check the directory listing.** Only `sutra` is submitted to
    Anthropic's plugin directory; `sutra-harness` ships hooks, which the
    directory accepts only from Verified organizations. On `sutra`'s page in
    the developer portal (claude.ai/directory/manage), select **Check for new
    commits** so the directory scans the tagged commit now rather than at its
    next scheduled check. The portal runs checks and a security scan the CLI
    cannot; read the Versions tab and fix anything marked Blocks.

## The listing icon

`plugins/sutra/assets/icon.png` is rendered from the vector source
`docs/assets/sutra-icon.svg` (the directory accepts a square PNG or JPEG of
512 to 2048 px, not SVG), and `plugins/sutra-harness/assets/icon.png` is a
copy of it, so the harness validates without an icon warning:

```
rsvg-convert -w 512 -h 512 docs/assets/sutra-icon.svg -o plugins/sutra/assets/icon.png
cp plugins/sutra/assets/icon.png plugins/sutra-harness/assets/icon.png
```

The portal takes the icon from the first saved or submitted version only, so a
later change to the file has to be set in the developer portal as well.

## Do NOT

- **Do NOT** put a version in `marketplace.json`. It lives only in the two
  `plugin.json` files, and they match. Leave `marketplace.json` version-free.
- **Do NOT** reuse a version number. `update` is a no-op against an unchanged
  string, so a re-cut under the same version silently reaches no one. Bump,
  even for a one-line fix.
- **Do NOT** tag off a non-`main` branch. Sutra is trunk-based; tags live on
  `main` and point at the SHA that passed the gate.
- **Do NOT** move anything that runs into `plugins/sutra`. Hooks, scripts,
  workflows, and servers go in `plugins/sutra-harness`, or the directory
  refuses the release; `check_directory_policy` catches it first.
