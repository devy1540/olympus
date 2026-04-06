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
  The agent starts working the moment it spawns. SendMessage is ONLY for inter-agent communication.

- RESULT CAPTURE RULE: Read-only agents deliver results via SendMessage(to: "team-lead").
  Orchestrator writes artifacts from these results. Write-capable agents write files directly.

- MANDATORY CONSULTATION (§7): Agents with peer consultation paths MUST exchange at least
  one round of inter-agent messages BEFORE reporting final results.
  Reports lacking consultation evidence are incomplete — send agent back to consult.

- RESPONSE RULE: If a teammate does not report within reasonable time:
  1. SendMessage(to: "{agent}", "Report your findings now. Include consultation results. Keep under 5000 chars.")
  2. Retry up to 3 times.
  3. NEVER do the agent's work directly — this violates §0.

- SEQUENTIAL SPAWN: Within each phase, spawn agents in dependency order, not all at once.
  Wait for prerequisite agent results before spawning dependent agents.
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
  - metis ↔ eris (Genesis wonder/reflect loop) — MANDATORY consultation
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

2. SPAWN hermes with IMMEDIATE TASK (sequential — first agent, FOREGROUND):

   hermes_result = Agent(name: "hermes", team_name: ${TEAM},
         subagent_type: "olympus:hermes",
         prompt: "You are Hermes in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           LEADER_NAME: team-lead
           IMMEDIATE TASK: Explore codebase related to: {user_input}.
           DO NOT write files — you are read-only.
           Gather: project structure, relevant modules, existing patterns, dependencies.
           When done: SendMessage(to: 'team-lead', summary: 'hermes 탐색 완료', '{codebase context}')")
   olympus_register_agent_spawn(pipeline_id, "hermes")

   → Write codebase-context.md from hermes SendMessage
   olympus_record_execution(pipeline_id, "oracle", "hermes", ...)

3. SPAWN apollo with IMMEDIATE TASK (BACKGROUND — uses SendMessage for interview proxy):

   Agent(name: "apollo", team_name: ${TEAM},
         subagent_type: "olympus:apollo",
         run_in_background: true,
         prompt: "You are Apollo in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           LEADER_NAME: team-lead
           IMMEDIATE TASK: Conduct Socratic interview about: {user_input}. Complexity: {level}.
           DO NOT write files — you are read-only.
           Read ${ARTIFACT_DIR}/codebase-context.md for project context.
           IMPORTANT: You CANNOT use AskUserQuestion directly.
           Instead, send each question to the leader:
             SendMessage(to: 'team-lead', summary: '인터뷰 질문 {n}', '{질문 + 컨텍스트 + 선택지}')
           The leader will proxy the question to the user and relay the answer back to you.
           Wait for the leader's response before generating the next question.
           Track ambiguity scores internally. Terminate when ambiguity ≤ 0.2 or max 10 rounds.
           When done: SendMessage(to: 'team-lead', summary: '인터뷰 완료', '{interview log + scores}')")
   olympus_register_agent_spawn(pipeline_id, "apollo")

   INTERVIEW PROXY LOOP (leader):
     FOR each message from apollo:
       IF apollo sends a question → AskUserQuestion({apollo's question})
       → SendMessage(to: "apollo", "User answered: {answer}")
       IF apollo sends completion → Write interview-log.md + ambiguity-scores.json

   DEADLOCK FALLBACK: If 5 minutes elapse without apollo sending a question or completion:
     → SendMessage(to: "apollo", "Interview timeout. Submit your current findings and scores now.")
     → Retry up to 2 times (2-minute intervals)
     → If still no response: proceed with available information, note "apollo consultation incomplete" in interview-log.md
   olympus_record_execution(pipeline_id, "oracle", "apollo", ...)

4. Ambiguity gate:
   ambiguityScore = read ${ARTIFACT_DIR}/ambiguity-scores.json
   olympus_gate_check(pipeline_id, "ambiguity", ambiguityScore)
   → IF passed: proceed to step 5
   → IF failed AND rounds < 10:
       Re-spawn apollo (BACKGROUND — dialog agent, same pattern as initial spawn):
       Agent(name: "apollo", team_name: ${TEAM},
           subagent_type: "olympus:apollo",
           run_in_background: true,
           prompt: "You are Apollo in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
             LEADER_NAME: team-lead
             IMMEDIATE TASK: Continue Socratic interview — reduce ambiguity from {score} by focusing on: {gap areas}.
             Read ${ARTIFACT_DIR}/interview-log.md for context from previous rounds.
             Ambiguity still at {score}. Continue interview, focus on: {gap areas}.
             IMPORTANT: Use SendMessage(to: 'team-lead') for each question (interview proxy pattern).
             When done: SendMessage(to: 'team-lead', summary: '인터뷰 완료', '{updated log + scores}')")
       olympus_register_agent_spawn(pipeline_id, "apollo")
       olympus_record_execution(pipeline_id, "oracle", "apollo-retry", ...)
       Continue INTERVIEW PROXY LOOP (same as Step 2, item 3)
       → Update interview-log.md + ambiguity-scores.json from retry completion
   → IF failed AND rounds >= 10:
       next = olympus_next_action(pipeline_id)
       # next.action: advance_phase (user override) or retry_phase
       AskUserQuestion with remaining gaps

5. SPAWN metis with IMMEDIATE TASK (after apollo completes, FOREGROUND):

   metis_result = Agent(name: "metis", team_name: ${TEAM},
         subagent_type: "olympus:metis",
         prompt: "You are Metis in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           LEADER_NAME: team-lead
           IMMEDIATE TASK: Perform gap analysis on interview results.
           DO NOT write files — you are read-only.
           Read ${ARTIFACT_DIR}/interview-log.md and ${ARTIFACT_DIR}/codebase-context.md.
           Analyze: Missing Questions, Undefined Guardrails, Scope Risks,
           Unvalidated Assumptions, Acceptance Criteria, Edge Cases.
           When done: SendMessage(to: 'team-lead', summary: 'metis 갭분석 완료', '{gap analysis}')")
   olympus_register_agent_spawn(pipeline_id, "metis")

   → Write gap-analysis.md from metis SendMessage
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

2. For EACH generation, spawn metis and eris as a pair (FOREGROUND per generation):

   FOR each generation n:

     a. Create gen directory: ${ARTIFACT_DIR}/gen-{n}/

     b. Spawn metis for wonder (FOREGROUND):
        metis_wonder = Agent(name: "metis-gen{n}", team_name: ${TEAM},
              subagent_type: "olympus:metis",
              prompt: "You are Metis in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           LEADER_NAME: team-lead
                IMMEDIATE TASK: Genesis wonder for generation {n}.
                Read ${ARTIFACT_DIR}/gen-{n}/spec.md and ontology.json.
                {If n > 1: Read gen-{n-1}/reflect.md for prior generation reflection context.}
                Answer 4 questions: Essence, Root Cause, Preconditions, Hidden Assumptions.
                SEQUENTIAL CONTEXT: Eris is spawned AFTER you complete — skip peer SendMessage to eris.
                Deliver wonder directly to team-lead.
                When done: SendMessage(to: 'team-lead', summary: 'metis wonder gen-{n} 완료', '{wonder analysis}')")
        olympus_register_agent_spawn(pipeline_id, "metis")
        olympus_record_execution(pipeline_id, "genesis", "metis", ...)

     c. Spawn eris for reflect (FOREGROUND, receives metis wonder):
        eris_reflect = Agent(name: "eris-gen{n}", team_name: ${TEAM},
              subagent_type: "olympus:eris",
              prompt: "You are Eris in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           LEADER_NAME: team-lead
                IMMEDIATE TASK: Read docs/shared/fallacy-catalog.md. Challenge this wonder analysis:
                {If n > 1: Read gen-{n-1}/wonder.md to track question evolution across generations.}
                === METIS WONDER ===
                {metis_wonder}
                SEQUENTIAL CONTEXT: Metis has already completed — do NOT SendMessage to metis expecting a reply.
                Challenge the wonder above directly. Deliver reflection to team-lead.
                When done: SendMessage(to: 'team-lead', summary: 'eris reflect gen-{n} 완료', '{challenges}')")
        olympus_register_agent_spawn(pipeline_id, "eris")
        olympus_record_execution(pipeline_id, "genesis", "eris", ...)

        → Write gen-{n}/wonder.md from metis+eris SendMessage dialogue
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

2. SPAWN helios with IMMEDIATE TASK (first — generates perspectives, FOREGROUND):

   helios_result = Agent(name: "helios", team_name: ${TEAM},
         subagent_type: "olympus:helios",
         prompt: "You are Helios in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           LEADER_NAME: team-lead
           IMMEDIATE TASK: Generate analysis perspectives.
           DO NOT write files — you are read-only.
           Read ${ARTIFACT_DIR}/spec.md and codebase-context.md.
           Evaluate 6 complexity dimensions. Derive 3-6 orthogonal perspectives.
           Map analyst agents to perspectives.
           When done: SendMessage(to: 'team-lead', summary: 'helios 관점 완료', '{perspectives}')")
   olympus_register_agent_spawn(pipeline_id, "helios")
   → Write perspectives.md from helios SendMessage
   olympus_record_execution(pipeline_id, "pantheon", "helios", ...)

3. Perspective approval:
   AskUserQuestion with generated perspectives
   → Confirmed perspectives saved to perspectives.md (immutable)

4. SPAWN ares + poseidon IN PARALLEL with CROSS-REFERENCE (BACKGROUND):

   Agent(name: "ares", team_name: ${TEAM},
         subagent_type: "olympus:ares",
         run_in_background: true,
         prompt: "You are Ares in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           LEADER_NAME: team-lead
           IMMEDIATE TASK: Analyze from Code Quality perspective.
           DO NOT write files — you are read-only.
           Read ${ARTIFACT_DIR}/spec.md, codebase-context.md, perspectives.md.
           Read source-scope-analyst.md if present.
           Each finding: Severity (CRITICAL/WARNING/INFO), file:line, confidence 0.0-1.0 (report only ≥ 0.7).
           MANDATORY CROSS-REFERENCE: After your initial analysis, share key findings with 'poseidon':
             SendMessage(to: 'poseidon', summary: '코드품질→보안 크로스레퍼런스',
               'My key findings: {top 3 issues}. Questions:
                1. Do any of these have security implications?
                2. Are there security concerns I should factor into priority?')
           Wait for poseidon's response. Incorporate security feedback into final report.
           When done: SendMessage(to: 'team-lead', summary: 'ares 분석 완료', '{full findings}')")
   olympus_register_agent_spawn(pipeline_id, "ares")

   Agent(name: "poseidon", team_name: ${TEAM},
         subagent_type: "olympus:poseidon",
         run_in_background: true,
         prompt: "You are Poseidon in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           LEADER_NAME: team-lead
           IMMEDIATE TASK: Analyze from Security perspective.
           DO NOT write files — you are read-only.
           Read ${ARTIFACT_DIR}/spec.md, codebase-context.md, perspectives.md.
           Read source-scope-analyst.md if present.
           OWASP Top 10 + project-specific security scan.
           Each finding: Severity, CWE, file:line, confidence 0.0-1.0 (report only ≥ 0.7).
           MANDATORY CROSS-REFERENCE: After your initial analysis, share key findings with 'ares':
             SendMessage(to: 'ares', summary: '보안→코드품질 크로스레퍼런스',
               'My security findings: {top concerns}. Questions:
                1. Do the code quality issues you found compound these risks?
                2. Any refactoring that could inadvertently fix/worsen security?')
           Wait for ares's response. Incorporate quality feedback into final report.
           When done: SendMessage(to: 'team-lead', summary: 'poseidon 분석 완료', '{full findings}')")
   olympus_register_agent_spawn(pipeline_id, "poseidon")

   Note: ares and poseidon run IN PARALLEL. Both do initial analysis, then CROSS-REFERENCE.
   The cross-reference exchange happens directly between them via SendMessage.
   Results come via background completion notifications.
   olympus_pipeline_status(pipeline_id)  # verify ares + poseidon are registered before waiting
   olympus_log_collaboration(pipeline_id, "ares", "poseidon", "코드품질↔보안 크로스레퍼런스")

   WAIT for both completion notifications → leader aggregates into analyst-findings.md
   olympus_record_execution(pipeline_id, "pantheon", "ares", ...)
   olympus_record_execution(pipeline_id, "pantheon", "poseidon", ...)

   DEADLOCK FALLBACK: ares and poseidon each wait for the other's cross-reference response.
     If 3 minutes elapse without both completing:
     → SendMessage(to: "ares", "Cross-reference timeout. Proceed without waiting for poseidon. Note 'poseidon consultation pending'.")
     → SendMessage(to: "poseidon", "Cross-reference timeout. Proceed without waiting for ares. Note 'ares consultation pending'.")
     → Leader synthesizes from whichever responded; flags missing cross-reference in analyst-findings.md.

5. Eris DA challenge (FOREGROUND):
   eris_da = Agent(name: "eris", team_name: ${TEAM},
     subagent_type: "olympus:eris",
     prompt: "You are Eris in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
       LEADER_NAME: team-lead
       IMMEDIATE TASK: Read ${ARTIFACT_DIR}/analyst-findings.md.
       Read docs/shared/fallacy-catalog.md. Challenge findings using the 22 fallacy patterns. Max 2 rounds.
       Focus on: logical gaps, unsupported claims, overlooked risks.
       When done: SendMessage(to: 'team-lead', summary: 'eris DA 평가 완료', '{da-evaluation}')")
   olympus_register_agent_spawn(pipeline_id, "eris")
   → Write da-evaluation.md from eris SendMessage
   olympus_record_execution(pipeline_id, "pantheon", "eris", ...)

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

3. SPAWN zeus with IMMEDIATE TASK (FOREGROUND):

   zeus_result = Agent(name: "zeus", team_name: ${TEAM},
         subagent_type: "olympus:zeus",
         prompt: "You are Zeus in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           LEADER_NAME: team-lead
           IMMEDIATE TASK: Create implementation plan.
           Read ${ARTIFACT_DIR}/spec.md and analysis.md.
           Create task breakdown with Critical Files for Implementation.
           Write to ${ARTIFACT_DIR}/plan.md directly (you have Write access).
           When done: SendMessage(to: 'team-lead', summary: 'zeus 계획 완료', '{plan summary}')")
   olympus_register_agent_spawn(pipeline_id, "zeus")
   → zeus writes plan.md directly; leader reads after SendMessage notification
   olympus_record_execution(pipeline_id, "planning", "zeus", ...)

4. SPAWN themis with IMMEDIATE TASK (after plan.md exists, FOREGROUND):

   themis_result = Agent(name: "themis", team_name: ${TEAM},
         subagent_type: "olympus:themis",
         prompt: "You are Themis in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           LEADER_NAME: team-lead
           IMMEDIATE TASK: Critique implementation plan.
           DO NOT write files — you are read-only.
           Read ${ARTIFACT_DIR}/plan.md and spec.md.
           Verify completeness, feasibility, risk coverage.
           IMPORTANT: You are INDEPENDENT — do not consult zeus about the plan you're critiquing.
           Verdict: APPROVE / REVISE / REJECT with specific reasons and evidence.
           When done: SendMessage(to: 'team-lead', summary: 'themis 검토 완료', '{verdict + reasoning}')")
   olympus_register_agent_spawn(pipeline_id, "themis")
   olympus_record_execution(pipeline_id, "planning", "themis", ...)
   → Extract verdict from themis SendMessage

5. Verdict loop (max 3 iterations):
   → APPROVE: proceed to Step 6
   → REVISE: Re-spawn zeus (FOREGROUND) with Themis feedback:
       zeus_revised = Agent(name: "zeus", team_name: ${TEAM},
           subagent_type: "olympus:zeus",
           prompt: "You are Zeus in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
             LEADER_NAME: team-lead
             IMMEDIATE TASK: Revise plan.md based on Themis critique.
             Themis critique: {specific feedback}. Revise plan.md.
             Read ${ARTIFACT_DIR}/plan.md and fix precisely what Themis flagged.
             Write the revised plan directly to ${ARTIFACT_DIR}/plan.md (you have Write access).
             When done: SendMessage(to: 'team-lead', summary: 'zeus 수정계획 완료', '{revision summary}')")
     olympus_register_agent_spawn(pipeline_id, "zeus")
     olympus_record_execution(pipeline_id, "planning", "zeus-revised", ...)
     → zeus updates plan.md directly; leader reads after SendMessage notification
     Re-spawn themis (FOREGROUND) for re-review:
       themis_recheck = Agent(name: "themis", team_name: ${TEAM},
           subagent_type: "olympus:themis",
           prompt: "You are Themis in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
             LEADER_NAME: team-lead
             IMMEDIATE TASK: Re-review the revised plan.md against spec.md after Zeus's corrections.
             Re-review revised ${ARTIFACT_DIR}/plan.md against spec.md.
             When done: SendMessage(to: 'team-lead', summary: 'themis 재검토 완료', '{verdict}')")
     olympus_register_agent_spawn(pipeline_id, "themis")
     olympus_record_execution(pipeline_id, "planning", "themis-recheck", ...)
     → Re-check verdict
   → 3 consecutive REVISE: trigger Agora debate
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

2. SPAWN prometheus with IMMEDIATE TASK (main implementer, FOREGROUND):

   prometheus_result = Agent(name: "prometheus", team_name: ${TEAM},
         subagent_type: "olympus:prometheus",
         prompt: "You are Prometheus in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
           LEADER_NAME: team-lead
           IMMEDIATE TASK: Implement ${ARTIFACT_DIR}/plan.md.
           You CAN write files directly.
           Use teammate collaboration (per your Teammate_Protocol):
             - SendMessage(to: 'hermes') for unfamiliar code structure BEFORE implementing
             - SendMessage(to: 'artemis') when encountering errors
             - SendMessage(to: 'hephaestus') AFTER completing for build verification
           When complete, write your implementation report to ${ARTIFACT_DIR}/implementation-report.md directly.
           When done: SendMessage(to: 'team-lead', summary: 'prometheus 구현 완료', '{implementation report + collaboration log}')")
   olympus_register_agent_spawn(pipeline_id, "prometheus")

   olympus_record_execution(pipeline_id, "execution", "prometheus", ...)

3. Build verification (FOREGROUND):
   heph_result = Agent(name: "hephaestus", team_name: ${TEAM},
     subagent_type: "olympus:hephaestus",
     prompt: "You are Hephaestus in team ${TEAM}.
       LEADER_NAME: team-lead
       IMMEDIATE TASK: Run full build, lint, test, and type-check.
       When done: SendMessage(to: 'team-lead', summary: 'hephaestus 빌드검증 완료', '{PASS/FAIL + details}')")
   olympus_register_agent_spawn(pipeline_id, "hephaestus")
   olympus_record_execution(pipeline_id, "execution", "hephaestus", ...)

4. Debug cycle (if build fails, max 3 cycles):

   IF hephaestus SendMessage indicates FAIL:
     retryTracking.consecutiveDebugFailures++

     debug_result = Agent(name: "prometheus", team_name: ${TEAM},
       subagent_type: "olympus:prometheus",
       prompt: "You are Prometheus in team ${TEAM}.
         LEADER_NAME: team-lead
         IMMEDIATE TASK: Fix build/test failures reported by hephaestus.
         Build/test failed: {hephaestus SendMessage summary}.
         Fix the failures. You CAN write files directly.
         When done: SendMessage(to: 'team-lead', summary: 'prometheus 디버그 완료', '{fix report}')")
     olympus_register_agent_spawn(pipeline_id, "prometheus")
     olympus_record_execution(pipeline_id, "execution", "prometheus-debug", ...)

     → Re-run hephaestus verification (FOREGROUND)

     IF consecutiveDebugFailures >= 3:
       next = olympus_next_action(pipeline_id)
       # next.action guides: advance_phase (circuit breaker) or retry_phase (different approach)
       → Circuit breaker: proceed to Step 7 with current state
       → Tribunal will classify as BLOCKED or REJECTED_IMPLEMENTATION

5. Update odyssey-state.json:
   phase: "tribunal"
   gates.mechanicalPass: true (or false if circuit breaker)
```

---

## Step 7: Tribunal Phase

Three-stage evaluation with GENUINE adversarial debate (agents respond to each other's arguments).

```
1. MCP: olympus_next_phase(pipeline_id) → confirm "tribunal" is valid

2. Tribunal agents are spawned on-demand per stage (FOREGROUND):

3. Stage 1 — Hephaestus mechanical verification (FOREGROUND):
   mech_result = Agent(name: "hephaestus", team_name: ${TEAM},
     subagent_type: "olympus:hephaestus",
     prompt: "You are Hephaestus in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
       LEADER_NAME: team-lead
       IMMEDIATE TASK: Run build, lint, test, type-check.
       Write results to ${ARTIFACT_DIR}/mechanical-result.json directly (you have Write access).
       When done: SendMessage(to: 'team-lead', summary: 'hephaestus 검증 완료', '{PASS/FAIL summary}')")
   olympus_register_agent_spawn(pipeline_id, "hephaestus")
   olympus_record_execution(pipeline_id, "tribunal", "hephaestus", ...)
   → hephaestus writes mechanical-result.json directly; leader reads after SendMessage notification
   → FAIL: BLOCKED verdict → exit
   → ENV_UNAVAILABLE: MANUAL_REVIEW_REQUIRED — proceed to Stage 2 with caveat
   → PASS: Stage 2

4. Stage 2 — Athena semantic evaluation (FOREGROUND):
   athena_result = Agent(name: "athena", team_name: ${TEAM},
     subagent_type: "olympus:athena",
     prompt: "You are Athena in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
       LEADER_NAME: team-lead
       IMMEDIATE TASK: Evaluate AC compliance.
       Read ${ARTIFACT_DIR}/spec.md and mechanical-result.json.
       Evaluate each AC with file:line evidence.
       When done: SendMessage(to: 'team-lead', summary: 'athena 평가 완료', '{semantic-matrix content}')")
   olympus_register_agent_spawn(pipeline_id, "athena")
   olympus_record_execution(pipeline_id, "tribunal", "athena", ...)
   → Write semantic-matrix.md from athena SendMessage
   → AC compliance < 100% OR score < 0.8: INCOMPLETE → exit
   → PASS: check Stage 3 trigger

5. Stage 3 — Genuine adversarial debate (if triggered):
   Trigger: spec modified, score < 0.8, scope deviation, user request

   THIS IS A REAL DEBATE — each agent RESPONDS to the previous arguments.

   a. Ares opens (FOREGROUND):
      ares_position = Agent(name: "ares", team_name: ${TEAM},
        subagent_type: "olympus:ares",
        prompt: "You are Ares in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
         LEADER_NAME: team-lead
         IMMEDIATE TASK: Tribunal Stage 3 opening — argue APPROVE or REJECT from quality perspective.
         Read ${ARTIFACT_DIR}/semantic-matrix.md. Argue for APPROVE or REJECT from quality perspective.
         Include file:line evidence for every claim.
         When done: SendMessage(to: 'team-lead', summary: 'ares 포지션 완료', '{full position}')")
      olympus_register_agent_spawn(pipeline_id, "ares")
      olympus_record_execution(pipeline_id, "tribunal", "ares", ...)
      olympus_log_collaboration(pipeline_id, "ares", "eris", "Tribunal debate: ares opening")

   b. Eris challenges — SEES ares's full argument (FOREGROUND):
      eris_counter = Agent(name: "eris", team_name: ${TEAM},
        subagent_type: "olympus:eris",
        prompt: "You are Eris in team ${TEAM}.
         LEADER_NAME: team-lead
         IMMEDIATE TASK: Tribunal Stage 3 rebuttal — challenge Ares's argument with evidence.
         ARES ARGUES: {ares_position}.
         Your job: find logical fallacies, unsupported claims, overlooked evidence.
         Read docs/shared/fallacy-catalog.md. Include file:line counter-evidence.
         IMPORTANT: Respond SPECIFICALLY to ares's points — do not make independent arguments.
         When done: SendMessage(to: 'team-lead', summary: 'eris 반박 완료', '{full rebuttal}')")
      olympus_register_agent_spawn(pipeline_id, "eris")
      olympus_record_execution(pipeline_id, "tribunal", "eris", ...)
      olympus_log_collaboration(pipeline_id, "eris", "ares", "Tribunal debate: eris rebuttal")

   c. OPTIONAL: Ares rebuttal (if eris raised substantive new points, FOREGROUND):
      ares_rebuttal = Agent(name: "ares", team_name: ${TEAM},
        subagent_type: "olympus:ares",
        prompt: "You are Ares in team ${TEAM}.
         LEADER_NAME: team-lead
         IMMEDIATE TASK: Tribunal Stage 3 rebuttal — respond specifically to Eris's counter-arguments.
         ERIS COUNTERS: {eris_counter}.
         Respond ONLY to new points eris raised. Do not repeat your opening.
         Concede where eris is right. Defend where you have stronger evidence.
         When done: SendMessage(to: 'team-lead', summary: 'ares 재반박 완료', '{rebuttal}')")
      olympus_register_agent_spawn(pipeline_id, "ares")
      olympus_record_execution(pipeline_id, "tribunal", "ares-rebuttal", ...)

   d. Hera synthesizes — SEES the full debate transcript (FOREGROUND):
      hera_verdict = Agent(name: "hera", team_name: ${TEAM},
        subagent_type: "olympus:hera",
        prompt: "You are Hera in team ${TEAM}. Artifact directory: ${ARTIFACT_DIR}/
         LEADER_NAME: team-lead
         IMMEDIATE TASK: Synthesize the Tribunal debate and render final APPROVE/REJECT verdict.
         DEBATE TRANSCRIPT:
         === ARES OPENING === {ares_position}
         === ERIS REBUTTAL === {eris_counter}
         === ARES REBUTTAL === {ares_rebuttal or 'N/A'}
         MANDATORY: Before rendering verdict, consult hephaestus for current build/test status
         (or read mechanical-result.json if already available).
         Synthesize the debate. Where ares and eris disagree, determine who has stronger evidence.
         Produce final verdict: APPROVE / REJECT with reasoned synthesis.
         When done: SendMessage(to: 'team-lead', summary: 'hera 판결 완료', '{verdict}')")
      olympus_register_agent_spawn(pipeline_id, "hera")
      olympus_record_execution(pipeline_id, "tribunal", "hera", ...)

   Tally votes: supermajority >= 66% (per gate-thresholds.json consensus threshold)
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
1. TeamDelete(team_name: ${TEAM})

2. Generate final report:
   - Phases executed
   - Gate results per phase
   - Total teammate spawns and reuses
   - Final artifact locations

3. Update odyssey-state.json:
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
  - olympus_next_action: gate failure recovery + debug cycle strategy (SHOULD call)
  - olympus_pipeline_status: phase transition validation (SHOULD call)
  - olympus_log_collaboration: inter-agent exchange recording (SHOULD call)

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
  | ontology.json | Genesis | Leader | convergence check |
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
  - Consensus: ≥ 66% (Pantheon, Tribunal)
  - Semantic: ≥ 0.8 (Tribunal)
  - Mechanical: PASS (Tribunal)
  - Themis: APPROVE (Planning)
</Gate_Thresholds>

<Protocol_References>
  - docs/shared/orchestrator-protocol.md — §0 mandatory spawn rule, §6 full teammate mode
  - docs/shared/pipeline-states.json — state machine schema
  - docs/shared/gate-thresholds.json — gate values
  - docs/shared/context-management.md — compaction per phase transition
  - docs/shared/agent-context.md — worker isolation rules
</Protocol_References>
