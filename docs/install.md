# Installing Sutra

Sutra is a Claude Code plugin. This guide covers the recommended no-clone
install, how to select an operating profile, local development, and how to
keep the operating contract in a repo for teammates who do not run the
plugin.

## Requirements

- A current build of Claude Code -- recent enough to expose the `/plugin`
  command and the plugin marketplace flow.
- `bash` 3.2 or later and `perl` with its core JSON::PP module on your PATH,
  both present by default on macOS and most Linux distributions. Every hook
  except PreCompact uses perl to read the hook payload and write its output;
  without perl the contract and the compaction brief are still printed as
  plain text and every other hook stays silent.

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

After installation, run `/reload-plugins` or start a new session to load the
skills; they appear as `/sutra:<name>`, for example
`/sutra:architecture-review`. The operating contract arrives with the next
SessionStart event (a new or resumed session, `/clear`, or a compaction),
because the SessionStart hook is what adds it.

## Selecting a profile

Sutra ships several operating profiles. Pick one of `lite`, `standard`,
`strict`, or `off`. The default is `standard`.

The profile is resolved in this order, first match wins:

1. The `SUTRA_PROFILE` environment variable in your shell:

   ```
   export SUTRA_PROFILE=strict
   ```

2. The plugin's `profile` setting, a `userConfig` option that Claude Code
   passes to the hooks as `CLAUDE_PLUGIN_OPTION_PROFILE`.
   `claude plugin configure sutra` shows it. Empty means unset. To set it:

   ```
   printf '{"profile":"strict"}' | claude plugin configure sutra --values-stdin
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
by importing its layers into their `CLAUDE.md`. Clone or add the repo as a
git submodule, then add `@import` lines for the layers, in order. For
`standard`:

```
@<path>/plugins/sutra/profiles/core.md
@<path>/plugins/sutra/profiles/standard.md
```

Replace `<path>` with the local path to your clone or submodule. Each file is
one layer: import `core.md` alone for `lite`, and add
`@<path>/plugins/sutra/profiles/strict.md` after both for `strict`. An import
carries the contract text only; the rule cards, the security floor, and the
strict stop gate come from the plugin's hooks.

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
