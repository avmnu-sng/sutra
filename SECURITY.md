# Security policy

## Supported versions

Security fixes go into the latest minor release only. Earlier releases are not
patched, so update before you report, and check that the problem is still
there.

| Version | Supported |
| --- | --- |
| The latest minor release (the newest `X.Y` in [CHANGELOG.md](CHANGELOG.md)) | Yes |
| Every earlier release | No |

`claude plugin list` shows the version you have installed.

## Reporting a vulnerability

Report it privately through GitHub's private vulnerability reporting:

1. Go to https://github.com/avmnu-sng/sutra.
2. Open the **Security** tab.
3. Select **Report a vulnerability** and fill in the form.

Do not open a public issue, pull request, or discussion about it. If
**Report a vulnerability** is not shown, open an issue that asks for a private
contact and says nothing about the problem.

Include what you can of:

- the Sutra version, and the file or component affected;
- your Claude Code version, operating system, and `bash` and `perl` versions;
- the steps or the smallest input that reproduces it -- for the hook, the
  event, the payload, and the environment variables set; and
- what an attacker gains, and what they must control first: a repository you
  open, a page Claude fetches, a file name, or your environment.

## Scope

Sutra is two plugins: `sutra` (skills and subagents) and `sutra-harness`
(hooks, contract, cards, and the workflow). Both are in scope.

In scope:

- **The hook dispatcher**, `plugins/sutra-harness/hooks/sutra.sh`, and its
  wiring in `plugins/sutra-harness/hooks/hooks.json`. For example: running a
  command, reaching the network, or writing outside the plugin data directory
  through a crafted payload, file, or file name; a repository lowering the
  profile or turning off the security floor through `.sutra`; text breaking
  out of the hook's JSON output; or a character in the documented set that
  the scan misses.
- **The bundled workflow**,
  `plugins/sutra-harness/workflows/build-orchestrator.workflow.js`.
- **The examples** in `examples/`, where copying one as documented weakens a
  user's security.
- **CI**, the workflows in `.github/workflows/`.
- **The instructions Sutra ships** -- profiles, rule cards, skills, and
  subagents -- where following one as written exposes a user, such as a
  command that runs a file name as code.

Out of scope:

- **Claude Code itself.** Report it to Anthropic through the HackerOne
  program named in the Claude Code security documentation:
  https://code.claude.com/docs/en/security#reporting-security-issues
- Other plugins, MCP servers, and marketplaces: report to their maintainers.
- The limits that [docs/security.md](docs/security.md) documents under
  residual risk and the plugin data directory, such as Sutra warning instead
  of blocking, a character outside the documented set, or a symbolic link
  planted in that directory, unless the code does not do what the page says.
  Proposals to narrow a limit are welcome as ordinary issues.
- Copies of the workflow or the examples that you have changed.

## What to expect

- An acknowledgment, then an assessment: whether the report reproduces, how
  severe it is, and whether it is in scope.
- Progress and questions in the private advisory, which stays the channel for
  both sides until the fix is out.
- A fix in a new release, recorded under `### Security` in
  [CHANGELOG.md](CHANGELOG.md), and the advisory published with credit to you
  unless you prefer not to be named.

There is no guaranteed response time. Please keep the details private until
the fixed release is published.
