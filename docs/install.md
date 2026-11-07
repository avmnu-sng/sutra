# Installing Sutra

Sutra is a Claude Code plugin. This guide covers the recommended no-clone
install, how to select an operating profile, local development, and how to
keep the operating contract in a repo for teammates who do not run the
plugin.

## Requirements

- A current build of Claude Code -- recent enough to expose the `/plugin`
  command and the plugin marketplace flow.
- `perl` on your PATH. The strict ASCII guard shells out to `perl`; it is
  present by default on macOS and most Linux distributions.

Nothing else is required for the recommended install.

## Recommended install (no clone)

Run these two commands inside Claude Code:

```
/plugin marketplace add avmnu-sng/sutra
```

Registers the Sutra marketplace with your Claude Code install. This tells
Claude Code where to find the plugin; it does not install anything on its
own.

```
/plugin install sutra@sutra
```

Installs the `sutra` plugin from the `sutra` marketplace you just added.

After installation, start a new session (or restart Claude Code). The
skills then appear as `/sutra:<name>` -- for example
`/sutra:architecture-review`. They
will not show up mid-session; the next session start is what registers
them.

## Selecting a profile

Sutra ships several operating profiles. Pick one of `lite`, `standard`,
`strict`, or `off`. The default is `standard`.

There are two ways to select a profile:

1. Set the `SUTRA_PROFILE` environment variable in your shell:

   ```
   export SUTRA_PROFILE=strict
   ```

2. Place a `.sutra` file at a project root containing just the profile
   name -- one line, no quotes:

   ```
   strict
   ```

Precedence: a project `.sutra` file overrides the unset default, and the
`SUTRA_PROFILE` environment variable overrides the `.sutra` file. In short,
env wins over file, file wins over nothing set.

Profiles at a glance:

- `lite` -- the lightest contract; minimal guardrails, maximum latitude.
- `standard` -- the balanced default; sensible guardrails for everyday
  work.
- `strict` -- the tightest contract; the most guardrails and the least
  latitude.
- `off` -- disables the operating contract entirely.

## Local development (try before you install)

To try Sutra without installing it, or to hack on the plugin itself, clone
the repo and point Claude Code at the plugin directory:

```
git clone https://github.com/avmnu-sng/sutra
claude --plugin-dir ./sutra/plugins/sutra
```

`--plugin-dir` loads the plugin straight from your working tree, so your
edits are live without going through the marketplace.

After you change a plugin file, reload it in the running session:

```
/reload-plugins
```

## Keeping the operating contract in your repo

Teammates who do not run the plugin can still share its operating contract
by importing a profile into their `CLAUDE.md`. Clone or add the repo as a
git submodule, then add an `@import` line pointing at the profile file:

```
@<path>/plugins/sutra/profiles/standard.md
```

Replace `<path>` with the local path to your clone or submodule (swap
`standard.md` for whichever profile you want).

Important: Claude Code `@import` is LOCAL-PATH ONLY. It resolves a file on
disk; it does not fetch over the network. A bare line like
`use github.com/avmnu-sng/sutra` is not fetched and does nothing -- the
file must already exist locally, which is why cloning or submoduling is
required for this path. If you want the network-free, no-clone experience,
install the plugin instead.

## Updating

Pull the latest marketplace metadata and plugin version:

```
/plugin marketplace update sutra
```

## Removing

Uninstall the plugin:

```
/plugin uninstall sutra@sutra
```

## Validating (for contributors)

If you are contributing to Sutra, validate the plugin manifest before
opening a pull request:

```
claude plugin validate --strict .
claude plugin validate --strict --profile directory ./plugins/sutra
```

The first validates the marketplace at the repo root; the second validates
the plugin package itself, including the plugin directory checks the CLI can
run. `--strict` turns warnings into failures.
