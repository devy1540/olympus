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
- TEAMMATE RESPONSE RULE: When a teammate goes idle without sending results,
  send a follow-up: SendMessage(to: "{agent}", "Report your findings now via SendMessage. Keep under 5000 chars.")
  Retry up to 3 times. NEVER do the agent's work directly — this violates §0.
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
        prompt: "You are Zeus, planner and tie-breaker in a committee debate.
          You will debate across multiple rounds. Build on previous arguments.
          You may communicate directly with 'ares' and 'eris'.
          Artifact directory: ${ARTIFACT_DIR}/
          Wait for messages — do not act until prompted.")
  olympus_register_agent_spawn(pipeline_id, "zeus")

IF "ares" not in team:
  Agent(name: "ares", team_name: ${TEAM},
        subagent_type: "olympus:ares",
        prompt: "You are Ares, engineering critic in a committee debate.
          Evaluate from technical feasibility, maintainability, scalability.
          You may communicate directly with 'zeus' and 'eris'.
          Wait for messages — do not act until prompted.")
  olympus_register_agent_spawn(pipeline_id, "ares")

IF "eris" not in team:
  Agent(name: "eris", team_name: ${TEAM},
        subagent_type: "olympus:eris",
        prompt: "You are Eris, devil's advocate in a committee debate.
          Challenge ALL positions. Apply fallacy-catalog.md.
          Wait for messages — do not act until prompted.")
  olympus_register_agent_spawn(pipeline_id, "eris")

Spawn UX critic (general-purpose, always fresh):
  Agent(name: "ux-critic", team_name: ${TEAM},
        prompt: "You are a UX critic in a committee debate.
          Evaluate from user experience, accessibility, usability.
          Wait for messages — do not act until prompted.")
  olympus_register_agent_spawn(pipeline_id, "ux-critic")
```

---

## Step 4: Debate Rounds (max 3)

```
FOR each round (max 3):

  1. Each committee member presents position (send in parallel):
     SendMessage(to: "zeus", summary: "Round {n} 입장 제시",
       "Read ${ARTIFACT_DIR}/debate-frame.json.
        {If round > 1: 'Previous positions: {summary of last round}'}
        Present: preferred option + rationale + pros/cons of others.
        Include evidence (file:line if applicable). Report to leader.")
     SendMessage(to: "ares", summary: "Round {n} 입장 제시", ...)
     SendMessage(to: "ux-critic", summary: "Round {n} 입장 제시", ...)

     WAIT for all → leader collects positions

  2. Identify disagreements:
     Compare each member's preference. Articulate points of disagreement.

  3. Cross-questioning (if disagreements):
     SendMessage(to: "ares", summary: "반박",
       "Zeus argues: {zeus_position}. Counter-argue with evidence.")
     SendMessage(to: "zeus", summary: "반박",
       "Ares argues: {ares_position}. Respond with evidence.")
     WAIT for rebuttals

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
SendMessage(to: "eris", summary: "DA 챌린지",
  "Read all committee positions from previous rounds.
   Challenge:
     - Weaknesses of the consensus option
     - Overlooked strengths of rejected options
     - Logical fallacies per fallacy-catalog.md
   Report challenges to leader.")

WAIT → receive eris challenges
olympus_record_execution(pipeline_id, "agora", "eris", ...)

Committee response (if needed):
  Forward challenges to committee members via SendMessage
  Re-measure consensus if changed
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

Generate recommendation.md:
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
  | recommendation.md | 6 | Leader | User |
</Artifact_Contracts>
