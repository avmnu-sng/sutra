// build-orchestrator.workflow.js
//
// A resumable, multi-session build orchestrator for Claude Code Workflows.
// It reads a value-ranked execution plan from the repo and drives every
// pending slice through a fixed pipeline: build -> adversarial review ->
// bounded fix -> independent validation -> retro. One slice is one PR-sized
// deliverable. Work is committed per slice and never pushed.
//
// PREREQUISITES
//   1. An execution_plan/ tree checked into the repo. At minimum:
//        execution_plan/sessions/INDEX.md   -- value-ranked slice index
//        execution_plan/sessions/briefs/<id>.md -- one brief per slice
//      INDEX.md lists slices in priority order with a status column
//      (PENDING | IN_PROGRESS | BLOCKED | DONE) and, per slice, an id, a
//      title, acceptance criteria, and the path to its brief.
//   2. A dedicated build branch already checked out -- NOT the default
//      branch. This workflow commits per slice and never pushes.
//
// RESUME
//   Re-run the workflow. The intake agent re-reads INDEX.md and the status
//   filter drops every slice already marked DONE, so finished work is
//   skipped and the run continues from the first pending slice. A slice
//   left BLOCKED stays in the queue until it validates clean.
//
// ADAPT
//   The control flow is the reusable part. The stage prompts, schema shapes,
//   and status vocabulary are starting points -- edit them to match your own
//   plan format. To build slices truly in parallel without them colliding in
//   one working tree, give the build/fix/retro stages isolation: "worktree"
//   (each agent then runs in its own git worktree); this reference keeps a
//   single shared tree for clarity.

export const meta = {
  name: "build-orchestrator",
  description:
    "Resumable multi-session build loop: read a value-ranked execution " +
    "plan, then build -> review -> fix -> validate -> retro each pending " +
    "slice on a dedicated branch, committing per slice and never pushing.",
  phases: [
    { title: "Plan intake" },
    { title: "Build" },
    { title: "Adversarial review" },
    { title: "Bounded fix" },
    { title: "Independent validation" },
    { title: "Retro and handoff" },
  ],
};

// Structured return shapes as JSON Schema. Forcing machine-readable output
// lets a stage branch on the result instead of parsing prose. Swap the
// fields to match your plan format.
const sliceListSchema = {
  type: "object",
  required: ["slices"],
  properties: {
    slices: {
      type: "array",
      items: {
        type: "object",
        required: ["id", "title", "status", "acceptance_criteria", "brief_path"],
        properties: {
          id: { type: "string" }, // stable identifier, e.g. "S-01"
          title: { type: "string" },
          status: { type: "string" }, // PENDING | IN_PROGRESS | BLOCKED | DONE
          acceptance_criteria: { type: "array", items: { type: "string" } },
          brief_path: { type: "string" }, // brief path under execution_plan/
        },
      },
    },
  },
};

const reviewSchema = {
  type: "object",
  required: ["blocking", "findings"],
  properties: {
    blocking: { type: "boolean" }, // true when a finding must be fixed first
    findings: {
      type: "array",
      items: {
        type: "object",
        required: ["severity", "summary", "failure_scenario", "location"],
        properties: {
          severity: { type: "string" }, // blocker | major | minor
          summary: { type: "string" },
          failure_scenario: { type: "string" }, // inputs/state -> wrong behavior
          location: { type: "string" }, // file:line
        },
      },
    },
  },
};

const validationSchema = {
  type: "object",
  required: ["verdict", "unmet_criteria"],
  properties: {
    verdict: { type: "string" }, // DONE | BLOCKED
    unmet_criteria: { type: "array", items: { type: "string" } }, // empty when DONE
    notes: { type: "string" },
  },
};

// Every subagent starts here. STEP ZERO is the single most important
// guardrail: it makes independent agents consistent and stops scope creep.
const STEP_ZERO =
  "STEP ZERO: Load and follow the active operating profile / methodology " +
  "for this repository before doing anything else. Work ONLY within the " +
  "scope of the named slice -- no adjacent refactors, no deferrals, and no " +
  "work that belongs to another slice. Never switch branches, never push, " +
  "and never operate on the default branch.\n\n";

// Stage 0 -- plan intake. The script cannot read files itself, so a cheap
// read-only agent parses the INDEX and returns the ordered slice list.
// Dropping DONE slices here is what makes a re-run a resume.
async function readPlan() {
  log("Reading execution_plan/sessions/INDEX.md");
  const plan = await agent(
    STEP_ZERO +
      "Read execution_plan/sessions/INDEX.md. Return every slice in listed " +
      "order with its id, title, status, acceptance criteria, and " +
      "brief_path. Do not modify any file.",
    { label: "plan-intake", phase: "Plan intake", schema: sliceListSchema, effort: "low" }
  );
  const pending = plan.slices.filter((s) => s.status !== "DONE");
  log("Pending slices: " + pending.length + " of " + plan.slices.length);
  return pending;
}

// Stage 1 -- build the slice to full declared scope. No stubs, no deferrals.
async function buildStage(slice) {
  log("[" + slice.id + "] build");
  const build = await agent(
    STEP_ZERO +
      "Build slice " + slice.id + " (" + slice.title + ") to its FULL " +
      "declared scope. Read its brief at " + slice.brief_path + ". No " +
      "deferrals, stubs, or TODOs left behind. Add or update tests for the " +
      "behavior you introduce. Report what you built and the files touched.",
    { label: slice.id + "-build", phase: "Build", effort: "high" }
  );
  return { ...slice, build };
}

// Stage 2 -- adversarial review. A reviewer that did not write the code
// hunts bugs and scale/failure-mode issues. Read-only: it reports, not fixes.
async function reviewStage(slice) {
  log("[" + slice.id + "] review");
  const review = await agent(
    STEP_ZERO +
      "Adversarially review the code just built for slice " + slice.id +
      ". Hunt correctness bugs, race conditions, unhandled failure modes, " +
      "and behavior that breaks at scale (large inputs, concurrency, " +
      "partial failures, retries). Give each issue a concrete failure " +
      "scenario and a file:line. Set blocking=true if any finding must be " +
      "fixed before the slice can be accepted. Do not modify any file.",
    { label: slice.id + "-review", phase: "Adversarial review", schema: reviewSchema, effort: "high" }
  );
  return { ...slice, review };
}

// Stage 3 -- bounded fix. Runs only when the review flagged blocking
// findings; a clean review falls straight through so nothing is churned.
async function fixStage(slice) {
  if (!slice.review || !slice.review.blocking) {
    log("[" + slice.id + "] no blocking findings, skipping fix");
    return slice;
  }
  log("[" + slice.id + "] fix (" + slice.review.findings.length + " findings)");
  const fix = await agent(
    STEP_ZERO +
      "Fix ONLY the blocking findings from the review of slice " + slice.id +
      ", listed below. Do not expand scope or touch unrelated code. Re-run " +
      "the affected tests after fixing.\n\n" +
      JSON.stringify(slice.review.findings, null, 2),
    { label: slice.id + "-fix", phase: "Bounded fix", effort: "high" }
  );
  return { ...slice, fix };
}

// Stage 4 -- independent validation. A fresh agent that did NOT build the
// slice walks each acceptance criterion, re-running tests and invariants.
// DONE requires zero deferrals; anything short is BLOCKED. Independence is
// the point: the validator has no stake in declaring success.
async function validateStage(slice) {
  log("[" + slice.id + "] validate");
  const verdict = await agent(
    STEP_ZERO +
      "You are an INDEPENDENT validator; you did not build this slice. Walk " +
      "the acceptance criteria for slice " + slice.id + " one at a time, " +
      "re-running the relevant tests and invariants for each. Return " +
      "verdict DONE only if every criterion passes with zero deferrals; " +
      "otherwise return BLOCKED and list the unmet criteria.\n\n" +
      "Acceptance criteria:\n" +
      slice.acceptance_criteria.map((c, i) => (i + 1) + ". " + c).join("\n"),
    { label: slice.id + "-validate", phase: "Independent validation", schema: validationSchema, effort: "high" }
  );
  log("[" + slice.id + "] verdict: " + verdict.verdict);
  return { ...slice, verdict };
}

// Stage 5 -- retro and handoff. Records the outcome, drafts the next
// slice's starter for a warm handoff, updates the INDEX status, and commits
// the slice. Never pushes.
async function retroStage(slice) {
  const status =
    slice.verdict && slice.verdict.verdict === "DONE" ? "DONE" : "BLOCKED";
  log("[" + slice.id + "] retro -> " + status);
  await agent(
    STEP_ZERO +
      "Close out slice " + slice.id + " with status " + status + ":\n" +
      "1. Write a short retro / handoff note (what shipped, deviations, " +
      "followups) beside the slice brief.\n" +
      "2. Draft a starter for the next pending slice so the next session " +
      "opens with fresh context.\n" +
      "3. Update the status column for " + slice.id + " in " +
      "execution_plan/sessions/INDEX.md to " + status + ".\n" +
      "4. Commit every change for this slice with a descriptive message. " +
      "Do NOT push and do NOT switch branches.",
    { label: slice.id + "-retro", phase: "Retro and handoff", effort: "medium" }
  );
  return { ...slice, status };
}

// Orchestration. pipeline() streams each slice through the stages
// independently, so a slice stuck in review does not hold back a slice
// ready to build. Every stage returns the slice enriched for the next one.
// Each stage assigns its own phase via the opts.phase field above, which is
// the race-free way to group progress when stages run concurrently.
const pending = await readPlan();
if (pending.length === 0) {
  log("No pending slices. Plan is complete.");
  return [];
}

const results = await pipeline(
  pending,
  buildStage,
  reviewStage,
  fixStage,
  validateStage,
  retroStage
);

const done = results.filter((s) => s && s.status === "DONE").length;
log("Run complete. DONE: " + done + "  BLOCKED: " + (results.length - done));
log("Re-run to resume; DONE slices are skipped by the INDEX filter.");
return results;
