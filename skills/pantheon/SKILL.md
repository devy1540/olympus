---
name: pantheon
description: "Council of the Gods — multi-perspective analysis pipeline"
---

<Purpose>
Analyze problems from multiple perspectives and validate through adversarial challenge.
All agents operate as teammates for inter-perspective communication and debate.
</Purpose>

<Execution_Policy>
- This skill uses FULL TEAMMATE mode. ALL agents are teammates in one team.
- Each Step MUST call the specified MCP tool. Do NOT skip MCP calls.
- Do NOT perform agent work directly. Helios MUST generate perspectives, Eris MUST challenge.
- Analyst agents MUST run in parallel (send all SendMessages before waiting).
- Eris DA challenge is MANDATORY — do NOT skip even if analysts agree.
- Leader handles ONLY: team management, gate checks, artifact writing.
- If MCP tools are unavailable, proceed without MCP — hooks provide fallback.
- IMPORTANT: Do NOT skip ToolSearch at Step 0.
</Execution_Policy>

<Team_Structure>
  team_name: "pantheon-${CLAUDE_SESSION_ID}"
  (When called from Odyssey, use the Odyssey team instead)

  Teammates:
  | Agent | Role | Comm Targets |
  |-------|------|-------------|
  | hermes | Codebase exploration (if needed) | leader |
  | helios | Complexity assessment + perspective generation | leader |
  | ares | Code quality analysis | eris (responds to challenges), leader |
  | poseidon | Security analysis | leader |
  | zeus | Architecture analysis (Analysis_Mode) | leader |
  | eris | DA challenge of all findings | analysts (challenges), leader |
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
     TeamCreate(team_name: "pantheon-${CLAUDE_SESSION_ID}")
   ELSE:
     Use existing Odyssey team (${TEAM})

2. olympus_start_pipeline(skill: "pantheon", pipeline_id: ...)
3. Create artifact directory: .olympus/pantheon-{YYYYMMDD}-{short-uuid}/
```

---

## Step 2: Source Scope Mapping (optional)

```
Activated when: --scope flag is used OR MCP resources are detected.
Default: skip (use local codebase + spec.md only).

When activated:
  1. Enumerate MCP resources via ListMcpResourcesTool
  2. AskUserQuestion (multiSelect): select data sources
  3. Collect external sources (URL → WebFetch, file → Read)
  4. Generate source-catalog.md, source-scope-analyst.md, source-scope-da.md
```

---

## Step 3: Helios Perspective Generation

```
IF "helios" not in team:
  Agent(name: "helios", team_name: ${TEAM},
        subagent_type: "olympus:helios", prompt: "...")
  olympus_register_agent_spawn(pipeline_id, "helios")

SendMessage(to: "helios", summary: "관점 생성",
  "Read ${ARTIFACT_DIR}/spec.md. Read codebase-context.md if present.
   Read source-catalog.md if present.
   Evaluate 6 complexity dimensions: Domain, Technical, Risk, Stakeholders, Timeline, Novelty.
   Derive 3-6 orthogonal perspectives. Apply quality gate (overlap < 20%).
   Map analyst agents: Code quality → ares, Security → poseidon, Architecture → zeus.
   Report to leader.")

WAIT → leader writes perspectives.md
olympus_record_execution(pipeline_id, "pantheon", "helios", ...)
```

---

## Step 4: Perspective Approval

```
AskUserQuestion:
  question: "다음 관점으로 분석합니다:"
  options: ["진행", "관점 추가", "관점 제거", "관점 수정"]

Confirmed perspectives → perspectives.md (immutable)
Generate context.md: spec + perspectives + ontology synthesis
```

---

## Step 5: Parallel Analysis

```
Spawn analyst teammates (lazy — skip if already in team):

IF "ares" not in team:
  Agent(name: "ares", team_name: ${TEAM}, subagent_type: "olympus:ares", prompt: "...")
  olympus_register_agent_spawn(pipeline_id, "ares")

IF "poseidon" not in team:
  Agent(name: "poseidon", team_name: ${TEAM}, subagent_type: "olympus:poseidon", prompt: "...")
  olympus_register_agent_spawn(pipeline_id, "poseidon")

IF architecture perspective AND "zeus" not in team:
  Agent(name: "zeus", team_name: ${TEAM}, subagent_type: "olympus:zeus", prompt: "...")
  olympus_register_agent_spawn(pipeline_id, "zeus")

Send ALL analysis tasks in parallel (do not wait between sends):

SendMessage(to: "ares", summary: "코드 품질 분석",
  "Read ${ARTIFACT_DIR}/spec.md, context.md, perspectives.md.
   Read source-scope-analyst.md if present.
   Analyze from Code Quality perspective. Include file:line evidence.
   Report findings to leader.")

SendMessage(to: "poseidon", summary: "보안 분석",
  "Read ${ARTIFACT_DIR}/spec.md, context.md, perspectives.md.
   Analyze from Security perspective (OWASP, CWE).
   Report findings to leader.")

SendMessage(to: "zeus", summary: "아키텍처 분석",
  "Read ${ARTIFACT_DIR}/spec.md, context.md, perspectives.md.
   Analyze from Architecture perspective (Analysis_Mode, not Planning).
   Report findings to leader.")

For dynamic perspectives from Helios:
  SendMessage(to: appropriate analyst, ...)

WAIT for ALL analysts → leader aggregates into analyst-findings.md
olympus_record_execution for each analyst
```

---

## Step 6: Eris DA Challenge

```
IF "eris" not in team:
  Agent(name: "eris", team_name: ${TEAM}, subagent_type: "olympus:eris", prompt: "...")
  olympus_register_agent_spawn(pipeline_id, "eris")

SendMessage(to: "eris", summary: "DA 챌린지",
  "Read ${ARTIFACT_DIR}/analyst-findings.md.
   Read docs/shared/fallacy-catalog.md.
   Read source-scope-da.md if present.
   Challenge all findings: detect fallacies, false positives, missing evidence.
   Max 2 challenge-response rounds.
   BLOCKING_QUESTIONs: tool-solvable → resolve, user-only → flag.
   Verdict: SUFFICIENT / NOT_SUFFICIENT / NEEDS_TRIBUNAL.
   Report to leader.")

WAIT → leader writes da-evaluation.md
olympus_record_execution(pipeline_id, "pantheon", "eris", ...)
```

---

## Step 7: Consensus & Synthesis

```
Apply consensus-levels.md criteria:
  olympus_gate_check(pipeline_id, "consensus", consensus_percentage)

IF consensus >= threshold (Normal: 67%, Hell: unanimous):
  → Generate analysis.md (synthesis of all perspectives)
  → Proceed to Step 8

ELSE:
  → Feedback loop (max 2 iterations):
    - Save current to prior-iterations.md
    - Add new perspectives only
    - Re-run Step 5-6
    - After 2 failures → AskUserQuestion

analysis.md structure:
  ## Per-Perspective Summary
  ## Cross-Perspective Findings
  ## DA Verification Results
  ## Consensus Level and Dissent
  ## Recommendations
```

---

## Step 8: Teardown

```
IF standalone:
  Shutdown all teammates → TeamDelete
ELSE:
  Teammates persist for Odyssey's next phase
```

</Steps>

<Tool_Usage>
  MCP Tools:
  - olympus_start_pipeline: Step 1 (MUST)
  - olympus_register_agent_spawn: after each spawn (MUST)
  - olympus_gate_check: Step 7 consensus gate (MUST)
  - olympus_record_execution: after each analyst (SHOULD)

  Team Tools:
  - TeamCreate: Step 1 (standalone only)
  - Agent (name + team_name): spawn teammates
  - SendMessage: all communication (parallel for analysts!)
  - TeamDelete: Step 8 (standalone only)
</Tool_Usage>

<Artifact_Contracts>
  | File | Step | Writer | Readers |
  |------|------|--------|---------|
  | source-catalog.md | 2 | Leader | All agents |
  | source-scope-analyst.md | 2 | Leader | Analyst agents |
  | source-scope-da.md | 2 | Leader | Eris |
  | perspectives.md | 3 | Leader (from helios) | All agents |
  | context.md | 4 | Leader | All agents |
  | analyst-findings.md | 5 | Leader (from analysts) | Eris |
  | da-evaluation.md | 6 | Leader (from eris) | Consensus |
  | prior-iterations.md | 7 | Leader | Re-entry |
  | analysis.md | 7 | Leader | Downstream skills |
</Artifact_Contracts>
