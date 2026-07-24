# Handoff

<!-- TEMPLATE: copy this file, rename per session (e.g. ../handoffs/<slice-id>.md),
     and replace every <placeholder> and TODO. Delete guidance comments before committing.
     This is the evidence-bearing record a session leaves behind. Claims without pasted
     command output do not count -- if it is not in a fenced block below, it did not happen. -->

## Slice

- **Slice id:** <slice-id>
- **Final status:** DONE | BLOCKED  <!-- pick one; BLOCKED requires a Blocker section below -->
- **Date:** <YYYY-MM-DD>
- **Branch / commit:** <branch-name> @ <short-sha>

## Branch catalog

One row per branch this session touched, so the handoff doubles as branch tracking.
Keep the primary slice branch first; add rows for any spin-off or dependency branches.

| id | branch | sha | base | status |
| --- | --- | --- | --- | --- |
| <b1> | <branch-name> | <short-sha> | <base-branch> | open / merged / abandoned |
| <b2> | <branch-name> | <short-sha> | <base-branch> | open / merged / abandoned |

<!-- id: short local handle you reference elsewhere in this doc (b1, b2, ...).
     base: the branch this one forked from. status: pick one per row. -->

## What shipped

List the concrete surface that changed. Name symbols and files, not intentions.

- `<path/to/file>` -- <what changed and why>
- `<Module::Symbol>` / `<function_name()>` -- <new or modified behavior>
- <TODO: add one bullet per meaningful change; delete unused bullets>

## Deviations from the brief

What the brief asked for vs. what you actually did. If nothing deviated, say "None."

- **Planned:** <what the brief specified>
  **Actual:** <what you shipped instead>
  **Reason:** <why the change was necessary>
- <TODO: repeat per deviation, or replace this whole list with "None.">

## Pasted evidence

Paste real command output. Do not summarize or claim -- show the run. Each block below
must be actual terminal output, unedited except for trimming length with a clear `...` marker.

### Validation run

```
$ <command>
<TODO: paste the exact output that proves the acceptance criterion holds>
```

### Test results

```
$ <test-command>
<TODO: paste the pass/fail summary line and any relevant per-test output>
```

### Demo / behavior log

```
$ <demo-command>
<TODO: paste output showing the feature working end-to-end>
```

<!-- Add or remove evidence blocks as the slice needs. A BLOCKED status still requires
     pasted evidence of the failure -- the error, the stack trace, the failing assertion. -->

## Blocker (only if status is BLOCKED)

- **What is blocked:** <symbol / file / step>
- **Root cause (as understood):** <one-line diagnosis>
- **Evidence:** see the failing block above / <reference the specific fenced block>
- **What was tried:** <approaches attempted and their outcomes>
- **What is needed to unblock:** <decision, access, upstream fix, or scope change>

## Followups / new work discovered

Work surfaced during the session that is out of scope for this slice. File it here so it
is not lost; do not silently fold it into the next slice.

- <TODO: describe the followup, where it lives, and why it is separate>
- <TODO: add proposed slice id if known, else "unassigned">

## Defer surface updates

Reconcile the running list of deferrals. State each as an explicit close or carry-forward,
never a silent drop.

- **Closed:** <deferral-id / description> -- <how it was resolved this session>
- **Carried forward:** <deferral-id / description> -- <why, and the condition that reopens it>
- **New deferral:** <description> -- <the technical reason it is deferred, not "effort">
- <TODO: if the defer surface is unchanged, say "No changes.">

## Changelog entry

The one Keep-a-Changelog line this slice appends to CHANGELOG `[Unreleased]` now, at
handoff time -- so the release-time step is a rename of the `[Unreleased]` heading, nothing
more. Write it user-facing; internal churn does not earn a line.

- **Group:** <Added | Changed | Fixed | Removed | Deprecated | Security>  <!-- pick one -->
- **Entry:** <the user-facing bullet, phrased as shipped behavior>

<!-- If the slice ships nothing a user can observe, do not invent an entry. Instead: -->

- **None -- internal only:** <one-line justification for why no user-visible line applies>
