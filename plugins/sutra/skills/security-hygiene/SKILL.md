---
description: Use when adding or upgrading a package dependency, reviewing a lockfile diff, handling a security advisory, provisioning tokens or secrets, or vetting supply-chain risk -- the standing-liability angles that a diff-level vuln scan does not cover.
---

# Security hygiene

Run `/security-review` first for what it owns: it reads the working diff for
injected vulnerabilities -- SQL injection, unsafe deserialization, path
traversal, secrets committed in this change. That is diff-level review of code
you wrote.

This skill covers the angles it does not: the standing liabilities you take on
around the code -- dependencies, lockfiles, credentials, advisories, and the
supply chain that delivers all of them. A clean diff can still pull in a
compromised package, widen a token's scope, or ignore a live advisory. Those
never show up in a diff scan.

Security work sits at the T3 verification floor (see `/sutra:effort-calibration`):
stakes force the full floor no matter how small the change looks. Adding one
line to a manifest is a one-line diff and a T3 decision. Do not let diff size
talk you out of the floor.

## The agent surface: /sutra:agent-security

Plugins, MCP servers, and skills; prompt injection through content an agent
reads; and Claude Code permissions and the sandbox make up the agent surface,
and `/sutra:agent-security` covers it. Vet a plugin, MCP server, or skill there
before you install it. This skill covers the packages, lockfiles, credentials,
and advisories around your code, and does not repeat that material.

## 1. Vet a dependency BEFORE you add it

A dependency is a standing liability, not a free function. You inherit its
code, its transitive tree, its maintainers, and its future bugs. Vet before
adding -- removal after the fact is far more expensive.

Check four things and record the answers:

- **Transitive blast radius.** What else does it pull in? Resolve the full
  transitive tree, not just the direct package. A three-line helper that drags
  in forty transitive packages is forty liabilities, not one. Prefer a smaller
  tree; prefer writing the three lines yourself when the tree is absurd.
- **Maintenance health.** When was the last release? Are there open critical
  issues with no maintainer response? What is the bus factor -- one unpaid
  maintainer, or a funded team? A package last released four years ago with
  open CVEs is abandonware.
- **License compatibility.** Confirm the license is compatible with your
  project's distribution terms. A copyleft dependency in a permissively
  licensed product is a legal defect, not a nit. Check the transitive tree's
  licenses too, not just the direct one.
- **Known advisories.** Query the advisory database for the exact version you
  intend to pin. A package with an unpatched high-severity advisory does not
  enter the tree until the advisory is resolved or you have a recorded
  mitigation.

If any check fails and you still need the capability, write the decision down
(Step 4) -- do not add silently.

## 2. Lockfile discipline

The lockfile is the source of truth for what actually ships. Treat its diffs
with the same scrutiny as source.

- **Pin versions in applications; range them in libraries.** Pin exact
  versions for deployed applications so builds are reproducible -- otherwise an
  upstream publish changes your artifact with no diff on your side. A published
  library should express compatible ranges instead -- pinning exact versions in
  a library breaks downstream resolution (diamond-dependency conflicts).
- **Review lockfile diffs.** Read every lockfile change. A lockfile change
  with no corresponding manifest change is a red flag -- something resolved
  differently, and you did not ask for it. Find out why before merging.
- **Prefer integrity hashes.** Use the lockfile's integrity-hash mechanism so
  a tampered artifact at fetch time fails the build instead of installing.
- **Regenerate deliberately.** Regenerate the lockfile as an intentional,
  reviewed act. Never blind-accept a machine-regenerated lockfile in a merge
  -- read what moved and why.

## 3. Least privilege, zero static secrets

Every credential is blast radius. Size it to the exact job and make it
short-lived.

- **Scope tokens and roles to exact permissions.** Grant the specific actions
  needed on the specific resources needed -- read on one bucket, not admin on
  the account. A token that can do more than its job is a bigger incident when
  it leaks.
- **Prefer short-lived credentials over static keys.** Use rotating,
  expiring credentials over long-lived static keys wherever the platform
  supports it. A leaked static key is valid until someone notices; a
  short-lived one expires on its own.
- **Keep secrets out of source and out of logs.** No secret in a committed
  file, no secret echoed into a log line or an error message. Route through a
  secret manager or injected environment, and scrub before any output leaves
  the process. To catch secrets before publishing a doc, transcript, or paste,
  run `/sutra:scrub-before-publish` -- removing secrets is its top priority.

## 4. Triage an advisory -- never silently ignore

When an advisory lands against something you depend on, decide deliberately.
"Ignore it and hope" is not a decision.

1. **Reachability.** Is the vulnerable code path actually reachable in your
   usage? A flaw in a code path you never call is lower urgency than one on
   your hot path -- but confirm reachability, do not assume it.
2. **Severity against exploitability.** Weigh the rated severity against how
   exploitable it is in your context: network-reachable versus local-only,
   authenticated versus anonymous, default config versus an option you never
   set.
3. **Act and record.** Choose one and write it down: **patch** (upgrade to
   the fixed version), **mitigate** (config change, input validation, or a
   compensating control), or **accept** with a recorded, dated decision and a
   revisit trigger. Silent inaction is the one option this step forbids.

## 5. Supply-chain red flags

These signals mean stop and investigate before installing or building:

- **Typosquatted names.** A package name one character off a popular one, or a
  scope that impersonates a known publisher. Confirm you are installing the
  package you meant.
- **Sudden maintainer handoff.** Ownership of a package transferred to an
  unknown account right before a release. A quiet handoff is a classic vector
  for slipping malicious code into a trusted name.
- **Unexpected post-install script.** An install-time hook that runs code
  during `install` when the package has no reason to. Post-install scripts run
  with your privileges -- read what they do.
- **Build reaches the network.** A build or install step that opens network
  connections when it should be offline -- exfiltration or fetching a
  second-stage payload. A pure library build should not phone home.

## Checklist

- [ ] `/security-review` run for the working diff; this skill run for the
      dependency, credential, and supply-chain surface it does not cover.
- [ ] Every new or upgraded dependency vetted on all four axes: transitive
      tree, maintenance health, license, advisories.
- [ ] Versions pinned; lockfile diff read line by line; no lockfile change
      without a manifest reason; integrity hashes on.
- [ ] Every token or role scoped to exact permissions; short-lived over
      static; no secret in source or logs.
- [ ] Every live advisory triaged for reachability and exploitability, then
      patched, mitigated, or accepted with a recorded decision.
- [ ] Package names, maintainer changes, install scripts, and build network
      access checked for supply-chain red flags.
- [ ] The whole review treated at the T3 floor, not sized down to the diff.

## Ties into the rest of sutra

- `/security-review` is the companion: it owns the working diff, this skill
  owns the standing liabilities around it. Run both.
- `/sutra:effort-calibration` sets why this is T3 -- security is an
  irreversible/high-stakes surface, so the verification floor holds regardless
  of change size.
- `/sutra:scrub-before-publish` is where the pre-publication secret scrub lives
  before code or docs leave your machine.
- `/sutra:agent-security` owns the agent surface; this skill owns the packages
  and credentials around your code.
