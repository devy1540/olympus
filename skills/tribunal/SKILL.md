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

- PROACTIVE SPAWN RULE (§6.3): Every Agent() call MUST include the agent's IMMEDIATE TASK or ROLE
  in the prompt. NEVER use "Wait for messages — do not act until prompted."
  The agent starts working the moment it spawns. SendMessage is ONLY for follow-up tasks.

- MANDATORY CONSULTATION (§7): athena MUST consult hephaestus for any AC where evidence is
  ambiguous BEFORE reporting final results to the leader. Reports lacking consultation evidence
  for ambiguous ACs are incomplete — send athena back to consult.
  Stage 3 debate: each agent MUST respond to the previous agent's specific points.
  This is a dialogue, not parallel monologues.

- RESPONSE RULE: If a teammate does not report within reasonable time:
  1. SendMessage(to: "{agent}", "Report your findings now. Include consultation results. Keep under 5000 chars.")
  2. Retry up to 3 times.
  3. NEVER do the agent's work directly — this violates §0.
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
        run_in_background: true,
        prompt: "You are Hephaestus in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
          IMMEDIATE TASK: Run mechanical verification — build, lint, type-check, and test suite in order.
          Save results to ${ARTIFACT_DIR}/mechanical-result.json.
          When done: SendMessage(to: 'leader', summary: '기계적 검증 완료', '{results}')
          Then STAY AVAILABLE throughout Tribunal — respond to queries from athena via SendMessage.")
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
        run_in_background: true,
        prompt: "You are Athena in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
          IMMEDIATE TASK: Perform semantic evaluation of AC compliance.
          DO NOT write files — you are read-only.
          Read ${ARTIFACT_DIR}/spec.md and mechanical-result.json.
          Extract AC list from spec.md.
          For each AC: search for implementation evidence (file:line).
          Status: MET (1.0) / PARTIALLY_MET (0.5) / NOT_MET (0.0).
          MANDATORY CONSULTATION: For any AC where evidence is ambiguous,
            query 'hephaestus': SendMessage(to: 'hephaestus', summary: 'AC 증거 확인', '{specific test or file to verify}')
            Wait for hephaestus response before finalizing that AC's status.
          Calculate overall score: sum / count.
          When done: SendMessage(to: 'leader', summary: '의미적 평가 완료 — score: {score}',
            '{semantic-matrix + hephaestus consultation log}')
          Then STAY AVAILABLE for Stage 3 queries.")
  olympus_register_agent_spawn(pipeline_id, "athena")

SendMessage(to: "athena", summary: "의미적 평가",
  "DO NOT write files — you are read-only.
   Read ${ARTIFACT_DIR}/spec.md and mechanical-result.json.
   Extract AC list from spec.md.
   For each AC: search for implementation evidence (file:line).
   Status: MET (1.0) / PARTIALLY_MET (0.5) / NOT_MET (0.0).
   CONSULTATION: For any AC where evidence is ambiguous,
     query 'hephaestus': SendMessage(to: 'hephaestus', summary: 'AC 증거 확인', '{specific test}')
   Calculate overall score: sum / count.
   Report semantic-matrix.md to leader with consultation log.")

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
           run_in_background: true,
           prompt: "You are Ares in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
             ROLE: Consensus proposer for Tribunal Stage 3 debate.
             DO NOT write files — you are read-only.
             Read ${ARTIFACT_DIR}/semantic-matrix.md and explore relevant code now.
             You will be asked to open the debate via SendMessage.
             When debating: include file:line evidence for every claim.
             STAY AVAILABLE throughout Stage 3 — you may be asked to rebut eris's counter-argument.")
     olympus_register_agent_spawn(pipeline_id, "ares")

   IF "eris" not in team:
     Agent(name: "eris", team_name: ${TEAM},
           subagent_type: "olympus:eris",
           run_in_background: true,
           prompt: "You are Eris in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
             ROLE: Devil's advocate for Tribunal Stage 3 debate.
             DO NOT write files — you are read-only.
             Read ${ARTIFACT_DIR}/semantic-matrix.md now.
             You will receive ares's full argument via SendMessage.
             When challenging: use fallacy-catalog.md, include file:line counter-evidence.
             IMPORTANT: Respond SPECIFICALLY to ares's points — do not make independent arguments.
             This is a dialogue, not parallel monologues.
             STAY AVAILABLE throughout Stage 3.")
     olympus_register_agent_spawn(pipeline_id, "eris")

   IF "hera" not in team:
     Agent(name: "hera", team_name: ${TEAM},
           subagent_type: "olympus:hera",
           run_in_background: true,
           prompt: "You are Hera in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
             ROLE: Final judge for Tribunal Stage 3 — synthesize the debate and produce verdict.
             You will receive the full debate transcript (ares opening + eris rebuttal + ares rebuttal).
             You may query 'hephaestus' for test evidence to settle factual disputes:
               SendMessage(to: 'hephaestus', summary: '판정 근거 확인', '{what to verify}')
             STAY AVAILABLE for verdict task.")
     olympus_register_agent_spawn(pipeline_id, "hera")

2. Sequential debate (EACH SEES THE PREVIOUS) — THIS IS A REAL DEBATE:

   a. Ares proposes:
      SendMessage(to: "ares", summary: "토론 개시",
        "DO NOT write files — you are read-only.
         Read ${ARTIFACT_DIR}/semantic-matrix.md and explore relevant code.
         Argue for APPROVE or REJECT from quality perspective.
         Include file:line evidence for every claim.
         This will be shared with Eris for counter-argument.
         Report position to leader.")
      WAIT → receive ares_position
      olympus_log_collaboration(pipeline_id, "ares", "eris", "Tribunal debate: ares opening")

   b. Eris counter-argues — SEES ares's full argument:
      SendMessage(to: "eris", summary: "반박",
        "ARES ARGUES: {ares_full_position}.
         Your job: find logical fallacies, unsupported claims, overlooked evidence.
         Use fallacy-catalog.md. Include file:line counter-evidence.
         IMPORTANT: Respond SPECIFICALLY to ares's points — do not make independent arguments.
         This is a dialogue, not parallel monologues.
         Report counter-argument to leader.")
      WAIT → receive eris_counter
      olympus_log_collaboration(pipeline_id, "eris", "ares", "Tribunal debate: eris rebuttal")

   c. OPTIONAL: Ares rebuttal (if eris raised substantive new points):
      SendMessage(to: "ares", summary: "재반박",
        "ERIS COUNTERS: {eris_full_counter}.
         Respond ONLY to new points eris raised. Do not repeat your opening.
         Concede where eris is right. Defend where you have stronger evidence.")
      WAIT → receive ares_rebuttal (if applicable)

   d. Hera synthesizes — SEES the full debate transcript:
      SendMessage(to: "hera", summary: "종합 판정",
        "DEBATE TRANSCRIPT:
         === ARES OPENING === {ares_position}
         === ERIS REBUTTAL === {eris_counter}
         === ARES REBUTTAL === {ares_rebuttal or 'N/A'}
         Synthesize the debate. Where ares and eris disagree, determine who has stronger evidence.
         You may query 'hephaestus' for test evidence to settle factual disputes:
           SendMessage(to: 'hephaestus', summary: '판정 근거 확인', '{specific test}')
         Produce final synthesized verdict: APPROVE or REJECT with reasoned synthesis.
         Report to leader.")
      WAIT → receive hera_verdict

3. Tally votes:
   Extract APPROVE/REJECT from each response.
   Supermajority >= 67%:
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
  - olympus_log_collaboration: Stage 3 debate exchanges (SHOULD)

  Team Tools:
  - TeamCreate: Step 1 (standalone only)
  - Agent (name + team_name + run_in_background: true): spawn teammates
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
