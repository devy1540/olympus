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

- PROACTIVE SPAWN RULE (§6.3): Every Agent() call MUST include the agent's IMMEDIATE TASK
  in the prompt. NEVER use "Wait for messages — do not act until prompted."
  The agent starts working the moment it spawns. SendMessage is ONLY for follow-up tasks.

- MANDATORY CONSULTATION (§7): ares ↔ poseidon must cross-reference findings before reporting.
  Reports lacking cross-reference consultation are incomplete — send agent back to consult.

- SEQUENTIAL SPAWN: helios first → ares+poseidon parallel → eris DA challenge.
  Wait for prerequisite agent results before spawning dependent agents.

- RESPONSE RULE: If a teammate does not report within reasonable time:
  1. SendMessage(to: "{agent}", "Report your findings now. Include consultation results. Keep under 5000 chars.")
  2. Retry up to 3 times.
  3. NEVER do the agent's work directly — this violates §0.
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
        subagent_type: "olympus:helios",
        run_in_background: true,
        prompt: "You are Helios in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
          IMMEDIATE TASK: Generate analysis perspectives.
          DO NOT write files — you are read-only.
          Read ${ARTIFACT_DIR}/spec.md. Read codebase-context.md if present.
          Read source-catalog.md if present.
          Evaluate 6 complexity dimensions: Domain, Technical, Risk, Stakeholders, Timeline, Novelty.
          Derive 3-6 orthogonal perspectives. Apply quality gate (overlap < 20%).
          Map analyst agents: Code quality → ares, Security → poseidon, Architecture → zeus.
          When done: SendMessage(to: 'leader', summary: '관점 생성 완료', '{perspectives}')
          Then STAY AVAILABLE.")
  olympus_register_agent_spawn(pipeline_id, "helios")

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
  Agent(name: "ares", team_name: ${TEAM},
        subagent_type: "olympus:ares",
        run_in_background: true,
        prompt: "You are Ares in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
          IMMEDIATE TASK: Analyze from Code Quality perspective.
          DO NOT write files — you are read-only.
          Read ${ARTIFACT_DIR}/spec.md, context.md, perspectives.md.
          Read source-scope-analyst.md if present.
          Include file:line evidence for all findings.
          MANDATORY CROSS-REFERENCE: After your initial analysis, share key findings with 'poseidon':
            SendMessage(to: 'poseidon', summary: '코드품질→보안 크로스레퍼런스',
              'My key findings: {top 3 issues}. Questions:
               1. Do any of these have security implications?
               2. Are there security concerns I should factor into priority?')
          Wait for poseidon's response. Incorporate security feedback into final report.
          When done: SendMessage(to: 'leader', summary: '코드 품질 분석 완료',
            '{findings + poseidon consultation log}')
          Then STAY AVAILABLE for Tribunal.")
  olympus_register_agent_spawn(pipeline_id, "ares")

IF "poseidon" not in team:
  Agent(name: "poseidon", team_name: ${TEAM},
        subagent_type: "olympus:poseidon",
        run_in_background: true,
        prompt: "You are Poseidon in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
          IMMEDIATE TASK: Analyze from Security perspective.
          DO NOT write files — you are read-only.
          Read ${ARTIFACT_DIR}/spec.md, context.md, perspectives.md.
          OWASP Top 10 + project-specific security scan. Include file:line evidence.
          MANDATORY CROSS-REFERENCE: After your initial analysis, share key findings with 'ares':
            SendMessage(to: 'ares', summary: '보안→코드품질 크로스레퍼런스',
              'My security findings: {top concerns}. Questions:
               1. Do the code quality issues you found compound these risks?
               2. Any refactoring that could inadvertently fix/worsen security?')
          Wait for ares's response. Incorporate quality feedback into final report.
          When done: SendMessage(to: 'leader', summary: '보안 분석 완료',
            '{findings + ares consultation log}')
          Then STAY AVAILABLE.")
  olympus_register_agent_spawn(pipeline_id, "poseidon")

IF architecture perspective AND "zeus" not in team:
  Agent(name: "zeus", team_name: ${TEAM},
        subagent_type: "olympus:zeus",
        run_in_background: true,
        prompt: "You are Zeus in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
          IMMEDIATE TASK: Analyze from Architecture perspective.
          DO NOT write files — you are read-only.
          Read ${ARTIFACT_DIR}/spec.md, context.md, perspectives.md.
          Analyze from Architecture perspective (Analysis_Mode, not Planning).
          CROSS-REFERENCE: Share architectural concerns with 'ares' and 'poseidon':
            SendMessage(to: 'ares', summary: '아키텍처→코드품질 크로스레퍼런스', '{concerns}')
            SendMessage(to: 'poseidon', summary: '아키텍처→보안 크로스레퍼런스', '{concerns}')
          Incorporate their feedback, then report FINAL findings to leader.
          When done: SendMessage(to: 'leader', summary: '아키텍처 분석 완료',
            '{findings + consultation log}')
          Then STAY AVAILABLE.")
  olympus_register_agent_spawn(pipeline_id, "zeus")

Note: ares and poseidon run IN PARALLEL. Both do initial analysis, then CROSS-REFERENCE.
The cross-reference exchange happens directly between them — leader only receives final results.
olympus_log_collaboration(pipeline_id, "ares", "poseidon", "코드품질↔보안 크로스레퍼런스")

For dynamic perspectives from Helios (already-spawned agents):
  SendMessage(to: appropriate analyst, ...)

WAIT for ALL analysts → leader aggregates into analyst-findings.md
olympus_record_execution for each analyst
```

---

## Step 6: Eris DA Challenge

```
IF "eris" not in team:
  Agent(name: "eris", team_name: ${TEAM},
        subagent_type: "olympus:eris",
        run_in_background: true,
        prompt: "You are Eris in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
          IMMEDIATE TASK: Challenge all analyst findings with DA methodology.
          DO NOT write files — you are read-only.
          Read ${ARTIFACT_DIR}/analyst-findings.md.
          Read docs/shared/fallacy-catalog.md.
          Read source-scope-da.md if present.
          Challenge all findings: detect fallacies, false positives, missing evidence.
          Max 2 challenge-response rounds.
          BLOCKING_QUESTIONs: tool-solvable → resolve, user-only → flag.
          Verdict: SUFFICIENT / NOT_SUFFICIENT / NEEDS_TRIBUNAL.
          When done: SendMessage(to: 'leader', summary: 'DA 챌린지 완료 — {verdict}',
            '{evaluation + challenge log}')
          Then STAY AVAILABLE.")
  olympus_register_agent_spawn(pipeline_id, "eris")

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
