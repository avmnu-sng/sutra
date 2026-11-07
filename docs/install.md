# Installing Sutra

Sutra is two Claude Code plugins from one marketplace:

- `sutra` -- twenty methodology skills and four read-only subagents. Markdown
  only: nothing in it runs on its own.
- `sutra-harness` -- the parts that run automatically: the operating contract
  at session start, rule cards, hidden-Unicode warnings, the compaction brief,
  the strict verify-before-stop nudge, and the build-orchestrator workflow. It
  depends on `sutra`, so installing it installs both.

This guide covers the recommended no-clone install, how to select an
operating profile, local development, and how to keep the operating contract
in a repo for teammates who do not run the plugins.

## Requirements

- A current build of Claude Code -- recent enough to expose the `/plugin`
  command and the plugin marketplace flow.
- For `sutra-harness` only: `bash` 3.2 or later and `perl` with its core
  JSON::PP module on your PATH, both present by default on macOS and most
  Linux distributions. Every hook except PreCompact uses perl to read the hook
  payload and write its output; without perl the contract and the compaction
  brief are still printed as plain text and every other hook stays silent.

Nothing else is required for the recommended install.

## Recommended install (no clone)

Run these two commands inside Claude Code:

```
/plugin marketplace add avmnu-sng/sutra
```

Registers the Sutra marketplace with your Claude Code install. This tells
Claude Code where to find the plugins; it does not install anything on its
own.

```
/plugin install sutra-harness@sutra
```

Installs the harness and, as its dependency, the `sutra` skills plugin from
the same marketplace. In Claude Code 2.1.275 or later, one command does both
steps: `/plugin install sutra-harness --marketplace avmnu-sng/sutra`.

For the skills and subagents alone, with no hooks, install `sutra@sutra`
instead. The harness depends on `sutra` from this marketplace and installs it
there. If `claude plugin list` already shows `sutra` from another source, keep
one copy: uninstall one from another marketplace with
`claude plugin uninstall sutra@<marketplace>`, or disable one synced from
claude.ai (`sutra@synced`) in the `/plugin` Installed tab.

After installation, run `/reload-plugins` or start a new session to load the
skills; they appear as `/sutra:<name>`, for example
`/sutra:architecture-review`. The operating contract arrives with the next
SessionStart event (a new or resumed session, `/clear`, or a compaction),
because the harness's SessionStart hook is what adds it.

## If only `sutra` is installed

`sutra` alone carries the skills and subagents. The contract, the rule cards,
the security floor, the strict stop gate, and the
`/sutra-harness:build-orchestrator` workflow come from `sutra-harness`. If
`claude plugin list` shows `sutra@sutra` but not `sutra-harness@sutra`, add the
harness:

```
/plugin marketplace update sutra
/plugin install sutra-harness@sutra
```

The harness has its own `profile` setting; see below.

## Selecting a profile

Profiles are a harness feature; with only `sutra` installed there is no
contract to select. Pick one of `lite`, `standard`, `strict`, or `off`. The
default is `standard`.

The profile is resolved in this order, first match wins:

1. The `SUTRA_PROFILE` environment variable in your shell:

   ```
   export SUTRA_PROFILE=strict
   ```

2. The harness's `profile` setting, a `userConfig` option that Claude Code
   passes to its hooks as `CLAUDE_PLUGIN_OPTION_PROFILE`.
   `claude plugin configure sutra-harness@sutra` shows it. Empty means unset. To
   set it:

   ```
   printf '{"profile":"strict"}' | claude plugin configure sutra-harness@sutra --values-stdin
   ```

3. The default, `standard`.

A project can also place a `.sutra` file at its root containing just a
profile name -- one line, no quotes:

```
strict
```

It applies only when neither of your own settings is set, and only to raise
the profile to `strict`. A repository can never lower the profile or turn
Sutra off; Sutra refuses such a `.sutra` and tells you at session start.

Profiles at a glance (each adds a layer to the one before):

- `lite` -- the core contract: trace before theorizing, verify by running,
  match the surrounding code, and the security rules. No rule cards except
  the security floor's untrusted-content card.
- `standard` -- the core plus the standard stance, and short rule cards when
  they apply (commits, publishing, migrations, test, doc, and code edits,
  delegation).
- `strict` -- everything in `standard` plus a house style, an ASCII notice on
  writes, and one verify-before-stop request when a file that is not a doc
  changed and no check command ran since.
- `off` -- no contract, cards, or stop gate. The security floor
  (hidden-Unicode warnings and the untrusted-content card) still runs; only
  `SUTRA_SECURITY=off` turns it off.

## Local development (try before you install)

To try Sutra without installing it, or to hack on the plugins themselves,
clone the repo and point Claude Code at the folder that holds both plugins:

```
git clone https://github.com/avmnu-sng/sutra
claude --plugin-dir ./sutra/plugins
```

A `--plugin-dir` that is not itself a plugin loads each plugin inside it
(Claude Code 2.1.265 or later). On older builds, pass one flag per plugin:
`--plugin-dir ./sutra/plugins/sutra --plugin-dir ./sutra/plugins/sutra-harness`.
Load `sutra` whenever you load the harness: without its dependency, Claude
Code disables `sutra-harness`. `--plugin-dir` loads the plugins straight from
your working tree, so your edits are live without going through the
marketplace.

After you change a plugin file, reload it in the running session:

```
/reload-plugins
```

## Keeping the operating contract in your repo

Teammates who do not run the plugins can still share the operating contract
by importing its layers into their `CLAUDE.md`. Clone or add the repo as a
git submodule, then add `@import` lines for the layers, in order. For
`standard`:

```
@<path>/plugins/sutra-harness/profiles/core.md
@<path>/plugins/sutra-harness/profiles/standard.md
```

Replace `<path>` with the local path to your clone or submodule. Each file is
one layer: import `core.md` alone for `lite`, and add
`@<path>/plugins/sutra-harness/profiles/strict.md` after both for `strict`. An
import carries the contract text only; the rule cards, the security floor,
and the strict stop gate come from the harness's hooks.

Important: Claude Code `@import` is LOCAL-PATH ONLY. It resolves a file on
disk; it does not fetch over the network. A bare line like
`use github.com/avmnu-sng/sutra` is not fetched and does nothing -- the
file must already exist locally, which is why cloning or submoduling is
required for this path. If you want the network-free, no-clone experience,
install the plugins instead.

## Updating

Pull the latest marketplace metadata and plugin versions:

```
/plugin marketplace update sutra
```

A marketplace added at a tag, such as `avmnu-sng/sutra#v0.3.0`, stays on that
tag when you update it. To move to a newer release, remove the marketplace,
add it again at the new tag, and install again. Removing a marketplace
uninstalls the plugins you installed from it, so set the `profile` setting
again afterwards if you had set it:

```
/plugin marketplace remove sutra
/plugin marketplace add avmnu-sng/sutra#vX.Y.Z
/plugin install sutra-harness@sutra
```

## Removing

Uninstall the harness, and with `--prune` the `sutra` copy it installed as a
dependency:

```
claude plugin uninstall sutra-harness@sutra --prune
```

`--prune` removes only what Claude Code installed as a dependency. A `sutra`
you installed yourself stays; remove it with `/plugin uninstall sutra@sutra`
once the harness is gone, since the harness needs it while installed. Leaving
out `--prune` keeps a dependency-installed `sutra` only until the next prune:
`claude plugin prune`, or any later `uninstall --prune`, removes it. To keep
just the skills, uninstall the harness with `--prune`, then run
`/plugin install sutra@sutra`, so that `sutra` counts as installed by you.

## Validating (for contributors)

If you are contributing to Sutra, run the checks and validate the manifests
before opening a pull request:

```
bash scripts/check.sh
claude plugin validate --strict .
claude plugin validate --strict ./plugins/sutra-harness
claude plugin validate --strict --profile directory ./plugins/sutra
```

`scripts/check.sh` runs what CI runs, including the hook tests and the gate
that keeps `plugins/sutra` within the plugin directory's file rules. The
`validate` commands check the marketplace at the repo root, the harness, and
the skills plugin with the plugin directory checks the CLI can run. `--strict`
turns validation warnings into failures, and with `--profile directory` the
plugin directory's warnings too.
