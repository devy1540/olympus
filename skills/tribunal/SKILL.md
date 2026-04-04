---
name: tribunal
description: "Trial of the Gods — 3-stage evaluation pipeline"
---

<Purpose>
Evaluate implementations through three stages: mechanical → semantic → adversarial consensus.
All agents operate as teammates. Stage 3 debate uses direct inter-agent SendMessage.
</Purpose>

<Execution_Policy>
- This skill uses FULL TEAMMATE mode. ALL agents are teammates in one team.
- Each Step MUST call the specified MCP tool. Do NOT skip MCP calls.
- Stage 3 is NOT optional when trigger conditions apply. Do NOT skip to APPROVED after Athena alone.
- Stage 3 debate is SEQUENTIAL: Ares → Eris (sees Ares) → Hera (sees both).
- Do NOT perform agent work directly.
- Leader handles ONLY: team management, gate checks, artifact writing, verdict compilation.
- IMPORTANT: Do NOT skip ToolSearch at Step 0.
- TEAMMATE RESPONSE RULE: When a teammate goes idle without sending results,
  send a follow-up: SendMessage(to: "{agent}", "Report your findings now via SendMessage. Keep under 5000 chars.")
  Retry up to 3 times. NEVER do the agent's work directly — this violates §0.
</Execution_Policy>

<Team_Structure>
  team_name: "tribunal-${CLAUDE_SESSION_ID}"
  (When called from Odyssey, use the Odyssey team instead)

  Teammates:
  | Agent | Stage | Role | Comm Targets |
  |-------|-------|------|-------------|
  | hephaestus | 1 | Mechanical verification | leader |
  | athena | 2 | Semantic evaluation | hephaestus (evidence), leader |
  | ares | 3 | Consensus proposer | eris (debate partner), leader |
  | eris | 3 | Consensus DA | ares (counter-argue), leader |
  | hera | 3 | Consensus synthesizer | hephaestus (evidence), leader |
</Team_Structure>

<Steps>

## Step 0: Load MCP Tools (REQUIRED FIRST)

```
Call ToolSearch("+olympus pipeline") to load MCP tools.
```

---

## Step 1: Initialize

```
1. IF standalone:
     TeamCreate(team_name: "tribunal-${CLAUDE_SESSION_ID}")
   ELSE:
     Use existing Odyssey team (${TEAM})

2. olympus_start_pipeline(skill: "tribunal", pipeline_id: ...)
3. Create artifact directory: .olympus/tribunal-{YYYYMMDD}-{short-uuid}/
```

---

## Step 2: Stage 1 — Hephaestus Mechanical Verification

```
IF "hephaestus" not in team:
  Agent(name: "hephaestus", team_name: ${TEAM},
        subagent_type: "olympus:hephaestus",
        prompt: "You are Hephaestus, a teammate in ${TEAM}.
          Run build/lint/test/type-check when requested.
          Artifact directory: ${ARTIFACT_DIR}/
          Wait for messages — do not act until prompted.")
  olympus_register_agent_spawn(pipeline_id, "hephaestus")

SendMessage(to: "hephaestus", summary: "기계적 검증",
  "Run build, lint, type-check, and test suite in order.
   Save results to ${ARTIFACT_DIR}/mechanical-result.json.
   Report to leader.")

WAIT → leader writes mechanical-result.json
olympus_record_execution(pipeline_id, "tribunal", "hephaestus", ...)

Decision:
  All PASS → proceed to Step 3
  Any FAIL → BLOCKED verdict
    Write verdict.md with detailed error report → exit
```

---

## Step 3: Stage 2 — Athena Semantic Evaluation

```
IF "athena" not in team:
  Agent(name: "athena", team_name: ${TEAM},
        subagent_type: "olympus:athena",
        prompt: "You are Athena, a teammate in ${TEAM}.
          You may query 'hephaestus' for additional test evidence.
          Artifact directory: ${ARTIFACT_DIR}/
          Wait for messages — do not act until prompted.")
  olympus_register_agent_spawn(pipeline_id, "athena")

SendMessage(to: "athena", summary: "의미적 평가",
  "Read ${ARTIFACT_DIR}/spec.md and mechanical-result.json.
   Extract AC list from spec.md.
   For each AC: search for implementation evidence (file:line).
   Status: MET (1.0) / PARTIALLY_MET (0.5) / NOT_MET (0.0).
   Calculate overall score: sum / count.
   Report semantic-matrix.md to leader.")

WAIT → leader writes semantic-matrix.md
olympus_record_execution(pipeline_id, "tribunal", "athena", ...)

Decision:
  AC compliance = 100% AND score >= 0.8 → check Stage 3 trigger
  Otherwise → INCOMPLETE verdict
    Write verdict.md with unmet AC list → exit
```

---

## Step 4: Stage 3 — Consensus Debate (conditional)

```
Trigger conditions (execute if ANY apply):
  - Spec was modified during pipeline
  - Overall semantic score < 0.8
  - Scope deviation detected
  - User explicitly requested

IF no trigger conditions: Stage 2 result → APPROVED directly → Step 5

WHEN triggered:

1. Spawn debate teammates (lazy):

   IF "ares" not in team:
     Agent(name: "ares", team_name: ${TEAM},
           subagent_type: "olympus:ares",
           prompt: "You are Ares, consensus proposer in ${TEAM}.
             You will debate with 'eris'. Read semantic-matrix.md and code.
             Wait for messages — do not act until prompted.")
     olympus_register_agent_spawn(pipeline_id, "ares")

   IF "eris" not in team:
     Agent(name: "eris", team_name: ${TEAM},
           subagent_type: "olympus:eris",
           prompt: "You are Eris, devil's advocate in ${TEAM}.
             You will counter-argue against 'ares' with evidence.
             Wait for messages — do not act until prompted.")
     olympus_register_agent_spawn(pipeline_id, "eris")

   IF "hera" not in team:
     Agent(name: "hera", team_name: ${TEAM},
           subagent_type: "olympus:hera",
           prompt: "You are Hera, synthesizer in ${TEAM}.
             You will see both Ares and Eris positions.
             Run tests for evidence. Produce final verdict.
             Wait for messages — do not act until prompted.")
     olympus_register_agent_spawn(pipeline_id, "hera")

2. Sequential debate (EACH SEES THE PREVIOUS):

   a. Ares proposes:
      SendMessage(to: "ares", summary: "토론 제안",
        "Read ${ARTIFACT_DIR}/semantic-matrix.md and explore relevant code.
         Argue for APPROVE or REJECT from quality perspective.
         Include file:line evidence for every claim.
         Report position to leader.")
      WAIT → receive ares_position

   b. Eris counter-argues (sees Ares):
      SendMessage(to: "eris", summary: "반박",
        "Ares's position: {ares_position_summary}.
         Read ${ARTIFACT_DIR}/semantic-matrix.md.
         Counter-argue with evidence. Challenge fallacies per fallacy-catalog.md.
         Report counter-argument to leader.")
      WAIT → receive eris_counter

   c. Hera synthesizes (sees both):
      SendMessage(to: "hera", summary: "종합 판정",
        "Ares argues: {ares_summary}. Eris counters: {eris_summary}.
         Read ${ARTIFACT_DIR}/semantic-matrix.md.
         Synthesize both arguments. Run tests via Bash for evidence.
         Produce final synthesized verdict: APPROVE or REJECT.
         Report to leader.")
      WAIT → receive hera_verdict

3. Tally votes:
   Extract APPROVE/REJECT from each response.
   Supermajority >= 66%:
     - 2+ approve → APPROVED
     - 1 approve → REJECTED + dissent recorded
     - 0 approve → REJECTED

4. Save consensus-record.json:
   { votes: { ares, eris, hera }, result, dissent }
```

---

## Step 5: Final Verdict

```
Generate verdict.md:

# Tribunal Verdict

## Stage Results
- Stage 1 (Mechanical): {PASS/FAIL}
- Stage 2 (Semantic): {score} — {PASS/FAIL}
- Stage 3 (Consensus): {executed/skipped} — {result}

## Final Verdict: {APPROVED / BLOCKED / INCOMPLETE / REJECTED_*}

REJECTED subtypes (auto-classified):
- REJECTED_IMPLEMENTATION: implementation quality issue → Phase 5 retry
- REJECTED_SPEC: requirement defect → Oracle rewind
- REJECTED_ARCHITECTURE: structural issue → Pantheon rewind

Classification:
- NOT_MET due to implementation omission → REJECTED_IMPLEMENTATION
- NOT_MET due to AC contradiction → REJECTED_SPEC
- NOT_MET due to architecture constraints → REJECTED_ARCHITECTURE

## Details
{per-verdict content}

## Recommendations
{action + target phase for return}
```

---

## Step 6: Teardown

```
IF standalone:
  Shutdown all teammates → TeamDelete
ELSE:
  Teammates persist for Odyssey verdict processing
```

</Steps>

<Tool_Usage>
  MCP Tools:
  - olympus_start_pipeline: Step 1 (MUST)
  - olympus_register_agent_spawn: after each spawn (MUST)
  - olympus_record_execution: after each agent (SHOULD)

  Team Tools:
  - TeamCreate: Step 1 (standalone only)
  - Agent (name + team_name): spawn teammates
  - SendMessage: SEQUENTIAL for debate (Ares → Eris → Hera, each sees previous)
  - TeamDelete: Step 6 (standalone only)
</Tool_Usage>

<Artifact_Contracts>
  | File | Stage | Writer | Readers |
  |------|-------|--------|---------|
  | mechanical-result.json | 1 | hephaestus (direct) | athena |
  | semantic-matrix.md | 2 | Leader (from athena) | ares, eris, hera |
  | consensus-record.json | 3 | Leader | Final verdict |
  | verdict.md | 5 | Leader | User |
</Artifact_Contracts>
