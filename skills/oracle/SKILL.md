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
- PROACTIVE SPAWN RULE (§6.3): Every Agent() call MUST include the agent's IMMEDIATE TASK
  in the prompt. NEVER use "Wait for messages — do not act until prompted."
  The agent starts working the moment it spawns. SendMessage is ONLY for follow-up tasks.

- MANDATORY CONSULTATION (§7): apollo must consult hermes before user questions.
  metis must verify assumptions via hermes. Reports without consultation are incomplete —
  send agent back to consult.

- SEQUENTIAL SPAWN: hermes first → apollo after hermes completes → metis after apollo completes.
  Wait for prerequisite agent results before spawning dependent agents.

- RESPONSE RULE: If a teammate does not report within reasonable time:
  1. SendMessage(to: "{agent}", "Report your findings now. Include consultation results. Keep under 5000 chars.")
  2. Retry up to 3 times.
  3. NEVER do the agent's work directly — this violates §0.

- RESULT CAPTURE RULE: Read-only agents deliver results via SendMessage(to: "team-lead").
  Orchestrator writes artifacts from these results. Write-capable agents write files directly.
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
hermes_result = Agent(name: "hermes", team_name: ${TEAM},
      subagent_type: "olympus:hermes",
      prompt: "You are Hermes in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
        LEADER_NAME: team-lead
        IMMEDIATE TASK: Explore codebase related to: {user_input}.
        DO NOT write files — you are read-only.
        Gather: project structure, relevant modules, existing patterns, dependencies.
        Output your full results as your final response.")
olympus_register_agent_spawn(pipeline_id, "hermes")

→ Write codebase-context.md from hermes_result
olympus_record_execution(pipeline_id, "oracle", "hermes", ...)
olympus_log_collaboration(pipeline_id, "hermes", "apollo", "코드베이스 컨텍스트 인계: hermes→apollo")
```

---

## Step 4: Apollo Interview Loop

```
Agent(name: "apollo", team_name: ${TEAM},
      subagent_type: "olympus:apollo",
      run_in_background: true,
      prompt: "You are Apollo in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
        LEADER_NAME: team-lead
        IMMEDIATE TASK: Conduct Socratic interview about: {user_input}. Complexity: {level}.
        DO NOT write files — you are read-only.
        Read ${ARTIFACT_DIR}/codebase-context.md for project context.
        IMPORTANT: You CANNOT use AskUserQuestion directly (teammates can't access it).
        Instead, send each question to the leader:
          SendMessage(to: 'team-lead', summary: '인터뷰 질문 {n}', '{질문 + 컨텍스트 + 선택지}')
        The leader will proxy the question to the user and relay the answer back to you.
        Track ambiguity scores internally. Terminate when ambiguity ≤ 0.2 or max 10 rounds.
        When done: SendMessage(to: 'team-lead', summary: '인터뷰 완료', '{interview log + scores}')")
olympus_register_agent_spawn(pipeline_id, "apollo")

APOLLO INTERVIEW PROXY LOOP (leader handles while Apollo runs in background):
  WHILE apollo has not sent '인터뷰 완료':
    1. Receive SendMessage from apollo (summary: '인터뷰 질문 {n}')
    2. AskUserQuestion(question: "{apollo's question}", options: ["답변 입력..."])
    3. Relay user answer back: SendMessage(to: "apollo", "{user's answer}")
    Note: if user wants to skip interview → send "SKIP" to apollo; apollo terminates and reports current score.

→ Write interview-log.md, ambiguity-scores.json from apollo's final '인터뷰 완료' message
olympus_record_execution(pipeline_id, "oracle", "apollo", ...)
```

---

## Step 5: Ambiguity Gate

```
ambiguityScore = read ${ARTIFACT_DIR}/ambiguity-scores.json

# Cross-reference: mechanical ambiguity calculation from interview log
mechanicalScore = olympus_calculate_ambiguity(pipeline_id, "${ARTIFACT_DIR}/interview-log.md")
# Use the higher (more conservative) score for gate check
effectiveScore = max(ambiguityScore, mechanicalScore)
olympus_gate_check(pipeline_id, "ambiguity", effectiveScore)

IF passed (ambiguity ≤ 0.2):
  → proceed to Step 6

ELSE IF rounds < 10:
  next = olympus_next_action(pipeline_id)
  # next.action: retry_phase — re-interview with focus on gap areas
  → Re-spawn apollo (FOREGROUND) with follow-up task:
    apollo_retry = Agent(name: "apollo", team_name: ${TEAM},
        subagent_type: "olympus:apollo",
        prompt: "You are Apollo. Artifact directory: ${ARTIFACT_DIR}/
          LEADER_NAME: team-lead
          Read ${ARTIFACT_DIR}/interview-log.md for previous rounds.
          Ambiguity still at {score}. Continue interview, focus on: {gap areas}.
          Output updated results as your final response.")
    olympus_register_agent_spawn(pipeline_id, "apollo")
    olympus_record_execution(pipeline_id, "oracle", "apollo-retry", ...)
  → re-check gate after completion

ELSE (rounds >= 10):
  next = olympus_next_action(pipeline_id)
  # next.action: escalate → user override decision
  → AskUserQuestion: "다음 갭이 남아있습니다. 그대로 진행할까요?"
  → On override: proceed to Step 6
```

---

## Step 6: Metis Gap Analysis

```
metis_result = Agent(name: "metis", team_name: ${TEAM},
      subagent_type: "olympus:metis",
      prompt: "You are Metis in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
        LEADER_NAME: team-lead
        IMMEDIATE TASK: Perform gap analysis on interview results.
        DO NOT write files — you are read-only.
        Read ${ARTIFACT_DIR}/interview-log.md and ${ARTIFACT_DIR}/codebase-context.md.
        Analyze: Missing Questions, Undefined Guardrails, Scope Risks,
        Unvalidated Assumptions, Acceptance Criteria, Edge Cases.
        Output your full results as your final response.")
olympus_register_agent_spawn(pipeline_id, "metis")

→ Write gap-analysis.md from metis_result
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
  - olympus_next_action: Step 5 gate failure recovery (SHOULD)
  - olympus_calculate_ambiguity: Step 5 ambiguity cross-reference (SHOULD)
  - olympus_log_collaboration: after hermes→apollo context handoff (SHOULD)
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
