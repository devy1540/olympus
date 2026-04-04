---
name: oracle
description: "The Oracle of Delphi — requirements refinement pipeline"
---

<Purpose>
Turn vague ideas into validated specifications through Socratic interview.
All agents operate as teammates for cross-phase context retention.
</Purpose>

<Execution_Policy>
- This skill uses FULL TEAMMATE mode. ALL agents are teammates in one team.
- Each Step MUST call the specified MCP tool. Do NOT skip MCP calls.
- Do NOT perform agent work directly (no Grep/Read instead of Hermes, no inline interview instead of Apollo).
- Teammates persist — Apollo remembers previous interview rounds, Hermes remembers codebase exploration.
- Leader handles ONLY: team management, gate checks, artifact writing for read-only agents.
- If MCP tools are unavailable, proceed without MCP — hooks provide fallback.
- IMPORTANT: Do NOT skip ToolSearch at Step 0.
- TEAMMATE RESPONSE RULE: When a teammate goes idle without sending results,
  send a follow-up: SendMessage(to: "{agent}", "Report your findings now via SendMessage. Keep under 5000 chars.")
  Retry up to 3 times. NEVER do the agent's work directly — this violates §0.
</Execution_Policy>

<Team_Structure>
  team_name: "oracle-${CLAUDE_SESSION_ID}"
  (When called from Odyssey, use the Odyssey team instead — do NOT create a separate team)

  Teammates:
  | Agent | Role | Comm Targets |
  |-------|------|-------------|
  | hermes | Codebase exploration | leader, apollo (responds to queries) |
  | apollo | Socratic interview | hermes (codebase questions), metis (gap feedback), leader |
  | metis | Gap analysis | hermes (codebase questions), leader |
  | eris | DA challenge (optional) | leader |
</Team_Structure>

<Steps>

## Step 0: Load MCP Tools (REQUIRED FIRST)

```
Call ToolSearch("+olympus pipeline") to load MCP tools.
```

**IMPORTANT**: Do NOT skip this step.

---

## Step 1: Initialize

```
1. IF standalone (not called from Odyssey):
     TeamCreate(team_name: "oracle-${CLAUDE_SESSION_ID}")
   ELSE:
     Use existing Odyssey team (${TEAM})

2. IF olympus_start_pipeline is available:
     olympus_start_pipeline(skill: "oracle", pipeline_id: "oracle-${CLAUDE_SESSION_ID}")

3. Create artifact directory: .olympus/oracle-{YYYYMMDD}-{short-uuid}/
```

---

## Step 2: Input Classification

```
Classify user input:
- file: file path → Read contents
- URL: web URL → WebFetch
- text: raw text → use directly
- conversation: extract from prior context

Complexity assessment:
- Trivial: clear and simple → skip to Step 7 (spec generation)
- Clear: mostly clear, minor clarification → light interview (3 rounds max)
- Vague: significant ambiguity → full interview (10 rounds max)
- Contradictory: contradictions detected → deep interview (resolve first)
```

---

## Step 3: Hermes Codebase Exploration

```
IF "hermes" not in team:
  Agent(name: "hermes", team_name: ${TEAM},
        subagent_type: "olympus:hermes",
        prompt: "You are Hermes, a teammate in ${TEAM}.
          Respond to codebase queries from apollo and leader.
          Artifact directory: ${ARTIFACT_DIR}/
          Wait for messages — do not act until prompted.")
  olympus_register_agent_spawn(pipeline_id, "hermes")

SendMessage(to: "hermes", summary: "코드베이스 탐색",
  "Explore codebase related to: {user_input}.
   Gather: project structure, relevant modules, existing patterns, dependencies.
   Report findings to leader.")

WAIT for hermes → leader writes codebase-context.md
olympus_record_execution(pipeline_id, "oracle", "hermes", ...)
```

---

## Step 4: Apollo Interview Loop

```
IF "apollo" not in team:
  Agent(name: "apollo", team_name: ${TEAM},
        subagent_type: "olympus:apollo",
        prompt: "You are Apollo, a teammate in ${TEAM}.
          You retain memory across interview rounds — build on previous answers.
          You may query 'hermes' for codebase context during interview.
          Artifact directory: ${ARTIFACT_DIR}/
          Wait for messages — do not act until prompted.")
  olympus_register_agent_spawn(pipeline_id, "apollo")

SendMessage(to: "apollo", summary: "인터뷰 시작",
  "Read ${ARTIFACT_DIR}/codebase-context.md for project context.
   User requirement: {user_input}. Complexity: {level}.
   Conduct Socratic interview via AskUserQuestion. One question at a time.
   After each answer:
     a. Track ambiguity scores internally (per ambiguity-scoring.md)
     b. Track interview log internally
     c. Track ambiguity scores internally
   DO NOT write files — you are read-only.
   Stagnation detection:
     - Spinning: same topic 3 times → move on
     - Oscillation: A↔B repetition → ask user to decide
     - Diminishing: delta < 0.02 → terminate dimension
   Terminate when: ambiguity ≤ 0.2 OR max rounds reached.
   Send interview log + ambiguity scores to leader via SendMessage when done.")

WAIT for apollo → leader writes interview-log.md, ambiguity-scores.json
olympus_record_execution(pipeline_id, "oracle", "apollo", ...)
```

---

## Step 5: Ambiguity Gate

```
ambiguityScore = read ${ARTIFACT_DIR}/ambiguity-scores.json
olympus_gate_check(pipeline_id, "ambiguity", ambiguityScore)

IF passed (ambiguity ≤ 0.2):
  → proceed to Step 6

ELSE IF rounds < 10:
  → SendMessage(to: "apollo", summary: "추가 인터뷰",
      "Ambiguity still at {score}. Continue interview, focus on: {gap areas}")
  ← Apollo REMEMBERS previous rounds — no re-initialization!
  → re-check gate after completion

ELSE (rounds >= 10):
  → AskUserQuestion: "다음 갭이 남아있습니다. 그대로 진행할까요?"
  → On override: proceed to Step 6
```

---

## Step 6: Metis Gap Analysis

```
IF "metis" not in team:
  Agent(name: "metis", team_name: ${TEAM},
        subagent_type: "olympus:metis",
        prompt: "You are Metis, a teammate in ${TEAM}.
          Artifact directory: ${ARTIFACT_DIR}/
          Wait for messages — do not act until prompted.")
  olympus_register_agent_spawn(pipeline_id, "metis")

SendMessage(to: "metis", summary: "갭 분석",
  "Read ${ARTIFACT_DIR}/interview-log.md and codebase-context.md.
   Analyze: Missing Questions, Undefined Guardrails, Scope Risks,
   Unvalidated Assumptions, Acceptance Criteria, Edge Cases.
   Report results to leader.")

WAIT for metis → leader writes gap-analysis.md
olympus_record_execution(pipeline_id, "oracle", "metis", ...)
```

---

## Step 7: Spec Generation

```
Synthesize interview-log.md + gap-analysis.md into spec.md:

# Specification: {title}

## GOAL
## CONSTRAINTS
## ACCEPTANCE_CRITERIA (GIVEN-WHEN-THEN format)
## SCOPE (In/Out)
## ASSUMPTIONS
## EDGE_CASES
## OPEN_QUESTIONS
## ONTOLOGY
## AMBIGUITY_SCORE

Write ${ARTIFACT_DIR}/spec.md
```

---

## Step 8: Teardown

```
IF standalone (not called from Odyssey):
  FOR each active teammate:
    SendMessage(to: "{name}", message: { type: "shutdown_request" })
    WAIT for shutdown_response
  TeamDelete(team_name: "oracle-${CLAUDE_SESSION_ID}")
ELSE:
  Teammates persist for Odyssey's next phase
```

</Steps>

<Tool_Usage>
  MCP Tools (loaded at Step 0):
  - olympus_start_pipeline: Step 1 (MUST)
  - olympus_register_agent_spawn: after each spawn (MUST)
  - olympus_gate_check: Step 5 ambiguity gate (MUST)
  - olympus_record_execution: after each agent completes (SHOULD)

  Team Tools:
  - TeamCreate: Step 1 (standalone only)
  - Agent (name + team_name): spawn teammates
  - SendMessage: all agent communication
  - TeamDelete: Step 8 (standalone only)
</Tool_Usage>

<Artifact_Contracts>
  | File | Step | Writer | Readers |
  |------|------|--------|---------|
  | codebase-context.md | 3 | Leader (from hermes) | apollo, metis |
  | interview-log.md | 4 | Leader (from apollo) | metis |
  | ambiguity-scores.json | 4 | Leader (from apollo) | Gate check |
  | gap-analysis.md | 6 | Leader (from metis) | zeus, helios |
  | spec.md | 7 | Leader | All downstream |
</Artifact_Contracts>
