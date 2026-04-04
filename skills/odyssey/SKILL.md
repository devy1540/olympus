---
name: odyssey
description: "The Grand Journey — Oracle→Genesis→Pantheon→Plan→Execute→Tribunal full pipeline"
---

<Purpose>
Execute the complete Olympus pipeline from requirements to verified implementation.
All agents operate as teammates in a single persistent team for cross-phase context retention.
</Purpose>

<Execution_Policy>
- FULL TEAMMATE mode. ALL agents are teammates in one team.
- Each Step MUST call the specified MCP tool. Do NOT skip MCP calls.
- Do NOT perform agent work directly. Spawn teammates and delegate. (§0 — no exceptions.)
- Teammates persist across phases — reuse existing teammates via SendMessage instead of re-spawning.
- Leader handles ONLY: team management, phase transitions, gate checks, MCP state, artifact writing for read-only agents.
- If MCP tools are unavailable, proceed without MCP — hooks provide fallback.
- IMPORTANT: Do NOT skip ToolSearch at Step 0.

- PROACTIVE SPAWN RULE (§6.3): Every Agent() call MUST include the agent's IMMEDIATE TASK
  in the prompt. NEVER use "Wait for messages — do not act until prompted."
  The agent starts working the moment it spawns. SendMessage is ONLY for follow-up tasks.

- MANDATORY CONSULTATION (§7): Agents with peer consultation paths MUST exchange at least
  one round of inter-agent messages BEFORE reporting final results to the leader.
  Reports lacking consultation evidence are incomplete — send agent back to consult.

- SEQUENTIAL SPAWN: Within each phase, spawn agents in dependency order, not all at once.
  Wait for prerequisite agent results before spawning dependent agents.

- RESPONSE RULE: If a teammate does not report within reasonable time:
  1. SendMessage(to: "{agent}", "Report your findings now. Include consultation results. Keep under 5000 chars.")
  2. Retry up to 3 times.
  3. NEVER do the agent's work directly — this violates §0.
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
  - apollo ↔ hermes (codebase context during interview) — MANDATORY per interview round
  - metis ↔ eris (Genesis wonder/reflect loop) — MANDATORY dialogue
  - ares ↔ poseidon (quality ↔ security cross-reference) — MANDATORY in Pantheon
  - ares ↔ eris (Tribunal debate) — MANDATORY in Stage 3
  - athena ↔ hephaestus (evidence verification) — On-demand
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
Agents are spawned SEQUENTIALLY with IMMEDIATE TASKS — not all at once.

```
1. MCP: olympus_next_phase(pipeline_id) → confirm "oracle" is valid

2. SPAWN hermes with IMMEDIATE TASK (sequential — first agent):

   Agent(name: "hermes", team_name: ${TEAM},
         subagent_type: "olympus:hermes",
         run_in_background: true,
         prompt: "You are Hermes in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           IMMEDIATE TASK: Explore codebase related to: {user_input}.
           DO NOT write files — you are read-only.
           Gather: project structure, relevant modules, existing patterns, dependencies.
           When done: SendMessage(to: 'leader', summary: '코드베이스 탐색 완료', '{결과}')
           Then STAY AVAILABLE: respond to queries from apollo, metis, prometheus via SendMessage.")
   olympus_register_agent_spawn(pipeline_id, "hermes")

   WAIT for hermes SendMessage → leader writes codebase-context.md
   olympus_record_execution(pipeline_id, "oracle", "hermes", ...)

3. SPAWN apollo with IMMEDIATE TASK (after hermes completes):

   Agent(name: "apollo", team_name: ${TEAM},
         subagent_type: "olympus:apollo",
         run_in_background: true,
         prompt: "You are Apollo in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           IMMEDIATE TASK: Conduct Socratic interview about: {user_input}. Complexity: {level}.
           DO NOT write files — you are read-only.
           Read ${ARTIFACT_DIR}/codebase-context.md for project context.
           MANDATORY CONSULTATION: Before each question, query 'hermes' to verify codebase facts:
             SendMessage(to: 'hermes', summary: '팩트 확인', '{question about codebase}')
             Wait for hermes response, then ask user with verified context.
           Interview rules: One question at a time via AskUserQuestion.
           Track ambiguity scores internally. Terminate when ambiguity ≤ 0.2 or max 10 rounds.
           When done: SendMessage(to: 'leader', summary: '인터뷰 완료 — 모호성: {score}',
             '{interview log + ambiguity scores + consultation log with hermes}')
           Then STAY AVAILABLE for follow-up rounds.")
   olympus_register_agent_spawn(pipeline_id, "apollo")

   WAIT for apollo SendMessage → leader writes interview-log.md + ambiguity-scores.json
   olympus_record_execution(pipeline_id, "oracle", "apollo", ...)

4. Ambiguity gate:
   ambiguityScore = read ${ARTIFACT_DIR}/ambiguity-scores.json
   olympus_gate_check(pipeline_id, "ambiguity", ambiguityScore)
   → IF passed: proceed to step 5
   → IF failed AND rounds < 10:
       SendMessage(to: "apollo", summary: "추가 인터뷰",
         "Ambiguity still at {score}. Focus on: {gap areas}.
          Continue consulting 'hermes' for fact verification.")
   → IF failed AND rounds >= 10: AskUserQuestion with remaining gaps

5. SPAWN metis with IMMEDIATE TASK (after apollo completes):

   Agent(name: "metis", team_name: ${TEAM},
         subagent_type: "olympus:metis",
         run_in_background: true,
         prompt: "You are Metis in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           IMMEDIATE TASK: Perform gap analysis on interview results.
           DO NOT write files — you are read-only.
           Read ${ARTIFACT_DIR}/interview-log.md and ${ARTIFACT_DIR}/codebase-context.md.
           Analyze: Missing Questions, Undefined Guardrails, Scope Risks,
           Unvalidated Assumptions, Acceptance Criteria, Edge Cases.
           CONSULTATION: Query 'hermes' to verify any codebase assumptions:
             SendMessage(to: 'hermes', summary: '가정 검증', '{assumption to verify}')
           When done: SendMessage(to: 'leader', summary: '갭 분석 완료',
             '{gap analysis results + hermes consultation log}')
           Then STAY AVAILABLE for Genesis wonder phase.")
   olympus_register_agent_spawn(pipeline_id, "metis")

   WAIT for metis SendMessage → leader writes gap-analysis.md
   olympus_record_execution(pipeline_id, "oracle", "metis", ...)

6. Synthesize spec.md from interview-log.md + gap-analysis.md
   Write ${ARTIFACT_DIR}/spec.md

7. Update odyssey-state.json:
   phase: "genesis" (or "pantheon" if genesis disabled)
   gates.ambiguityScore: {score}
   artifacts.specId: "{oracle-id}"
```

---

## Step 3: Genesis Phase (optional)

Evolve spec through generational refinement using Metis↔Eris DIALOGUE.

```
Activation conditions (any):
  - User provides --evolve flag
  - Auto-detect: spec ONTOLOGY items > 10
  - Auto-detect: OPEN_QUESTIONS > 3

When disabled: skip to Step 4.

When enabled:

1. MCP: olympus_next_phase(pipeline_id) → confirm "genesis" is valid

2. Spawn eris (metis already in team from Oracle):

   Agent(name: "eris", team_name: ${TEAM},
         subagent_type: "olympus:eris",
         run_in_background: true,
         prompt: "You are Eris in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           IMMEDIATE TASK: Enter Genesis reflect mode.
           DO NOT write files — you are read-only.
           You will receive wonder results from 'metis' via SendMessage.
           For EACH generation: read metis's wonder, challenge it with fallacy-catalog.md,
           then SendMessage(to: 'metis', summary: '반박: Gen {n}', '{challenges}')
           so metis can incorporate your feedback in the next generation.
           Also report each reflect to leader.
           STAY AVAILABLE across all generations.")
   olympus_register_agent_spawn(pipeline_id, "eris")

   SendMessage(to: "metis", summary: "Genesis 모드 전환",
     "Switching to Genesis wonder mode. Build on Oracle insights.
      MANDATORY DIALOGUE: After each wonder, share with 'eris' via SendMessage.
      Wait for eris's challenges, then incorporate into next generation.
      Artifact directory: ${ARTIFACT_DIR}/")

3. Evolution loop (max 30 generations):

   FOR each generation n:

     a. Create gen directory: ${ARTIFACT_DIR}/gen-{n}/

     b. Wonder + Dialogue (Metis ↔ Eris):
        SendMessage(to: "metis", summary: "Gen {n} wonder",
          "Generation {n}. Read ${ARTIFACT_DIR}/gen-{n}/spec.md and ontology.json.
           Answer 4 questions: Essence, Root Cause, Preconditions, Hidden Assumptions.
           THEN share your wonder with 'eris': SendMessage(to: 'eris', summary: 'Wonder Gen {n}', '{findings}')
           Wait for eris's challenges.
           Report to leader: wonder + eris challenges + your response to challenges.")
        WAIT → leader writes gen-{n}/wonder.md (includes metis↔eris dialogue)

        Note: The dialogue happens BETWEEN metis and eris directly.
        Metis sends wonder to eris, eris challenges back, metis responds.
        Leader receives the FINAL consolidated result.
        olympus_log_collaboration(pipeline_id, "metis", "eris", "Gen {n} wonder/reflect dialogue")

     c. Seed: Update ontology + spec from wonder + reflect dialogue
        Save gen-{n+1}/ontology.json and gen-{n+1}/spec.md

     d. Convergence check:
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

Multi-perspective analysis with MANDATORY cross-reference between analysts.

```
1. MCP: olympus_next_phase(pipeline_id) → confirm "pantheon" is valid

2. SPAWN helios with IMMEDIATE TASK (first — generates perspectives):

   Agent(name: "helios", team_name: ${TEAM},
         subagent_type: "olympus:helios",
         run_in_background: true,
         prompt: "You are Helios in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           IMMEDIATE TASK: Generate analysis perspectives.
           DO NOT write files — you are read-only.
           Read ${ARTIFACT_DIR}/spec.md and codebase-context.md.
           Evaluate 6 complexity dimensions. Derive 3-6 orthogonal perspectives.
           Map analyst agents to perspectives.
           When done: SendMessage(to: 'leader', summary: '관점 생성 완료', '{perspectives}')
           Then STAY AVAILABLE.")
   olympus_register_agent_spawn(pipeline_id, "helios")
   WAIT → leader writes perspectives.md

3. Perspective approval:
   AskUserQuestion with generated perspectives
   → Confirmed perspectives saved to perspectives.md (immutable)

4. SPAWN ares + poseidon IN PARALLEL with IMMEDIATE TASKS + CROSS-REFERENCE:

   Agent(name: "ares", team_name: ${TEAM},
         subagent_type: "olympus:ares",
         run_in_background: true,
         prompt: "You are Ares in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           IMMEDIATE TASK: Analyze from Code Quality perspective.
           DO NOT write files — you are read-only.
           Read ${ARTIFACT_DIR}/spec.md, codebase-context.md, perspectives.md.
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

   Agent(name: "poseidon", team_name: ${TEAM},
         subagent_type: "olympus:poseidon",
         run_in_background: true,
         prompt: "You are Poseidon in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           IMMEDIATE TASK: Analyze from Security perspective.
           DO NOT write files — you are read-only.
           Read ${ARTIFACT_DIR}/spec.md, codebase-context.md, perspectives.md.
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

   Note: ares and poseidon run IN PARALLEL. Both do initial analysis, then CROSS-REFERENCE.
   The cross-reference exchange happens directly between them — leader only receives final results.
   olympus_log_collaboration(pipeline_id, "ares", "poseidon", "코드품질↔보안 크로스레퍼런스")

   WAIT for both → leader aggregates into analyst-findings.md

5. Eris DA challenge (reuse from Oracle/Genesis):
   SendMessage(to: "eris", summary: "DA 챌린지",
     "Read ${ARTIFACT_DIR}/analyst-findings.md.
      Challenge findings using fallacy-catalog.md. Max 2 rounds.
      Focus on: logical gaps, unsupported claims, overlooked risks.
      Report evaluation to leader with specific rebuttals.")
   WAIT → leader writes da-evaluation.md

6. Consensus check + synthesis → analysis.md

7. Update odyssey-state.json:
   phase: "planning"
   gates.consensusLevel: {level}
   artifacts.pantheonId: "{pantheon-id}"
```

---

## Step 5: Planning Phase (Zeus + Themis)

Create implementation plan with independent critique. Zeus consults hermes; Themis critiques independently.

```
1. MCP: olympus_next_phase(pipeline_id) → confirm "planning" is valid

2. MCP plan validation:
   olympus_validate_plan(pipeline_id, "odyssey", "execution", "prometheus", estimated_calls)

3. SPAWN zeus with IMMEDIATE TASK:

   Agent(name: "zeus", team_name: ${TEAM},
         subagent_type: "olympus:zeus",
         run_in_background: true,
         prompt: "You are Zeus in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           IMMEDIATE TASK: Create implementation plan.
           Read ${ARTIFACT_DIR}/spec.md and analysis.md.
           CONSULTATION: Query 'hermes' for codebase structure clarifications:
             SendMessage(to: 'hermes', summary: '구조 확인', '{question}')
           Create task breakdown with Critical Files for Implementation.
           When done: SendMessage(to: 'leader', summary: '계획 수립 완료',
             '{plan + hermes consultation log}')
           Then STAY AVAILABLE for revision feedback from Themis.")
   olympus_register_agent_spawn(pipeline_id, "zeus")
   WAIT → leader writes plan.md

4. SPAWN themis with IMMEDIATE TASK (after plan.md exists):

   Agent(name: "themis", team_name: ${TEAM},
         subagent_type: "olympus:themis",
         run_in_background: true,
         prompt: "You are Themis in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           IMMEDIATE TASK: Critique implementation plan.
           DO NOT write files — you are read-only.
           Read ${ARTIFACT_DIR}/plan.md and spec.md.
           Verify completeness, feasibility, risk coverage.
           IMPORTANT: You are INDEPENDENT — do not consult zeus about the plan you're critiquing.
           Verdict: APPROVE / REVISE / REJECT with specific reasons and evidence.
           When done: SendMessage(to: 'leader', summary: '계획 비평 완료 — {verdict}', '{critique}')
           Then STAY AVAILABLE for re-review.")
   olympus_register_agent_spawn(pipeline_id, "themis")
   WAIT → receive verdict

5. Verdict loop (max 3 iterations):
   → APPROVE: proceed to Step 6
   → REVISE: SendMessage(to: "zeus", summary: "Themis 피드백 반영",
       "Themis critique: {specific feedback}. Revise plan.
        You REMEMBER the original plan — fix precisely.
        Query 'hermes' again if needed for verification.")
     WAIT for zeus → leader updates plan.md
     SendMessage(to: "themis", summary: "수정된 계획 재검토",
       "plan.md has been revised. Re-read and re-evaluate.")
     WAIT for themis → re-check verdict
   → 2 consecutive REVISE: trigger Agora debate
     (ares, zeus, eris structured debate → forward to zeus → Themis re-review)
   → REJECT: AskUserQuestion (Return to Oracle / Pantheon / Exit)

6. Update odyssey-state.json:
   phase: "execution"
   gates.themisVerdict: "APPROVE"
```

---

## Step 6: Execution Phase (Prometheus + Hephaestus + Artemis)

Implement the approved plan. **Teammate mode shines here — agents collaborate in real-time.**

```
1. MCP: olympus_next_phase(pipeline_id) → confirm "execution" is valid

2. SPAWN artemis + hephaestus first (support agents, ready for queries):

   Agent(name: "artemis", team_name: ${TEAM},
         subagent_type: "olympus:artemis",
         run_in_background: true,
         prompt: "You are Artemis in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           ROLE: Debugging support agent. Respond to requests from 'prometheus' or leader.
           When 'prometheus' sends you an error/issue:
             1. Analyze root cause with file:line evidence
             2. SendMessage(to: 'prometheus', summary: '근본 원인: {cause}', '{analysis + fix direction}')
           When leader sends you a task: investigate and report back.
           STAY AVAILABLE throughout Execution phase.")
   olympus_register_agent_spawn(pipeline_id, "artemis")

   Agent(name: "hephaestus", team_name: ${TEAM},
         subagent_type: "olympus:hephaestus",
         run_in_background: true,
         prompt: "You are Hephaestus in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           ROLE: Build/test verification agent. Run build/lint/test/type-check on request.
           When 'prometheus' or leader sends you a verification request:
             1. Run the requested checks
             2. Report results to the REQUESTER (not just leader)
           STAY AVAILABLE throughout Execution and Tribunal phases.")
   olympus_register_agent_spawn(pipeline_id, "hephaestus")

3. SPAWN prometheus with IMMEDIATE TASK (main implementer):

   Agent(name: "prometheus", team_name: ${TEAM},
         subagent_type: "olympus:prometheus",
         run_in_background: true,
         prompt: "You are Prometheus in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           IMMEDIATE TASK: Implement ${ARTIFACT_DIR}/plan.md.
           You CAN write files directly.
           ACTIVE COLLABORATION — use your teammates:
             - 'hermes': SendMessage for codebase structure questions
             - 'artemis': SendMessage for debugging when you hit errors
             - 'hephaestus': SendMessage for quick build verification during implementation
           Do NOT work in isolation. Query teammates when uncertain.
           When done: SendMessage(to: 'leader', summary: '구현 완료',
             '{implementation report + teammate consultation log}')
           Then STAY AVAILABLE for debug cycles.")
   olympus_register_agent_spawn(pipeline_id, "prometheus")

   WAIT for prometheus completion
   olympus_record_execution(pipeline_id, "execution", "prometheus", ...)

4. Build verification:
   SendMessage(to: "hephaestus", summary: "전체 빌드/테스트 실행",
     "Run full build, lint, test, and type-check.
      Report results to leader AND to 'prometheus'.")
   WAIT for hephaestus result

5. Debug cycle (if build fails, max 3 cycles):

   IF hephaestus reports FAIL:
     retryTracking.consecutiveDebugFailures++

     SendMessage(to: "prometheus", summary: "테스트 실패 수정",
       "Build/test failed. Hephaestus results: {summary}.
        COLLABORATE: Ask 'artemis' for root cause analysis.
        SendMessage(to: 'artemis', summary: '에러 분석 요청', '{error details}')
        Wait for artemis's diagnosis, then fix.
        You REMEMBER your previous implementation — fix precisely.
        After fix, ask 'hephaestus' for quick verification before reporting.")
     ← Prometheus retains full context of what it built!
     ← Real-time prometheus → artemis → prometheus dialogue
     ← prometheus → hephaestus quick check before reporting

     WAIT for prometheus → leader sends to hephaestus for full verification

     IF consecutiveDebugFailures >= 3:
       → Circuit breaker: proceed to Step 7 with current state
       → Tribunal will classify as BLOCKED or REJECTED_IMPLEMENTATION

6. Update odyssey-state.json:
   phase: "tribunal"
   gates.mechanicalPass: true (or false if circuit breaker)
```

---

## Step 7: Tribunal Phase

Three-stage evaluation with GENUINE adversarial debate (agents respond to each other's arguments).

```
1. MCP: olympus_next_phase(pipeline_id) → confirm "tribunal" is valid

2. SPAWN athena + hera (hephaestus, ares, eris already in team):

   Agent(name: "athena", team_name: ${TEAM},
         subagent_type: "olympus:athena",
         run_in_background: true,
         prompt: "You are Athena in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           ROLE: Semantic evaluator for Tribunal.
           DO NOT write files — you are read-only.
           You will be asked to evaluate AC compliance.
           You may query 'hephaestus' for test evidence:
             SendMessage(to: 'hephaestus', summary: '증거 확인', '{what to verify}')
           STAY AVAILABLE for evaluation tasks.")
   olympus_register_agent_spawn(pipeline_id, "athena")

   Agent(name: "hera", team_name: ${TEAM},
         subagent_type: "olympus:hera",
         run_in_background: true,
         prompt: "You are Hera in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           ROLE: Final judge for Tribunal Stage 3.
           You will receive debate transcripts from ares and eris.
           You may query 'hephaestus' for test evidence to settle disputes.
           STAY AVAILABLE for verdict task.")
   olympus_register_agent_spawn(pipeline_id, "hera")

3. Stage 1 — Hephaestus mechanical verification (reuse):
   SendMessage(to: "hephaestus", summary: "기계적 검증",
     "Run build, lint, test, type-check.
      Report to leader AND save mechanical-result.json.")
   WAIT → leader writes mechanical-result.json
   → FAIL: BLOCKED verdict → exit
   → PASS: Stage 2

4. Stage 2 — Athena semantic evaluation:
   SendMessage(to: "athena", summary: "의미적 평가",
     "Read ${ARTIFACT_DIR}/spec.md and mechanical-result.json.
      Evaluate each AC with file:line evidence.
      CONSULTATION: For any AC where evidence is ambiguous,
        query 'hephaestus': SendMessage(to: 'hephaestus', summary: 'AC 증거 확인', '{specific test}')
      Report semantic-matrix.md to leader with consultation log.")
   WAIT → leader writes semantic-matrix.md
   → AC compliance < 100% OR score < 0.8: INCOMPLETE → exit
   → PASS: check Stage 3 trigger

5. Stage 3 — Genuine adversarial debate (if triggered):
   Trigger: spec modified, score < 0.8, scope deviation, user request

   THIS IS A REAL DEBATE — each agent RESPONDS to the previous arguments.

   a. Ares opens (reuse):
      SendMessage(to: "ares", summary: "토론 개시",
        "Read semantic-matrix.md. Argue for APPROVE or REJECT from quality perspective.
         Include file:line evidence for every claim.
         This will be shared with Eris for counter-argument.")
      WAIT → receive ares_position
      olympus_log_collaboration(pipeline_id, "ares", "eris", "Tribunal debate: ares opening")

   b. Eris challenges (reuse) — SEES ares's full argument:
      SendMessage(to: "eris", summary: "반박",
        "ARES ARGUES: {ares_full_position}.
         Your job: find logical fallacies, unsupported claims, overlooked evidence.
         Use fallacy-catalog.md. Include file:line counter-evidence.
         IMPORTANT: Respond SPECIFICALLY to ares's points — do not make independent arguments.
         This is a dialogue, not parallel monologues.")
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
         You may query 'hephaestus' for test evidence to settle factual disputes.
         Produce final verdict: APPROVE / REJECT with reasoned synthesis.")
      WAIT → receive hera_verdict

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
