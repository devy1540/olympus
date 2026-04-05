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
heph_result = Agent(name: "hephaestus", team_name: ${TEAM},
      subagent_type: "olympus:hephaestus",
      prompt: "You are Hephaestus in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
        LEADER_NAME: team-lead
        IMMEDIATE TASK: Run mechanical verification — build, lint, type-check, and test suite in order.
        Output results as your final response in mechanical-result.json format.")
olympus_register_agent_spawn(pipeline_id, "hephaestus")

→ Write mechanical-result.json from heph_result
olympus_record_execution(pipeline_id, "tribunal", "hephaestus", ...)

Decision:
  All PASS → proceed to Step 3
  Any FAIL → BLOCKED verdict
    Write verdict.md with detailed error report → exit
```

---

## Step 3: Stage 2 — Athena Semantic Evaluation

```
athena_result = Agent(name: "athena", team_name: ${TEAM},
      subagent_type: "olympus:athena",
      prompt: "You are Athena in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
        LEADER_NAME: team-lead
        IMMEDIATE TASK: Perform semantic evaluation of AC compliance.
        DO NOT write files — you are read-only.
        Read ${ARTIFACT_DIR}/spec.md and mechanical-result.json.
        Extract AC list from spec.md.
        For each AC: search for implementation evidence (file:line).
        Status: MET (1.0) / PARTIALLY_MET (0.5) / NOT_MET (0.0).
        Calculate overall score: sum / count.
        Output your full results as your final response.")
olympus_register_agent_spawn(pipeline_id, "athena")

→ Write semantic-matrix.md from athena_result
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

1. Sequential debate — each agent spawned FOREGROUND, EACH SEES PREVIOUS:

   a. Ares proposes (FOREGROUND):
      ares_position = Agent(name: "ares", team_name: ${TEAM},
        subagent_type: "olympus:ares",
        prompt: "You are Ares. Artifact directory: ${ARTIFACT_DIR}/
          LEADER_NAME: team-lead
          IMMEDIATE TASK: Read ${ARTIFACT_DIR}/semantic-matrix.md and explore relevant code.
          Argue for APPROVE or REJECT from quality perspective.
          Include file:line evidence for every claim.
          Output your full position as your final response.")
      olympus_log_collaboration(pipeline_id, "ares", "eris", "Tribunal debate: ares opening")

   b. Eris counter-argues — SEES ares's full argument (FOREGROUND):
      eris_counter = Agent(name: "eris", team_name: ${TEAM},
        subagent_type: "olympus:eris",
        prompt: "LEADER_NAME: team-lead
          ARES ARGUES: {ares_position}.
          Your job: find logical fallacies, unsupported claims, overlooked evidence.
          Use fallacy-catalog.md. Include file:line counter-evidence.
          IMPORTANT: Respond SPECIFICALLY to ares's points — do not make independent arguments.
          Output your full rebuttal as your final response.")
      olympus_log_collaboration(pipeline_id, "eris", "ares", "Tribunal debate: eris rebuttal")

   c. OPTIONAL: Ares rebuttal (if eris raised substantive new points, FOREGROUND):
      ares_rebuttal = Agent(name: "ares", team_name: ${TEAM},
        subagent_type: "olympus:ares",
        prompt: "LEADER_NAME: team-lead
          ERIS COUNTERS: {eris_counter}.
          Respond ONLY to new points eris raised. Do not repeat your opening.
          Concede where eris is right. Defend where you have stronger evidence.
          Output your rebuttal as your final response.")

   d. Hera synthesizes — SEES the full debate transcript (FOREGROUND):
      hera_verdict = Agent(name: "hera", team_name: ${TEAM},
        subagent_type: "olympus:hera",
        prompt: "LEADER_NAME: team-lead
          DEBATE TRANSCRIPT:
          === ARES OPENING === {ares_position}
          === ERIS REBUTTAL === {eris_counter}
          === ARES REBUTTAL === {ares_rebuttal or 'N/A'}
          Synthesize the debate. Where ares and eris disagree, determine who has stronger evidence.
          Produce final synthesized verdict: APPROVE or REJECT with reasoned synthesis.
          Output your verdict as your final response.")

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
  - Agent (name + team_name): spawn teammates (FOREGROUND for sequential debate)
  - SendMessage: inter-agent coordination only (NOT for agent→leader communication)
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
