---
name: agora
description: "The Forum — committee debate for technical decision-making"
---

<Purpose>
Reach technical decisions through structured committee debate with consensus-driven discourse.
Committee members operate as teammates for multi-round debate with context retention.
</Purpose>

<Execution_Policy>
- This skill uses FULL TEAMMATE mode. All committee members are teammates.
- Each Step MUST call the specified MCP tool. Do NOT skip MCP calls.
- Do NOT simulate debate internally. Spawn agents and delegate via SendMessage.
- Debate rounds require separate agent outputs — each round builds on previous.
- Eris DA challenge is MANDATORY — do NOT skip even if committee agrees.
- Leader handles ONLY: framing, round management, consensus measurement, report.
- IMPORTANT: Do NOT skip ToolSearch at Step 0.
- PROACTIVE SPAWN RULE (§6.3): Every Agent() call MUST include IMMEDIATE TASK in prompt.
  NEVER use "Wait for messages — do not act until prompted."
- MANDATORY CONSULTATION (§7): Debate members MUST react to each other's prior statements,
  not present independent opinions. Round 2+ responses MUST explicitly reference a prior speaker.
  A position that does not engage with any prior argument is incomplete.
- RESPONSE RULE: If a teammate does not report within reasonable time:
  1. SendMessage(to: "{agent}", "Report your findings now. Include consultation results. Keep under 5000 chars.")
  2. Retry up to 3 times.
  3. NEVER do the agent's work directly — this violates §0.
- RESULT CAPTURE RULE: Read-only agents deliver results via SendMessage(to: "team-lead").
  Orchestrator writes artifacts from these results. Write-capable agents write files directly.
- SEQUENTIAL SPAWN: committee members spawned in Step 3 → debate rounds sequential (Step 4).
  Wait for prerequisite agent results before spawning dependent agents.
</Execution_Policy>

<Team_Structure>
  team_name: "agora-${CLAUDE_SESSION_ID}"
  (When called from Odyssey Phase 4 deadlock, use the Odyssey team instead)

  Teammates:
  | Agent | Role | Comm Targets |
  |-------|------|-------------|
  | zeus | Planner / tie-breaker | ares, eris (debate), leader |
  | ares | Engineering critic | zeus, eris (debate), leader |
  | eris | Devil's Advocate | zeus, ares (challenges), leader |
  | (UX critic) | UX perspective | leader |

  Direct communication: zeus ↔ ares ↔ eris (cross-questioning)
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
     TeamCreate(team_name: "agora-${CLAUDE_SESSION_ID}")
   ELSE:
     Use existing Odyssey team (${TEAM})

2. olympus_start_pipeline(skill: "agora", pipeline_id: ...)
3. Create artifact directory: .olympus/agora-{YYYYMMDD}-{short-uuid}/
```

---

## Step 2: Question Framing

```
1. Extract decision from user input
2. Convert to 2-4 concrete options
3. AskUserQuestion:
   "The debate will be structured as follows. Any modifications?"
   ["Proceed", "Modify options", "Add context", "Cancel"]

4. Generate debate-frame.json:
   { question, options: [{ id, title, description }], context }
   Save to ${ARTIFACT_DIR}/
```

---

## Step 3: Committee Assembly

```
Spawn committee teammates (lazy):

Note: Agora uses per-round spawns (see Step 4). Committee members join only when needed for
their round — there is no persistent assembly phase. Step 3 assembles the debate frame only.

# Assembly: Register the debate frame and roles (no agent spawns here)
# Agents are spawned on-demand per round in Step 4 as "zeus-r{n}", "ares-r{n}", etc.

# No record_execution here — per-round agents are recorded in Step 4
```

---

## Step 4: Debate Rounds (max 3)

```
FOR each round (max 3):

  1. Spawn all debaters IN PARALLEL (BACKGROUND) with round context:

     Round 1 — Initial positions:
     Agent(name: "zeus-r{n}", team_name: ${TEAM}, subagent_type: "olympus:zeus",
       run_in_background: true,
       prompt: "LEADER_NAME: team-lead
         IMMEDIATE TASK: Round {n} debate position.
         Read ${ARTIFACT_DIR}/debate-frame.json.
         Present: preferred option + rationale + pros/cons of others.
         Include evidence (file:line if applicable).
         When done: SendMessage(to: 'team-lead', summary: 'zeus-r{n} 포지션', '{full position}')")

     Agent(name: "ares-r{n}", team_name: ${TEAM}, subagent_type: "olympus:ares",
       run_in_background: true,
       prompt: "LEADER_NAME: team-lead
         IMMEDIATE TASK: Round {n} debate position.
         DO NOT write files — you are read-only.
         Read ${ARTIFACT_DIR}/debate-frame.json.
         Present: preferred option from technical perspective + evidence.
         When done: SendMessage(to: 'team-lead', summary: 'ares-r{n} 포지션', '{full position}')")

     Agent(name: "ux-r{n}", team_name: ${TEAM},
       run_in_background: true,
       prompt: "LEADER_NAME: team-lead
         IMMEDIATE TASK: Round {n} debate position.
         DO NOT write files — you are read-only.
         Read ${ARTIFACT_DIR}/debate-frame.json.
         Present: preferred option from UX perspective + evidence.
         When done: SendMessage(to: 'team-lead', summary: 'ux-r{n} 포지션', '{full position}')")

     olympus_register_agent_spawn(pipeline_id, "zeus-r{n}")
     olympus_register_agent_spawn(pipeline_id, "ares-r{n}")
     # NOTE: ux-r{n} is a general-purpose agent — skip register_spawn (not in agent registry)
     olympus_pipeline_status(pipeline_id)  # verify olympus round debaters are registered
     DEADLOCK FALLBACK: If 3 minutes elapse without all members completing:
       → SendMessage(to: non-responding member, "Round timeout. Submit your current position now.")
       → After 1 additional minute: proceed with available responses, note missing positions in committee-positions.md.

     WAIT for all completion notifications → leader collects positions
     → Write committee-positions.md (aggregate all round positions)

     Round {n > 1} — REACTIVE positions (include prior round context in prompt):
     Same pattern but prompt includes: "Prior round positions: {summary}
       MANDATORY: Reference a specific prior claim and respond to it."

  2. Identify disagreements:
     Compare each member's preference. Articulate points of disagreement.

  3. Cross-questioning (if disagreements — FOREGROUND sequential):
     ares_rebuttal = Agent(name: "ares-cross", team_name: ${TEAM}, subagent_type: "olympus:ares",
       prompt: "LEADER_NAME: team-lead
         IMMEDIATE TASK: Cross-questioning rebuttal — counter Zeus's argument.
         DO NOT write files — you are read-only.
         Zeus argues: {zeus_position_verbatim}. Counter-argue with specific technical evidence.
         When done: SendMessage(to: 'team-lead', summary: 'ares 크로스반박 완료', '{rebuttal}')")
     olympus_register_agent_spawn(pipeline_id, "ares-cross")

     zeus_rebuttal = Agent(name: "zeus-cross", team_name: ${TEAM}, subagent_type: "olympus:zeus",
       prompt: "LEADER_NAME: team-lead
         IMMEDIATE TASK: Cross-questioning rebuttal — respond to Ares's objections.
         Ares argues: {ares_position_verbatim}. Respond to ares's specific objections.
         When done: SendMessage(to: 'team-lead', summary: 'zeus 크로스반박 완료', '{rebuttal}')")
     olympus_register_agent_spawn(pipeline_id, "zeus-cross")
     olympus_record_execution(pipeline_id, "agora", "ares-cross", ...)
     olympus_record_execution(pipeline_id, "agora", "zeus-cross", ...)
     olympus_log_collaboration(pipeline_id, "ares", "zeus", "교차 반박: ares↔zeus 논거 충돌")

  olympus_record_execution(pipeline_id, "agora", "zeus-r{n}", ...)
  olympus_record_execution(pipeline_id, "agora", "ares-r{n}", ...)

  4. Measure consensus (per consensus-levels.md):
     - Strong (3/3): unanimous → exit
     - Working (2/3): majority → record dissent, exit
     - Partial: next round needed
     - No: next round or escalation

  5. IF consensus reached OR round == 3: proceed to Step 5
```

---

## Step 5: Eris Challenge

```
eris_challenge = Agent(name: "eris-da", team_name: ${TEAM},
    subagent_type: "olympus:eris",
    prompt: "LEADER_NAME: team-lead
      IMMEDIATE TASK: Devil's Advocate challenge — find weaknesses in the consensus position.
      Artifact directory: ${ARTIFACT_DIR}/
      DO NOT write files — you are read-only.
      Read ${ARTIFACT_DIR}/committee-positions.md for all prior round positions.
      Read docs/shared/fallacy-catalog.md.
      Challenge each claim by name — do not issue abstract challenges.
      Challenge areas:
        - Weaknesses of the consensus option
        - Overlooked strengths of rejected options
        - Logical fallacies (cite the fallacy name from fallacy-catalog.md)
      When done: SendMessage(to: 'team-lead', summary: 'eris DA 도전 완료', '{challenges}')")
olympus_register_agent_spawn(pipeline_id, "eris-da")
olympus_record_execution(pipeline_id, "agora", "eris-da", ...)

Committee response (MANDATORY — FOREGROUND sequential):
  zeus_response = Agent(name: "zeus-resp", team_name: ${TEAM}, subagent_type: "olympus:zeus",
    prompt: "LEADER_NAME: team-lead
      IMMEDIATE TASK: Respond to Eris's DA challenge on your position.
      Eris challenged your position: {eris_challenge}. Respond specifically.
      When done: SendMessage(to: 'team-lead', summary: 'zeus DA 응답 완료', '{response}')")
  olympus_register_agent_spawn(pipeline_id, "zeus-resp")
  ares_response = Agent(name: "ares-resp", team_name: ${TEAM}, subagent_type: "olympus:ares",
    prompt: "LEADER_NAME: team-lead
      IMMEDIATE TASK: Respond to Eris's DA challenge on your position.
      DO NOT write files — you are read-only.
      Eris challenged your position: {eris_challenge}. Respond specifically.
      When done: SendMessage(to: 'team-lead', summary: 'ares DA 응답 완료', '{response}')")
  olympus_register_agent_spawn(pipeline_id, "ares-resp")
  olympus_record_execution(pipeline_id, "agora", "zeus-resp", ...)
  olympus_record_execution(pipeline_id, "agora", "ares-resp", ...)
  olympus_log_collaboration(pipeline_id, "eris", "zeus", "DA Challenge: eris↔committee 응답")
  → Write da-challenges.md from eris_challenge + committee responses
  → Re-measure consensus if changed
```

---

## Step 6: Consensus → Recommendation

```
Normal mode:
  Working or above → proceed
  Partial → Zeus tie-breaker decision
  No → escalate to user

Hell mode (--hell):
  Strong required (unanimous)
  Additional rounds if not met

Gate check:
  olympus_gate_check(pipeline_id, "consensus", consensus_percentage)
  IF gate fails:
    next = olympus_next_action(pipeline_id)
    # next.action: retry_phase, advance_phase, or pipeline_complete

Generate decision.md:
  ## Decision: {selected option}
  ### Rationale
  ### Committee Positions (table)
  ### Dissent
  ### DA Challenges (Eris)
  ### Consensus Level
  ### Implementation Notes
```

---

## Step 7: Teardown

```
IF standalone:
  Shutdown all teammates → TeamDelete
ELSE:
  Teammates persist for Odyssey
```

</Steps>

<Tool_Usage>
  MCP Tools:
  - olympus_start_pipeline: Step 1 (MUST)
  - olympus_register_agent_spawn: after each spawn (MUST)
  - olympus_gate_check: Step 6 consensus (MUST)
  - olympus_next_action: consensus failure recovery (SHOULD)
  - olympus_pipeline_status: after parallel debater spawn per round (SHOULD)
  - olympus_log_collaboration: after each cross-questioning exchange between members (SHOULD)
  - olympus_record_execution: after each round (SHOULD)

  Team Tools:
  - TeamCreate: Step 1 (standalone only)
  - Agent (name + team_name): spawn committee + eris
  - SendMessage: PARALLEL for round positions, SEQUENTIAL for cross-questioning
  - TeamDelete: Step 7 (standalone only)
</Tool_Usage>

<Artifact_Contracts>
  | File | Step | Writer | Readers |
  |------|------|--------|---------|
  | debate-frame.json | 2 | Leader | All members |
  | committee-positions.md | 4 | Leader (from committee) | eris |
  | da-challenges.md | 5 | Leader (from eris) | committee |
  | decision.md | 6 | Leader | User |
</Artifact_Contracts>
