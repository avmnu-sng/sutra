# Skills catalog

Twenty skills, several with overlapping trigger boundaries -- this map routes each task to the one skill that fits and names the sibling to reach for instead.

## Decision map

| Skill | Use it when (trigger) | Closest sibling | Pick the sibling instead when |
| --- | --- | --- | --- |
| `/sutra:effort-calibration` | Deciding how much energy -- tokens, agent fan-out, verification passes, independent attempts -- a task is worth before you commit to an approach. | `/sutra:agent-orchestration` | You have already decided to delegate and need to prompt and verify one subagent, not size the task's total spend. |
| `/sutra:architecture-review` | Assessing a backend or service design for scale, resource fit, and cost -- trace requests, stress each component, model 2x/5x/10x load, quantify ROI. | `/sutra:audit-and-remediation` | The code already exists and you need a prioritized, sequenced fix backlog, not a forward-looking design verdict. |
| `/sutra:performance-profiling` | Chasing a real bottleneck on a running system -- run the empirical measure -> optimize -> re-measure -> ratchet loop against live measurements until the gain sticks. | `/sutra:architecture-review` | You are modeling 2x/5x/10x load on a design before it is built; pick architecture-review before building, this after, against real measurements. |
| `/sutra:audit-and-remediation` | Auditing an existing codebase and sequencing the fixes -- produce a structured audit, prioritize across lenses, assign items to parallel work lanes. | `/sutra:architecture-review` | You are evaluating a proposed or not-yet-built design for where it breaks under load, not cataloguing defects in shipped code. |
| `/sutra:scaffold-execution-plan` | Starting a large multi-session build and you need the `execution_plan/` tree that `/sutra-harness:build-orchestrator` runs on. | `/sutra:multi-session-build` | The scaffold exists and you need the honesty gates and methodology for running the build, not the file structure. |
| `/sutra:multi-session-build` | Running a large build across many sessions or agents and you need gates that keep the assembled, deployed system honest -- claims-vs-built ledger, independent completeness gate. | `/sutra:scaffold-execution-plan` | You are laying down the `execution_plan/` tree and orchestrator for the first time, not enforcing the discipline that runs it. |
| `/sutra:debugging` | Isolating a defect systematically -- contain a live incident first, then reproduce, hypothesize, bisect, and confirm the mechanism. | `/sutra:test-authoring` | The mechanism is already understood and you want a durable regression guard, not a diagnosis of an unknown failure. |
| `/sutra:test-authoring` | Writing, strengthening, or debugging tests -- read the source of truth before asserting, ship real assertions, never weaken a test to go green. | `/sutra:verify-completeness` | You are sweeping the codebase for every instance of a pattern and re-searching until empty, not authoring a regression test. |
| `/sutra:data-migration` | Making a safe schema change or data migration on a live system -- plan and sequence expand/contract steps so the change stays reversible and non-breaking. | `/sutra:debugging`, `/sutra:test-authoring` | You are diagnosing an unknown defect (debugging) or writing a durable regression guard (test-authoring), not sequencing an expand/contract migration for safety. |
| `/sutra:verify-completeness` | Finishing a cleanup or find-and-fix sweep where one missed instance is costly -- enumerate every match, fix each, and re-search until empty. | `/sutra:test-authoring` | You want a test that catches the class of bug on every future run, not a one-time exhaustive pass over the current tree. |
| `/sutra:agent-orchestration` | Deciding whether to delegate to a subagent and how to prompt, verify, and integrate the output of the one delegate you chose. | `/sutra:parallel-agent-orchestration` | Many agents run concurrently against shared files, branches, or trees and you need an isolation regime and coordination protocol. |
| `/sutra:parallel-agent-orchestration` | Running multiple agents or sessions concurrently against shared state and you must stop two writers from corrupting the same file, branch, or working tree. | `/sutra:agent-orchestration` | You are dispatching a single delegate and the question is how to prompt and verify it, not how to coordinate many. |
| `/sutra:commit-craft` | Writing or revising a commit message, splitting work into commits, or structuring a branch so a future `git blame` reader understands the change. | `/sutra:style-audit` | You are checking the changed files' contents against house style, not composing the commit or branch narrative. |
| `/sutra:style-audit` | Auditing a code or doc change against house style -- why-not-what comments, current-state docs, symbol references, safe Mermaid, and (on the strict profile / when your project enforces it) ASCII-only files -- when finishing a diff. | `/sutra:scrub-before-publish` | The material is being published and you must remove secrets and internal identifiers, not just enforce style. |
| `/sutra:scrub-before-publish` | Publishing your own code or docs and needing to remove secrets, credentials, and internal identifiers first -- and confirm the material is yours to release. | `/sutra:style-audit` | The material stays internal and you only need house-style conformance, not a pre-publish scrub. |
| `/sutra:security-hygiene` | Hardening dependency, supply-chain, lockfile, and secret hygiene and triaging advisories -- vet a bumped dependency, audit a lockfile, scan for committed secrets, weigh an advisory's real exposure. | `/security-review`, `/sutra:scrub-before-publish`, `/sutra:agent-security` | You want a diff-level vulnerability review of pending code changes (`/security-review`), a pre-publish secret scrub of material you are about to publish (`/sutra:scrub-before-publish`), or a vetting of a plugin, MCP server, or skill you are about to install (`/sutra:agent-security`), not dependency and supply-chain hygiene. |
| `/sutra:agent-security` | Installing or updating a plugin, MCP server, or skill; letting an agent with tools read untrusted content (issues, pull requests, web pages, email); configuring permissions or the sandbox; running agents headless or in CI; or reviewing agent edits to CI workflows, hooks, settings, `.mcp.json`, or agent instruction files -- the threat model for agent tooling plus a vetting checklist. | `/sutra:security-hygiene` | You are vetting a package dependency, a lockfile diff, a committed secret, or an advisory, not an extension that runs inside the agent or the content it reads. |
| `/sutra:agent-docs-architecture` | Structuring or auditing a repo's agent-facing docs -- entry docs, shared rulebook, routing and handoff tables, skill ordering, source-of-truth designation. | `/sutra:hooks-cookbook` | You need an executable check that enforces behavior at tool boundaries, not doc structure that agents read and navigate. |
| `/sutra:hooks-cookbook` | Authoring a Claude Code hook -- a PreToolUse, PostToolUse, SessionStart, or UserPromptSubmit checker -- with a fail-open skeleton and advisory-vs-blocking recipes. | `/sutra:agent-docs-architecture` | You are organizing the docs agents read to orient themselves, not writing a hook that enforces a rule. |
| `/sutra:retro-and-memory` | Closing a work session, hitting a periodic meta-review cadence, or recording a durable lesson -- run a probe-backed retro, reconcile outside critique, and capture the lessons that survive. | `/sutra:multi-session-build` | You are setting up the honesty gates for a long build up front, not running the end-of-work retro and memory fold. |

## The four confusable pairs

These four collisions cause the most misroutes. Memorize the split.

- **`/sutra:agent-orchestration` vs `/sutra:parallel-agent-orchestration`** -- agent-orchestration is how to prompt and verify a delegate you chose; parallel-agent-orchestration is coordinating MANY concurrent agents against shared state.
- **`/sutra:architecture-review` vs `/sutra:audit-and-remediation`** -- architecture-review is design-time (will it scale, where does it break); audit-and-remediation is auditing EXISTING code and sequencing the fixes.
- **`/sutra:verify-completeness` vs `/sutra:test-authoring`** -- verify-completeness iterates a search or sweep until empty; test-authoring writes tests that catch regressions.
- **`/sutra:multi-session-build` vs `/sutra:scaffold-execution-plan`** -- multi-session-build is the gates that keep a long build honest; scaffold-execution-plan lays down the `execution_plan/` tree that `/sutra-harness:build-orchestrator` runs on.

## How the pieces compose

A typical build runs the skills in sequence:

```
effort-calibration        how much energy the task is worth
   -> architecture-review OR scaffold-execution-plan   plan the work
   -> build
   -> debugging / test-authoring    make it correct
   -> verify-completeness           confirm it is clean
   -> commit-craft                  land it
```

Around that spine:

- **Delegation machinery.** `/sutra:agent-orchestration` (one delegate) and `/sutra:parallel-agent-orchestration` (many concurrent) supply the prompting, verification, and isolation rules; the build-orchestrator workflow (see `plugins/sutra-harness/workflows/README.md`) drives the build -> review -> fix -> validate -> retro loop per slice.
- **Brownfield entry.** On existing code, `/sutra:audit-and-remediation` replaces architecture-review at the plan stage and feeds sequenced fixes into the same build loop.
- **Long builds.** `/sutra:multi-session-build` wraps the whole spine with honesty gates when the work spans many sessions; `/sutra:scaffold-execution-plan` lays down the structure it runs on.
- **Performance work.** `/sutra:performance-profiling` runs the measure -> optimize -> re-measure -> ratchet loop against the running system -- the after-it-is-built, empirical counterpart to architecture-review's design-time load modeling.
- **Schema and data changes.** `/sutra:data-migration` sequences expand/contract steps so a live schema change or data migration stays reversible and non-breaking.
- **Security and supply chain.** `/sutra:security-hygiene` vets dependencies, lockfiles, and secrets and triages advisories -- distinct from the built-in `/security-review`'s diff-level vulnerability pass. `/sutra:agent-security` covers the agent's own attack surface: the plugins, MCP servers, and skills you install, the untrusted content the agent reads, its permissions and sandbox, headless and CI runs, and agent edits to CI, hooks, and settings.
- **Finishing and publishing.** `/sutra:style-audit` checks the diff against house style before commit-craft; `/sutra:scrub-before-publish` runs before you open-source or otherwise publish the material.
- **Repo setup.** `/sutra:agent-docs-architecture` and `/sutra:hooks-cookbook` configure the environment agents operate in, ahead of any single task.
- **Closing the loop.** `/sutra:retro-and-memory` ends the session -- a probe-backed retro folded into durable memory so the next run starts smarter.
