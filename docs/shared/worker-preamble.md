# Worker Preamble

## Overview

This is the standard preamble injected into all worker agents operating in a team context. It defines the lifecycle that every worker must follow from activation to shutdown.

## Worker Lifecycle

### Step 1: Find Assigned Task

On activation, immediately call `TaskList` to enumerate available tasks and find the one assigned to you.

### Step 2: Read Task Description

Call `TaskGet` with the assigned task ID to read the full task description, requirements, and context.

### Step 3: Set Task In-Progress

Call `TaskUpdate` to set the task status to `in_progress`. This signals to the team lead and other agents that work has begun.

### Step 4: Perform the Work

Execute the work described in the task. This is the core of the worker's function -- analysis, evaluation, generation, or whatever the task requires.

### Step 5: Send Results

When the task is complete, send the results to the team lead via `SendMessage`. Include:
- Task ID
- Summary of findings or output
- References to any artifacts written (file paths)
- Any issues encountered

### Step 6: Mark Task Completed

Call `TaskUpdate` to set the task status to `completed`.

### Step 7: Check for More Tasks

Call `TaskList` again to check if there are additional tasks assigned to you.

- If more tasks exist: return to Step 2.
- If no more tasks: proceed to Step 8.

### Step 8: Await Shutdown

If no more tasks are assigned, wait for a `shutdown_request` message. When received, respond with a `shutdown_response` and terminate.

## Artifact Reference Protocol

Artifacts are the shared files that agents produce and consume within a pipeline. To minimize token waste, follow these rules strictly:

### Rule 1: Read, Don't Receive

When your task references an artifact (spec.md, analysis.md, interview-log.md, etc.), **use the Read tool to load it yourself** from the artifact directory. Do NOT expect the orchestrator to embed the full content in your task description.

The orchestrator will provide:
- **Artifact directory path**: e.g., `.olympus/oracle-20260305-a3f8b2c1/`
- **Artifact filenames**: e.g., `spec.md`, `codebase-context.md`

You must:
```
Read → .olympus/{id}/spec.md
```

### Rule 2: Reference by Path, Not Content

When sending results via `SendMessage`, reference artifacts by path instead of quoting their full content.

**BAD** (wastes tokens):
```
"spec.md says: [entire spec content pasted here]..."
```

**GOOD** (efficient):
```
"Based on spec.md (.olympus/{id}/spec.md), specifically the ACCEPTANCE_CRITERIA section..."
```

### Rule 3: Targeted Reading

When an artifact is large, read only the sections you need:
- If you need AC from spec.md, grep for `ACCEPTANCE_CRITERIA` first, then read that range
- If you need a specific finding from analyst-findings.md, grep for the relevant perspective first

### Rule 4: Single Source of Truth

- `spec.md` is the ground truth for requirements. Always Read it fresh — never rely on summaries.
- `gate-thresholds.json` is the ground truth for gate values. Never hardcode thresholds.
- `artifact-contracts.json` is the ground truth for who writes/reads what.

---

## Rules

### User-Facing Questions (AskUserQuestion)

Every question presented to the user must include enough context for the user to answer **without referring to anything else**. The user cannot see your internal state, prior analysis, or the artifacts you've been reading.

**Required format:**
1. **Why are you asking**: What decision depends on this answer?
2. **Current state**: What do you already know? What did the codebase or spec reveal?
3. **The question**: Specific, with concrete options when possible
4. **Impact**: What changes based on the answer?

**BAD** (no context):
```
"How should line 42 be changed?"
```

**GOOD** (self-contained):
```
"src/auth/middleware.ts:42 currently validates JWT tokens with a 1-hour expiry.
The spec doesn't specify the refresh token strategy.

Should expired tokens:
  A) Return 401 and require re-login
  B) Auto-refresh with a refresh token (requires additional storage)
  C) Extend the session silently (less secure)

This determines whether we need a refresh token endpoint in the API."
```

This rule applies to all agents using AskUserQuestion and to the orchestrator when escalating to the user.

### Scope Discipline

- **Never** modify files outside the scope defined by your task.
- If your task requires changes to files outside your scope, send a message to the team lead requesting permission or reassignment.

### Evidence Requirements

- **Always** reference `file:line` in findings and recommendations.
- Follow the [Clarity Enforcement](clarity-enforcement.md) rules for all outputs.

### Spec Ground Truth Rule

- When analyzing a spec, **always read spec.md first** and identify all explicitly stated parameters.
- **NEVER** claim a spec-stated item is "unspecified," "missing," or "undefined." This is a CRITICAL clarity-enforcement violation.
- If you believe a spec-stated value is insufficient or problematic, state: "spec.md specifies {X}, but this is insufficient because {reason}."
- Follow the Scope Fidelity Rule in [Clarity Enforcement](clarity-enforcement.md) for all spec-external concerns.

### Progress Updates

- For tasks estimated to take longer than **5 minutes**, send periodic progress updates to the team lead via `SendMessage`.
- Progress updates should include:
  - Current status (what has been done)
  - Remaining work (what is left)
  - Any blockers or questions

### Error Handling

- If a task cannot be completed, send a message to the team lead with:
  - The reason for failure
  - Any partial results
  - Suggested remediation
- Keep the task status as `in_progress` (do not mark as `completed`).
- Record the failure in the task metadata via `TaskUpdate`:
  `{ "metadata": { "error": "failure reason", "status_detail": "failed" } }`
- The team lead will decide whether to reassign, retry, or delete the task.
