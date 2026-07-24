---
description: Use before open-sourcing or otherwise publishing your own code or docs -- remove secrets, credentials, and internal identifiers, and verify the scrub with a repeated search, so nothing private ships.
---

# Scrub before publish

Before you publish material you have the right to publish -- open-sourcing your
own repo, posting a sample, sharing a runbook -- remove the private details
first. This is a security and privacy pass, not a rewrite: you keep the
authorship, the license, and the substance; you strip the secrets and internal
identifiers that should never leave the building.

## Guardrail first: only publish what is yours to publish

This skill is for material you are authorized to release. It is NOT a way to
work around a restriction.

- A `CONFIDENTIAL`, `INTERNAL`, `DO NOT SHARE`, or NDA marking is a STOP SIGN,
  not a line to delete. If you find one, do not publish the material and do not
  strip the label -- get authorization or leave it internal.
- If the material belongs to an employer, a customer, or someone else, or you
  are unsure you have the right to release it, stop and confirm before going
  further.
- Scrubbing removes secrets from material you MAY publish. It is never a tool
  for laundering material you may not.

## What to remove

Search for and replace every private referent. Secrets are the highest
priority -- a leaked credential is an incident, not a nit.

- **Secrets and credentials** -- API keys, tokens, passwords, private keys,
  connection strings, `.env` values, signed URLs. If one ever reaches a public
  commit it must be rotated, so catch it before, not after.
- **Absolute machine paths** -- `/Users/<name>/...`, `/home/<name>/...`,
  `C:\Users\...`. Replace with a relative or generic path (`./config`,
  `/path/to/project`).
- **Usernames, handles, and personal names.**
- **Internal hostnames and IPs** -- laptop names, `*.internal`, `*.corp`,
  staging boxes, and private v4/v6 ranges.
- **Internal URLs** -- wikis, dashboards, issue trackers, artifact registries,
  short links.
- **Employer, customer, product, and service names** -- including codenames and
  insider shorthand. Replace with a neutral role name ("a backend event
  service", "the image-upload endpoint").
- **Email addresses.**
- **Account, tenant, and contract IDs; UUIDs** -- even expired or
  example-looking ones; a real-shaped ID invites a probe.

Replacement rules: pick one placeholder per real term and use it everywhere;
keep it generic enough that no reader can reverse it to the original; preserve
structure and drop identity -- a sample config should still parse, just with the
values swapped.

## Verify mechanically -- do not trust a mental scan

The person who scrubbed the material is blind to their own residue. For every
term you removed, search the WHOLE tree (not just the file you edited),
case-insensitively, and confirm zero matches. A term that survives in a sibling
file, a code comment, an example output, or git history is still a leak.
Iterate the search until it returns empty; one clean pass only counts if
nothing changed since the last one. (This is the `/sutra:verify-completeness`
discipline applied to leaks.)

## Independent second pass

Have a fresh reader or a dispatched agent (the `doc-sanitizer` subagent)
re-scan against the same list of terms. Treat every surviving secret or
identifier as blocking, fix it, and re-run. Check git history too -- a value
removed from the working tree can still sit in an earlier commit.

## Checklist

- [ ] Confirmed the material is yours to publish; no confidential/NDA marking
      overridden.
- [ ] Every secret and credential removed (and rotated if it ever hit a commit).
- [ ] Internal identifiers (paths, hosts, IPs, URLs, org/product names, emails,
      account IDs) genericized with stable placeholders.
- [ ] Whole-tree, case-insensitive search per term returns empty -- including
      comments, example output, and git history.
- [ ] Independent re-scan clean.

## Ties into the rest of sutra

- `/sutra:security-hygiene` keeps secrets out of source in the first place;
  this skill is the pre-publication backstop for what slipped through.
- `/sutra:verify-completeness` is the search-until-empty method this relies on.
- The `doc-sanitizer` subagent runs the independent second pass.
