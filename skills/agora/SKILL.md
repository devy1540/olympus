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
- RESPONSE RULE: If teammate doesn't report, retry up to 3 times. NEVER do agent's work directly.
- RESULT CAPTURE RULE: Read-only agents deliver results via SendMessage(to: "team-lead").
  Orchestrator writes artifacts from these results. Write-capable agents write files directly.
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

IF "zeus" not in team:
  Agent(name: "zeus", team_name: ${TEAM},
        subagent_type: "olympus:zeus",
        run_in_background: false,
        prompt: "You are Zeus, planner and tie-breaker in a committee debate.
          LEADER_NAME: team-lead
          IMMEDIATE TASK: You will present positions and respond to other members each round.
          CONSULTATION: In Round 2+, you MUST explicitly reference ares's or eris's prior argument
          and either agree, rebut, or qualify it. Independent opinions without engagement are incomplete.
          You may send direct cross-questions to 'ares' and 'eris' via SendMessage at any time.
          Artifact directory: ${ARTIFACT_DIR}/
          Output your results as your final response.")
  olympus_register_agent_spawn(pipeline_id, "zeus")

IF "ares" not in team:
  Agent(name: "ares", team_name: ${TEAM},
        subagent_type: "olympus:ares",
        run_in_background: false,
        prompt: "You are Ares, engineering critic in a committee debate.
          LEADER_NAME: team-lead
          IMMEDIATE TASK: You will evaluate options from technical feasibility, maintainability, scalability.
          CONSULTATION: In Round 2+, you MUST explicitly reference zeus's or eris's prior argument
          and either agree, rebut, or qualify it with technical evidence. Independent opinions are incomplete.
          You may send direct cross-questions to 'zeus' and 'eris' via SendMessage at any time.
          Output your results as your final response.")
  olympus_register_agent_spawn(pipeline_id, "ares")

IF "eris" not in team:
  Agent(name: "eris", team_name: ${TEAM},
        subagent_type: "olympus:eris",
        run_in_background: false,
        prompt: "You are Eris, devil's advocate in a committee debate.
          LEADER_NAME: team-lead
          IMMEDIATE TASK: You will challenge ALL positions using fallacy-catalog.md.
          CONSULTATION: You MUST target specific claims made by zeus or ares — not abstract positions.
          Quote the claim you are challenging, then deliver your challenge.
          You may send direct challenges to 'zeus' and 'ares' via SendMessage between rounds.
          Output your results as your final response.")
  olympus_register_agent_spawn(pipeline_id, "eris")

Spawn UX critic (general-purpose, always fresh):
  Agent(name: "ux-critic", team_name: ${TEAM},
        run_in_background: false,
        prompt: "You are a UX critic in a committee debate.
          LEADER_NAME: team-lead
          IMMEDIATE TASK: You will evaluate options from user experience, accessibility, usability.
          CONSULTATION: In Round 2+, you MUST reference a prior speaker's claim and respond to it
          from a UX lens. Independent opinions without engagement are incomplete.
          Output your results as your final response.")
  olympus_register_agent_spawn(pipeline_id, "ux-critic")
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
         Read ${ARTIFACT_DIR}/debate-frame.json.
         Present: preferred option + rationale + pros/cons of others.
         Include evidence (file:line if applicable).
         Output your position as your final response.")

     Agent(name: "ares-r{n}", team_name: ${TEAM}, subagent_type: "olympus:ares",
       run_in_background: true,
       prompt: "LEADER_NAME: team-lead
         DO NOT write files — you are read-only.
         Read ${ARTIFACT_DIR}/debate-frame.json.
         Present: preferred option from technical perspective + evidence.
         Output your position as your final response.")

     Agent(name: "ux-r{n}", team_name: ${TEAM},
       run_in_background: true,
       prompt: "LEADER_NAME: team-lead
         DO NOT write files — you are read-only.
         Read ${ARTIFACT_DIR}/debate-frame.json.
         Present: preferred option from UX perspective + evidence.
         Output your position as your final response.")

     olympus_register_agent_spawn(pipeline_id, "zeus-r{n}")
     olympus_register_agent_spawn(pipeline_id, "ares-r{n}")
     olympus_register_agent_spawn(pipeline_id, "ux-r{n}")
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
         DO NOT write files — you are read-only.
         Zeus argues: {zeus_position_verbatim}. Counter-argue with specific technical evidence.
         Output your rebuttal as your final response.")
     olympus_register_agent_spawn(pipeline_id, "ares-cross")

     zeus_rebuttal = Agent(name: "zeus-cross", team_name: ${TEAM}, subagent_type: "olympus:zeus",
       prompt: "LEADER_NAME: team-lead
         Ares argues: {ares_position_verbatim}. Respond to ares's specific objections.
         Output your rebuttal as your final response.")
     olympus_register_agent_spawn(pipeline_id, "zeus-cross")
     olympus_record_execution(pipeline_id, "agora", "ares-cross", ...)
     olympus_record_execution(pipeline_id, "agora", "zeus-cross", ...)

  olympus_record_execution(pipeline_id, "agora", "zeus-r{n}", ...)
  olympus_record_execution(pipeline_id, "agora", "ares-r{n}", ...)
  olympus_record_execution(pipeline_id, "agora", "ux-r{n}", ...)

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
      DO NOT write files — you are read-only.
      Read all committee positions from previous rounds.
      Challenge each claim by name — do not issue abstract challenges.
      Challenge areas:
        - Weaknesses of the consensus option
        - Overlooked strengths of rejected options
        - Logical fallacies per fallacy-catalog.md (cite the fallacy name)
      Output your challenges as your final response.")
olympus_register_agent_spawn(pipeline_id, "eris")
olympus_record_execution(pipeline_id, "agora", "eris", ...)

Committee response (MANDATORY — FOREGROUND sequential):
  zeus_response = Agent(name: "zeus-resp", team_name: ${TEAM}, subagent_type: "olympus:zeus",
    prompt: "LEADER_NAME: team-lead
      Eris challenged your position: {eris_challenge}. Respond specifically.
      Output your response as your final response.")
  olympus_register_agent_spawn(pipeline_id, "zeus-resp")
  ares_response = Agent(name: "ares-resp", team_name: ${TEAM}, subagent_type: "olympus:ares",
    prompt: "LEADER_NAME: team-lead
      DO NOT write files — you are read-only.
      Eris challenged your position: {eris_challenge}. Respond specifically.
      Output your response as your final response.")
  olympus_register_agent_spawn(pipeline_id, "ares-resp")
  olympus_record_execution(pipeline_id, "agora", "zeus-resp", ...)
  olympus_record_execution(pipeline_id, "agora", "ares-resp", ...)
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
