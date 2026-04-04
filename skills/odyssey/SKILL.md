---
name: odyssey
description: "The Grand Journey — Oracle→Genesis→Pantheon→Plan→Execute→Tribunal full pipeline"
---

<Purpose>
Execute the complete Olympus pipeline from requirements to verified implementation.
All agents operate as teammates in a single persistent team for cross-phase context retention.
</Purpose>

<Execution_Policy>
- This skill uses FULL TEAMMATE mode. ALL agents are teammates in one team.
- Each Step MUST call the specified MCP tool. Do NOT skip MCP calls.
- Do NOT perform agent work directly. Spawn teammates and delegate via SendMessage.
- Teammates persist across phases — reuse existing teammates instead of re-spawning.
- Leader handles ONLY: team management, phase transitions, gate checks, MCP state, artifact writing for read-only agents.
- If MCP tools are unavailable (binary not installed), proceed without MCP — hooks provide fallback validation.
- IMPORTANT: Do NOT skip ToolSearch at Step 0.
- TEAMMATE RESPONSE RULE: When a teammate goes idle without sending results,
  send a follow-up: SendMessage(to: "{agent}", "Report your findings now via SendMessage. Keep under 5000 chars.")
  Retry up to 3 times. NEVER do the agent's work directly — this violates §0.
</Execution_Policy>

<Team_Structure>
  team_name: "odyssey-${CLAUDE_SESSION_ID}"

  Lazy-spawned teammates (spawn on first need, persist until teardown):
  | Agent | Phase First Needed | Role |
  |-------|-------------------|------|
  | hermes | Oracle | Codebase exploration |
  | apollo | Oracle | Socratic interview |
  | metis | Oracle | Gap analysis / Genesis wonder |
  | eris | Oracle | DA challenge / Genesis reflect |
  | helios | Pantheon | Perspective generation |
  | ares | Pantheon | Code quality analysis |
  | poseidon | Pantheon | Security analysis |
  | zeus | Planning | Implementation planning |
  | prometheus | Execution | Code implementation |
  | artemis | Execution | Debugging |
  | hephaestus | Execution | Build/test verification |
  | athena | Tribunal | Semantic evaluation |
  | hera | Tribunal | Final verification |
  | themis | Planning | Independent critique |

  Inter-agent direct communication (no leader relay needed):
  - prometheus ↔ hermes (codebase queries during implementation)
  - prometheus ↔ artemis (debugging during implementation)
  - prometheus ↔ hephaestus (quick build checks)
  - apollo ↔ hermes (codebase context during interview)
  - metis ↔ eris (Genesis wonder/reflect loop)
  - ares ↔ eris (Tribunal debate)
</Team_Structure>

<Steps>

## Step 0: Load MCP Tools (REQUIRED FIRST)

```
Call ToolSearch("+olympus pipeline") to load MCP tools.
```

**IMPORTANT**: Do NOT skip this step. Do NOT assume MCP tools are unavailable.

---

## Step 1: Initialize Team + Pipeline

```
1. TeamCreate(team_name: "odyssey-${CLAUDE_SESSION_ID}",
              description: "Odyssey full pipeline team")
   → Save: TEAM = team_name

2. IF olympus_start_pipeline is available:
     olympus_start_pipeline(skill: "odyssey", pipeline_id: "odyssey-${CLAUDE_SESSION_ID}")
     → Receive: { required_agents, first_phase }

3. Create artifact directory:
     .olympus/odyssey-{YYYYMMDD}-{short-uuid}/
     Save: ARTIFACT_DIR = above path

4. Initialize odyssey-state.json in ARTIFACT_DIR
```

**State schema** (conforms to pipeline-states.json):

```json
{
  "id": "odyssey-{YYYYMMDD}-{short-uuid}",
  "team": "odyssey-${CLAUDE_SESSION_ID}",
  "phase": "oracle",
  "transition": null,
  "gates": {
    "ambiguityScore": null,
    "convergenceScore": null,
    "consensusLevel": null,
    "themisVerdict": null,
    "mechanicalPass": null
  },
  "retryTracking": {
    "evaluationPass": 0,
    "maxPasses": 3,
    "feedbackLoopCount": 0,
    "consecutiveFailures": 0,
    "consecutiveDebugFailures": 0,
    "maxDebugCycles": 3
  },
  "activeTeammates": [],
  "genesisEnabled": false,
  "artifacts": {
    "specId": null,
    "genesisId": null,
    "pantheonId": null,
    "tribunalId": null
  }
}
```

---

## Step 2: Oracle Phase

Refine requirements into spec.md through Socratic interview.

```
1. MCP: olympus_next_phase(pipeline_id) → confirm "oracle" is valid

2. Spawn teammates (if not already in team):

   Agent(name: "hermes", team_name: ${TEAM},
         subagent_type: "olympus:hermes",
         prompt: "You are Hermes, a teammate in ${TEAM}.
           Respond to codebase queries via SendMessage.
           Artifact directory: ${ARTIFACT_DIR}/
           Wait for messages — do not act until prompted.")
   olympus_register_agent_spawn(pipeline_id, "hermes")

   Agent(name: "apollo", team_name: ${TEAM},
         subagent_type: "olympus:apollo",
         prompt: "You are Apollo, a teammate in ${TEAM}.
           You retain memory across interview rounds.
           Artifact directory: ${ARTIFACT_DIR}/
           You may query 'hermes' for codebase context.
           Wait for messages — do not act until prompted.")
   olympus_register_agent_spawn(pipeline_id, "apollo")

   Agent(name: "metis", team_name: ${TEAM},
         subagent_type: "olympus:metis",
         prompt: "You are Metis, a teammate in ${TEAM}.
           Artifact directory: ${ARTIFACT_DIR}/
           Wait for messages — do not act until prompted.")
   olympus_register_agent_spawn(pipeline_id, "metis")

   Agent(name: "eris", team_name: ${TEAM},
         subagent_type: "olympus:eris",
         prompt: "You are Eris, a teammate in ${TEAM}.
           Artifact directory: ${ARTIFACT_DIR}/
           Wait for messages — do not act until prompted.")
   olympus_register_agent_spawn(pipeline_id, "eris")

3. Hermes exploration:
   SendMessage(to: "hermes", summary: "코드베이스 탐색",
     "Explore codebase for: {user_input}.
      DO NOT write files — you are read-only.
      Send your findings to leader via SendMessage when done.")
   WAIT for hermes SendMessage → leader writes codebase-context.md from hermes findings
   olympus_record_execution(pipeline_id, "oracle", "hermes", ...)

4. Apollo interview loop:
   SendMessage(to: "apollo", summary: "인터뷰 시작",
     "Read ${ARTIFACT_DIR}/codebase-context.md for project context.
      User requirement: {user_input}. Complexity: {level}.
      Conduct interview via AskUserQuestion. One question at a time.
      After each answer, track ambiguity scores internally.
      DO NOT write files — you are read-only.
      Terminate when ambiguity ≤ 0.2 or max 10 rounds.
      Send interview log + ambiguity scores to leader via SendMessage when done.")
   WAIT for apollo SendMessage → leader writes interview-log.md + ambiguity-scores.json
   olympus_record_execution(pipeline_id, "oracle", "apollo", ...)

5. Ambiguity gate:
   ambiguityScore = read ${ARTIFACT_DIR}/ambiguity-scores.json
   olympus_gate_check(pipeline_id, "ambiguity", ambiguityScore)
   → IF passed: proceed to Metis gap analysis
   → IF failed AND rounds < 10: SendMessage(to: "apollo", "추가 인터뷰 라운드")
   → IF failed AND rounds >= 10: AskUserQuestion with remaining gaps

6. Metis gap analysis:
   SendMessage(to: "metis", summary: "갭 분석",
     "Read ${ARTIFACT_DIR}/interview-log.md and ${ARTIFACT_DIR}/codebase-context.md.
      Perform gap analysis: Missing Questions, Undefined Guardrails, Scope Risks,
      Unvalidated Assumptions, Acceptance Criteria, Edge Cases.
      Report results to leader.")
   WAIT for metis completion → leader writes gap-analysis.md
   olympus_record_execution(pipeline_id, "oracle", "metis", ...)

7. Synthesize spec.md from interview-log.md + gap-analysis.md
   Write ${ARTIFACT_DIR}/spec.md

8. Update odyssey-state.json:
   phase: "genesis" (or "pantheon" if genesis disabled)
   gates.ambiguityScore: {score}
   artifacts.specId: "{oracle-id}"
```

---

## Step 3: Genesis Phase (optional)

Evolve spec through generational refinement.

```
Activation conditions (any):
  - User provides --evolve flag
  - Auto-detect: spec ONTOLOGY items > 10
  - Auto-detect: OPEN_QUESTIONS > 3

When disabled: skip to Step 4.

When enabled:

1. MCP: olympus_next_phase(pipeline_id) → confirm "genesis" is valid

2. Reuse existing teammates (metis, eris already spawned in Oracle):
   SendMessage(to: "metis", summary: "Genesis 모드 전환",
     "Switching to Genesis wonder mode. You will be called repeatedly across generations.
      Build on your earlier Oracle insights — do not repeat explored questions.
      Artifact directory: ${ARTIFACT_DIR}/")

   SendMessage(to: "eris", summary: "Genesis 모드 전환",
     "Switching to Genesis reflect mode. You will validate ontology mutations.
      Track mutation patterns across generations — catch recurring fallacies.
      Artifact directory: ${ARTIFACT_DIR}/")

3. Evolution loop (max 30 generations):

   FOR each generation n:

     a. Create gen directory: ${ARTIFACT_DIR}/gen-{n}/

     b. Wonder (Metis):
        SendMessage(to: "metis", summary: "Gen {n} wonder",
          "Generation {n}. Read ${ARTIFACT_DIR}/gen-{n}/spec.md and ontology.json.
           Answer 4 fundamental questions: Essence, Root Cause, Preconditions, Hidden Assumptions.
           Report results to leader.")
        WAIT → leader writes gen-{n}/wonder.md

     c. Reflect (Eris):
        SendMessage(to: "eris", summary: "Gen {n} reflect",
          "Generation {n}. Read gen-{n}/wonder.md.
           Compare gen-{n-1}/ontology.json vs gen-{n}/ontology.json.
           Validate logical soundness using fallacy-catalog.md.
           Report results to leader.")
        WAIT → leader writes gen-{n}/reflect.md

     d. Seed: Update ontology + spec from wonder + reflect
        Save gen-{n+1}/ontology.json and gen-{n+1}/spec.md

     e. Convergence check:
        similarity = name_sim * 0.5 + type_sim * 0.3 + exact_sim * 0.2
        olympus_gate_check(pipeline_id, "convergence", similarity)
        → IF similarity >= 0.95: BREAK → proceed to Step 4
        → IF stagnation detected: lateral thinking persona switch

4. Update odyssey-state.json:
   phase: "pantheon"
   gates.convergenceScore: {score}
   artifacts.genesisId: "{genesis-id}"
```

---

## Step 4: Pantheon Phase

Multi-perspective analysis with adversarial challenge.

```
1. MCP: olympus_next_phase(pipeline_id) → confirm "pantheon" is valid

2. Spawn teammates (lazy — skip if already in team):

   IF "helios" not in team:
     Agent(name: "helios", team_name: ${TEAM},
           subagent_type: "olympus:helios", prompt: "...")
     olympus_register_agent_spawn(pipeline_id, "helios")

   IF "ares" not in team:
     Agent(name: "ares", team_name: ${TEAM},
           subagent_type: "olympus:ares", prompt: "...")
     olympus_register_agent_spawn(pipeline_id, "ares")

   IF "poseidon" not in team:
     Agent(name: "poseidon", team_name: ${TEAM},
           subagent_type: "olympus:poseidon", prompt: "...")
     olympus_register_agent_spawn(pipeline_id, "poseidon")

   (hermes, eris already in team from Oracle)
   (zeus may be reused for Architecture perspective)

3. Helios complexity assessment + perspective generation:
   SendMessage(to: "helios", summary: "관점 생성",
     "Read ${ARTIFACT_DIR}/spec.md and codebase-context.md.
      Evaluate 6 complexity dimensions. Derive 3-6 orthogonal perspectives.
      Map analyst agents to perspectives.
      Report results to leader.")
   WAIT → leader writes perspectives.md

4. Perspective approval:
   AskUserQuestion with generated perspectives
   → Confirmed perspectives saved to perspectives.md (immutable)

5. Parallel analysis (SendMessage to each analyst):
   SendMessage(to: "ares", summary: "코드 품질 분석", "...")
   SendMessage(to: "poseidon", summary: "보안 분석", "...")
   SendMessage(to: "zeus", summary: "아키텍처 분석", "...") ← zeus reused from later planning
   WAIT for all → leader aggregates into analyst-findings.md

6. Eris DA challenge:
   SendMessage(to: "eris", summary: "DA 챌린지",
     "Read ${ARTIFACT_DIR}/analyst-findings.md.
      Challenge findings using fallacy-catalog.md. Max 2 rounds.
      Report evaluation to leader.")
   WAIT → leader writes da-evaluation.md

7. Consensus check + synthesis → analysis.md

8. Update odyssey-state.json:
   phase: "planning"
   gates.consensusLevel: {level}
   artifacts.pantheonId: "{pantheon-id}"
```

---

## Step 5: Planning Phase (Zeus + Themis)

Create implementation plan with independent critique.

```
1. MCP: olympus_next_phase(pipeline_id) → confirm "planning" is valid

2. Spawn teammates (lazy):

   IF "zeus" not in team:
     Agent(name: "zeus", team_name: ${TEAM},
           subagent_type: "olympus:zeus", prompt: "...")
     olympus_register_agent_spawn(pipeline_id, "zeus")

   IF "themis" not in team:
     Agent(name: "themis", team_name: ${TEAM},
           subagent_type: "olympus:themis", prompt: "...")
     olympus_register_agent_spawn(pipeline_id, "themis")

3. MCP plan validation:
   olympus_validate_plan(pipeline_id, "odyssey", "execution", "prometheus", estimated_calls)

4. Zeus creates plan:
   SendMessage(to: "zeus", summary: "구현 계획 작성",
     "Read ${ARTIFACT_DIR}/spec.md and analysis.md.
      Query 'hermes' if you need codebase structure clarification.
      Create implementation plan with task breakdown.
      Report plan to leader.")
   WAIT → leader writes plan.md

5. Themis critiques plan:
   SendMessage(to: "themis", summary: "계획 비평",
     "Read ${ARTIFACT_DIR}/plan.md and spec.md.
      Verify completeness, feasibility, and risk coverage.
      Verdict: APPROVE / REVISE / REJECT.
      Report to leader.")
   WAIT → receive verdict

6. Verdict loop (max 3 iterations):
   → APPROVE: proceed to Step 6
   → REVISE: SendMessage(to: "zeus", "Themis 피드백: {feedback}. 계획 수정")
             → re-send to Themis
   → 2 consecutive REVISE: trigger Agora debate
     (ares, zeus, eris structured debate → forward to zeus → Themis re-review)
   → REJECT: AskUserQuestion (Return to Oracle / Pantheon / Exit)

7. Update odyssey-state.json:
   phase: "execution"
   gates.themisVerdict: "APPROVE"
```

---

## Step 6: Execution Phase (Prometheus + Hephaestus + Artemis)

Implement the approved plan. **This is where teammate mode shines.**

```
1. MCP: olympus_next_phase(pipeline_id) → confirm "execution" is valid

2. Spawn teammates (lazy):

   Agent(name: "prometheus", team_name: ${TEAM},
         subagent_type: "olympus:prometheus",
         prompt: "You are Prometheus, a teammate in ${TEAM}.
           You can write files directly.
           You may query teammates directly:
             - 'hermes': codebase structure questions
             - 'artemis': debugging assistance
             - 'hephaestus': quick build checks
           Artifact directory: ${ARTIFACT_DIR}/
           Wait for messages — do not act until prompted.")
   olympus_register_agent_spawn(pipeline_id, "prometheus")

   Agent(name: "artemis", team_name: ${TEAM},
         subagent_type: "olympus:artemis",
         prompt: "You are Artemis, a teammate in ${TEAM}.
           Respond to debugging requests from 'prometheus' or leader.
           Artifact directory: ${ARTIFACT_DIR}/
           Wait for messages — do not act until prompted.")
   olympus_register_agent_spawn(pipeline_id, "artemis")

   Agent(name: "hephaestus", team_name: ${TEAM},
         subagent_type: "olympus:hephaestus",
         prompt: "You are Hephaestus, a teammate in ${TEAM}.
           Run build/lint/test/type-check when requested.
           Report results to requester (prometheus or leader).
           Wait for messages — do not act until prompted.")
   olympus_register_agent_spawn(pipeline_id, "hephaestus")

3. Implementation:
   SendMessage(to: "prometheus", summary: "구현 시작",
     "Read ${ARTIFACT_DIR}/plan.md and implement all tasks.
      You may query 'hermes' for codebase structure questions.
      You may ask 'artemis' for help with debugging.
      Report completion to leader with implementation report.")

   WAIT for prometheus completion
   olympus_record_execution(pipeline_id, "execution", "prometheus", ...)

4. Build verification:
   SendMessage(to: "hephaestus", summary: "빌드/테스트 실행",
     "Run full build, lint, test, and type-check.
      Report results to leader.")
   WAIT for hephaestus result

5. Debug cycle (if build fails, max 3 cycles):

   IF hephaestus reports FAIL:
     retryTracking.consecutiveDebugFailures++

     SendMessage(to: "prometheus", summary: "테스트 실패 수정",
       "Build/test failed. Check hephaestus results and fix.
        You may ask 'artemis' for root cause analysis.
        You REMEMBER your previous implementation — fix precisely.")
     ← Prometheus retains full context of what it built!
     ← Prometheus can directly ask artemis: "이 에러 원인 추적해줘"
     ← Artemis can directly respond to prometheus

     WAIT for prometheus → re-send to hephaestus

     IF consecutiveDebugFailures >= 3:
       → Circuit breaker: proceed to Step 7 with current state
       → Tribunal will classify as BLOCKED or REJECTED_IMPLEMENTATION

6. Update odyssey-state.json:
   phase: "tribunal"
   gates.mechanicalPass: true (or false if circuit breaker)
```

---

## Step 7: Tribunal Phase

Three-stage evaluation with adversarial consensus.

```
1. MCP: olympus_next_phase(pipeline_id) → confirm "tribunal" is valid

2. Spawn teammates (lazy):

   IF "athena" not in team:
     Agent(name: "athena", team_name: ${TEAM},
           subagent_type: "olympus:athena", prompt: "...")
     olympus_register_agent_spawn(pipeline_id, "athena")

   IF "hera" not in team:
     Agent(name: "hera", team_name: ${TEAM},
           subagent_type: "olympus:hera", prompt: "...")
     olympus_register_agent_spawn(pipeline_id, "hera")

   (ares, eris, hephaestus already in team)

3. Stage 1 — Hephaestus mechanical verification:
   SendMessage(to: "hephaestus", summary: "기계적 검증",
     "Run build, lint, test, type-check. Save to mechanical-result.json.
      Report to leader.")
   WAIT → leader writes mechanical-result.json
   → FAIL: BLOCKED verdict → exit
   → PASS: Stage 2

4. Stage 2 — Athena semantic evaluation:
   SendMessage(to: "athena", summary: "의미적 평가",
     "Read ${ARTIFACT_DIR}/spec.md and mechanical-result.json.
      Evaluate AC compliance with file:line evidence.
      Report semantic-matrix.md to leader.")
   WAIT → leader writes semantic-matrix.md
   → AC compliance < 100% OR score < 0.8: INCOMPLETE → exit
   → PASS: check Stage 3 trigger

5. Stage 3 — Consensus debate (if triggered):
   Trigger conditions: spec modified, score < 0.8, scope deviation, user request

   Sequential debate (each sees previous):

   a. SendMessage(to: "ares", summary: "토론 제안",
        "Read semantic-matrix.md. Argue for APPROVE or REJECT from quality perspective.
         Include file:line evidence.")
      WAIT → receive ares position

   b. SendMessage(to: "eris", summary: "반박",
        "Ares argues: {ares_summary}. Counter-argue with evidence.
         Challenge logical fallacies per fallacy-catalog.md.")
      WAIT → receive eris counter-argument

   c. SendMessage(to: "hera", summary: "종합 판정",
        "Ares: {ares_summary}. Eris: {eris_summary}.
         Synthesize both. Run tests for evidence. Produce final verdict.")
      WAIT → receive hera synthesis

   Tally votes: supermajority >= 66%
   Save consensus-record.json

6. Final verdict processing:
   → APPROVED: Hera final verification → Step 8
   → BLOCKED: return to Step 6 (debug)
   → INCOMPLETE: return to Step 6 (implement unmet ACs)
   → REJECTED_IMPLEMENTATION: evaluationPass++ → return to Step 6
     IF evaluationPass >= 3: Genesis rewind (AskUserQuestion)
   → REJECTED_SPEC: return to Step 2 (new Oracle artifact directory)
   → REJECTED_ARCHITECTURE: return to Step 4 (new Pantheon artifact directory)

7. Update odyssey-state.json:
   artifacts.tribunalId: "{tribunal-id}"
```

---

## Step 8: Team Teardown

```
1. Send shutdown to all active teammates:
   FOR each active teammate:
     SendMessage(to: "{name}", message: { type: "shutdown_request", reason: "Pipeline complete" })
     WAIT for shutdown_response

2. TeamDelete(team_name: ${TEAM})

3. Generate final report:
   - Phases executed
   - Gate results per phase
   - Total teammate spawns and reuses
   - Final artifact locations

4. Update odyssey-state.json:
   phase: "completed"
   transition: { status: "terminal", reason: "completed" }
```

</Steps>

<Tool_Usage>
  MCP Tools (loaded via ToolSearch at Step 0):
  - olympus_start_pipeline: Step 1 (MUST call)
  - olympus_next_phase: each phase transition (MUST call)
  - olympus_register_agent_spawn: after each teammate spawn (MUST call)
  - olympus_gate_check: at each gate (MUST call)
  - olympus_record_execution: after each agent task completes (SHOULD call)
  - olympus_validate_plan: Step 5 before planning (SHOULD call)

  Team Tools:
  - TeamCreate: Step 1 (create team once)
  - Agent (with name + team_name): spawn teammates (lazy, on first need)
  - SendMessage: all inter-agent communication
  - TeamDelete: Step 8 (teardown)

  Other Tools:
  - AskUserQuestion: user decisions, escalation
  - Read/Write/Edit: artifact management (leader only for read-only agent artifacts)
</Tool_Usage>

<Artifact_Contracts>
  | File | Phase | Writer | Readers |
  |------|-------|--------|---------|
  | odyssey-state.json | All | Leader | All |
  | codebase-context.md | Oracle | Leader (from hermes) | apollo, metis, zeus, prometheus |
  | interview-log.md | Oracle | Leader (from apollo) | metis |
  | ambiguity-scores.json | Oracle | Leader (from apollo) | Gate check |
  | gap-analysis.md | Oracle | Leader (from metis) | zeus, helios |
  | spec.md | Oracle | Leader | All downstream |
  | gen-{n}/*.md | Genesis | Leader | metis, eris |
  | perspectives.md | Pantheon | Leader (from helios) | analysts |
  | analyst-findings.md | Pantheon | Leader (from analysts) | eris |
  | da-evaluation.md | Pantheon | Leader (from eris) | consensus |
  | analysis.md | Pantheon | Leader | zeus |
  | plan.md | Planning | zeus (direct write) | prometheus, themis |
  | implementation-report.md | Execution | prometheus (direct write) | hephaestus, tribunal |
  | mechanical-result.json | Tribunal | hephaestus (direct write) | athena |
  | semantic-matrix.md | Tribunal | Leader (from athena) | ares, eris, hera |
  | consensus-record.json | Tribunal | Leader | verdict |
  | verdict.md | Tribunal | Leader | user |
</Artifact_Contracts>

<Gate_Thresholds>
  All values from gate-thresholds.json (single source of truth):
  - Ambiguity: ≤ 0.2 (Oracle)
  - Convergence: ≥ 0.95 (Genesis)
  - Consensus: ≥ 67% (Pantheon, Tribunal)
  - Semantic: ≥ 0.8 (Tribunal)
  - Mechanical: PASS (Tribunal)
  - Themis: APPROVE (Planning)
</Gate_Thresholds>

<Protocol_References>
  - orchestrator-protocol.md — §0 mandatory spawn rule, §6 full teammate mode
  - pipeline-states.json — state machine schema
  - gate-thresholds.json — gate values
  - context-management.md — compaction per phase transition
  - agent-context.md — worker isolation rules
</Protocol_References>
