---
name: odyssey
description: "The Grand Journey — Oracle→Genesis→Pantheon→Plan→Execute→Tribunal full pipeline"
---

# /olympus:odyssey — The Grand Journey (Full Pipeline)

Executes the complete harness engineering pipeline from Oracle through Tribunal.

## Pipeline Overview

```
Phase 1: Oracle → spec.md
    ↓ Gate: ambiguity ≤ 0.2
Phase 2: Genesis (optional) → evolved spec.md
    ↓ Gate: ontology convergence ≥ 0.95
Phase 3: Pantheon → analysis.md
    ↓ Gate: consensus ≥ Working
Phase 4: Zeus + Themis → plan.md
    ↓ Gate: Themis APPROVE
Phase 5: Prometheus → implementation
    ↓ Gate: Hephaestus build/test pass
Phase 6: Tribunal → verdict.md
    ↓ APPROVED → Phase 7
    ↓ REJECTED → Phase 5 retry (max 3)
    ↓ 3 failures → Genesis rewind
Phase 7: Team teardown
```

## Agent Bindings (subagent_type)
| Agent | subagent_type |
|---|---|
| Zeus | `olympus:zeus` |
| Themis | `olympus:themis` |
| Prometheus | `olympus:prometheus` |
| Hephaestus | `olympus:hephaestus` |
| Artemis | `olympus:artemis` |
| Hera | `olympus:hera` |

> Sub-skills (Oracle, Genesis, Pantheon, Tribunal) use their own agent bindings when invoked.

**⚠ MANDATORY**: See orchestrator-protocol.md §0.
- Sub-skills (Oracle, Pantheon, Tribunal) MUST spawn their own agents as defined in their SKILL.md. The Odyssey orchestrator MUST NOT bypass sub-skill agent spawns.
- Zeus and Themis in Phase 4 MUST be spawned as separate Agent calls.
- Prometheus in Phase 5 MUST be spawned via Agent tool, not executed inline.

## State Management

Conforms to **pipeline-states.json** PipelineState schema (ported from Claude Code's query.ts State type).

```json
{
  "id": "odyssey-{YYYYMMDD}-{short-uuid}",
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
  "phaseTimings": {
    "oracle":    { "startedAt": null, "completedAt": null, "agentTurns": {} },
    "genesis":   { "startedAt": null, "completedAt": null, "agentTurns": {} },
    "pantheon":  { "startedAt": null, "completedAt": null, "agentTurns": {} },
    "planning":  { "startedAt": null, "completedAt": null, "agentTurns": {} },
    "execution": { "startedAt": null, "completedAt": null, "agentTurns": {} },
    "tribunal":  { "startedAt": null, "completedAt": null, "agentTurns": {} }
  },
  "genesisEnabled": false,
  "artifacts": {
    "specId": null,
    "genesisId": null,
    "pantheonId": null,
    "tribunalId": null
  }
}
```

State file: `.olympus/{id}/odyssey-state.json`

## MCP Integration

**⚠ MANDATORY**: If the MCP tool `olympus_start_pipeline` is available, the orchestrator MUST call MCP tools at each lifecycle point. The MCP server tracks state independently and enforces gates that the orchestrator cannot bypass.

```
Phase 0 (Init):
  Call: olympus_start_pipeline(skill: "odyssey", pipeline_id: "{id}")
  → Receive: required_agents list, first_phase

Each agent spawn:
  Call: olympus_register_agent_spawn(pipeline_id: "{id}", agent_name: "{agent}")
  → Server records spawn for later gate_check verification

Each gate check:
  Call: olympus_gate_check(pipeline_id: "{id}", gate_type: "{type}", score: {value})
  → Server verifies score AND checks all required agents were spawned
  → If missing spawns: response includes missing_spawns warning

Phase transition:
  Call: olympus_next_phase(pipeline_id: "{id}")
  → Server returns valid next phases (enforces transition rules)

After each agent completes:
  Call: olympus_record_execution(pipeline_id: "{id}", phase: "{phase}", agent_name: "{agent}", duration_ms: {ms}, token_count: {tokens})
  → Server accumulates execution history for future plan validation

Before Zeus planning (Phase 4):
  Call: olympus_validate_plan(pipeline_id: "{id}", skill: "odyssey", phase: "execution", agent: "prometheus", estimated_calls: {N})
  → Server checks against historical data and warns if estimate is unrealistic
```

If MCP tools are not available (binary not installed), the orchestrator proceeds without MCP — hooks provide fallback validation.

**Validation:** `validate-state.sh` enforces:
- Phase enum (pipeline-states.json OdysseyPhases)
- Transition rules (oracle→genesis|pantheon, etc.)
- Terminal/Continue reason enums
- retryTracking.evaluationPass ≤ maxPasses
- Gate preconditions per phase

**Compaction:** `compact-context.sh` auto-injects compaction instructions on phase transitions per **context-management.md**.

---

## Phase 1: Oracle

```
0. MCP: olympus_next_phase(pipeline_id) → confirm "oracle" is valid
1. Execute /olympus:oracle
2. Result: spec.md
3. MCP gate check:
   - ambiguityScore = read ambiguity-scores.json
   - Call: olympus_gate_check(pipeline_id, "ambiguity", ambiguityScore)
   - If passed → Phase 2
   - If failed → Oracle re-run (user override allowed)
   - If missing_spawns in response → warn and re-spawn missing agents
4. Update odyssey-state.json:
   - phase: "genesis" (or "pantheon" if genesis disabled)
   - transition: { status: "continue", reason: "next_phase" }
   - gates.ambiguityScore: {score}
   - artifacts.specId: "{oracle-id}"
```

## Phase 2: Genesis (optional)

```
Activation conditions (any):
  - User provides --evolve flag
  - Auto-detect: spec ONTOLOGY items > 10
  - Auto-detect: OPEN_QUESTIONS > 3

When disabled:
  - Skip to Phase 3

When enabled:
  1. Execute /olympus:genesis
  2. Result: evolved spec.md
  3. Gate check:
     - convergenceScore ≥ 0.95 → Phase 3
     - Convergence failure → notify user + confirm proceeding with current spec
  4. Update odyssey-state.json:
     - phase: "pantheon"
     - transition: { status: "continue", reason: "next_phase" }
     - gates.convergenceScore: {score}
     - artifacts.genesisId: "{genesis-id}"
```

## Phase 3: Pantheon

```
1. Execute /olympus:pantheon
   - Pass artifact directory path containing spec.md
   - Reuse Oracle's codebase-context.md if it exists (skip Hermes re-exploration)
2. Result: analysis.md
3. Gate check:
   - consensusLevel ≥ Working → Phase 4
   - Partial → user decides: proceed / re-run Pantheon (max 2)
   - No → re-run Pantheon (max 2)
4. Update odyssey-state.json:
   - phase: "planning"
   - transition: { status: "continue", reason: "next_phase" }
   - gates.consensusLevel: {level}
   - artifacts.pantheonId: "{pantheon-id}"
```

## Phase 4: Zeus Planning + Themis Critique

```
0. MCP: olympus_validate_plan(pipeline_id, "odyssey", "execution", "prometheus", estimated_calls)
   → If unrealistic: adjust plan scope before proceeding

1. Spawn Zeus as a Task:
   - Prompt: artifact directory path
   - Instruction: "Use Read to load spec.md and analysis.md directly"
   - Output: plan.md

2. Spawn Themis as a Task:
   - Prompt: artifact directory path
   - Instruction: "Use Read to load plan.md and spec.md directly"
   - Output: verdict (APPROVE / REVISE / REJECT)

3. Loop:
   - APPROVE → Phase 5
   - REVISE → forward feedback to Zeus → revise plan.md → Themis re-review
   - 2 consecutive REVISE → auto-trigger /olympus:agora:
     - Frame deadlocked issue as debate topic
     - Zeus (Planner) + Ares (Engineering) + Eris (DA) structured debate
     - Forward consensus result to Zeus → rewrite plan.md → Themis re-review
   - REJECT → notify user + AskUserQuestion:
     - "Return to Oracle": rewind to Phase 1 for requirement re-refinement
     - "Return to Pantheon": rewind to Phase 3 for re-analysis
     - "Exit": terminate Odyssey
   - Max 3 iterations (including Agora)

4. Update odyssey-state.json:
   - phase: "execution"
   - transition: { status: "continue", reason: "next_phase" }
   - gates.themisVerdict: "APPROVE"
```

## Phase 5: Prometheus Execution

```
1. Spawn Prometheus as a Task:
   - Prompt: artifact directory path
   - Instruction: "Use Read to load plan.md directly"
   - Inject worker-preamble (includes Artifact Reference Protocol)

2. After implementation, immediate build verification:
   - Spawn Hephaestus as a Task
   - Build/test pass → Phase 6
   - Build/test fail → deploy Artemis (debugger) → fix → re-verify

3. Debug cycle (if needed, max 3 cycles):
   - Spawn Artemis: root cause analysis
   - Spawn Prometheus: implement fix
   - Spawn Hephaestus: re-verify
   - Track: retryTracking.consecutiveDebugFailures++
   - If consecutiveDebugFailures >= 3:
     → Circuit breaker: stop debug loop
     → Proceed to Phase 6 (Tribunal) with current state
     → Tribunal will classify as BLOCKED or REJECTED_IMPLEMENTATION

4. Update odyssey-state.json:
   - phase: "tribunal"
   - transition: { status: "continue", reason: "next_phase" }
   - gates.mechanicalPass: true
```

## Phase 6: Tribunal

```
1. Execute /olympus:tribunal
2. Process verdict:
   - APPROVED → Hera final verification → Phase 7
   - BLOCKED → return to Phase 5 (build issue)
     transition: { status: "continue", reason: "debug_retry" }
   - INCOMPLETE → return to Phase 5 (unmet ACs)
     transition: { status: "continue", reason: "implementation_retry", retryCount: N, maxRetries: 3 }
   - REJECTED_IMPLEMENTATION → evaluationPass++ → return to Phase 5
     transition: { status: "continue", reason: "implementation_retry", retryCount: N, maxRetries: 3 }
   - REJECTED_SPEC → return to Phase 1 (Oracle)
     transition: { status: "terminal", reason: "rejected", returnToPhase: "oracle" }
     NOTE: Reverse transitions do NOT modify odyssey-state.json phase directly.
           Instead, create a new artifact directory and re-execute the target skill.
           (See orchestrator-protocol.md §5.2)
   - REJECTED_ARCHITECTURE → return to Phase 3 (Pantheon)
     transition: { status: "terminal", reason: "rejected", returnToPhase: "pantheon" }
     NOTE: Same as above — re-execute /olympus:pantheon with new artifact directory.

3. Retry logic (REJECTED_IMPLEMENTATION):
   if retryTracking.evaluationPass < retryTracking.maxPasses (3):
     → return to Phase 5 with feedback
   else:
     → Genesis rewind (spec needs evolution)
     → AskUserQuestion: "3 implementation evaluation failures. Evolve the spec?"
       - Yes → Phase 2 (Genesis)
       - No → terminate
     → transition: { status: "terminal", reason: "max_retries" }

4. Hera final verification (on APPROVED):
   - Spawn Hera as a Task
   - Verdict: APPROVED / APPROVED_WITH_CAVEATS / REJECTED
   - REJECTED → return to Phase 5
```

## Phase 7: Team Teardown

```
1. Execute team-teardown.md protocol
2. Generate final report:
   - Phases executed
   - Gate results per phase
   - Total rounds
   - Final artifact locations
3. Update odyssey-state.json:
   - phase: "completed"
   - transition: { status: "terminal", reason: "completed" }
```

## Protocol References

- **orchestrator-protocol.md** — Orchestrator decision logic, error recovery, escalation paths
- **pipeline-states.json** — Terminal/Continue state machine schema
- **context-management.md** — Compaction strategies per phase transition
- **agent-context.md** — Worker isolation rules
- **hook-responses.json** — Structured hook response format
