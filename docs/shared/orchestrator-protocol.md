# Orchestrator Protocol

## Overview

The orchestrator is the execution host for skills. It runs the pipeline defined in each skill's SKILL.md, spawning and terminating agents, persisting artifacts, and evaluating gates.

This document specifies the orchestrator's decision logic, artifact management rules, error recovery procedures, and escalation paths.

---

## 0. Mandatory Agent Spawn Rule

**CRITICAL — This rule overrides all other considerations.**

When a SKILL.md specifies "Spawn {Agent} as a Task", the orchestrator **MUST** use the Agent tool with the specified `subagent_type`. The orchestrator **MUST NOT**:

1. Perform the agent's work directly (e.g., running Grep/Read instead of spawning Hermes)
2. Skip an agent because "I can do it faster myself"
3. Combine multiple agents' roles into a single action
4. Skip pipeline stages (e.g., Eris DA challenge, Stage 3 consensus) unless the SKILL.md explicitly defines skip conditions

**Why this rule exists:**
- **Role separation is the product.** An orchestrator that does everything itself is just a monolithic agent with extra steps
- **Adversarial verification requires independent agents.** Eris cannot challenge findings she produced. Themis cannot critique a plan she wrote
- **Specialization produces better results.** Hermes (haiku, fast exploration) finds different things than the orchestrator (opus, generalist)

**Enforcement:** If the orchestrator performs work that SKILL.md assigns to an agent, it is equivalent to a read-only agent writing files directly — a protocol violation.

**The only exception:** If the Agent tool is unavailable or agent spawn fails after retry, the orchestrator may fall back to direct execution with a logged warning: `"FALLBACK: {Agent} spawn failed, executing directly. Reason: {reason}"`

---

## 1. Artifact Management Rules

### 1.1 Write on Behalf

Read-only agents (those with Write/Edit in `disallowedTools`) cannot save files directly. The orchestrator writes on their behalf:

```
Agent → SendMessage(result) → Orchestrator → Write(.olympus/{id}/{artifact})
```

**Rules:**
- Save the content of `SendMessage` **verbatim**. The orchestrator must not summarize or transform it.
- When aggregating results from multiple agents (e.g., `analyst-findings.md`), separate each agent's output into distinct sections.
- Artifact filenames must exactly match those defined in `artifact-contracts.json`.
- **Size tracking**: If a SendMessage result exceeds `maxResultSizeChars` (default: 50,000, per `agent-schema.json`), log a warning in the artifact with the actual size. Oversized results may be truncated by the runtime, causing silent data loss. When this occurs, add a note at the top of the saved artifact: `<!-- WARNING: Agent output was {N} chars, exceeding maxResultSizeChars ({limit}). Content may be truncated. -->`

### 1.2 Artifact Reference (No Full-Content Injection)

When passing artifacts to agents, **do not embed the full content in the prompt**.

```
BAD:  "Here is the spec.md content: {full spec, 5000 chars}"
GOOD: "Artifact directory: .olympus/{id}/. Use Read to load spec.md directly."
```

**Exception:** Short values under 100 characters (e.g., scores, verdict strings) may be passed inline.

### 1.3 Artifact Directory

All artifacts are stored under `.olympus/{skill}-{YYYYMMDD}-{short-uuid}/`.

```
.olympus/
  oracle-20260305-a3f8b2c1/
    codebase-context.md
    interview-log.md
    ambiguity-scores.json
    gap-analysis.md
    spec.md
```

Meta-skills like Odyssey record sub-skill artifact directory paths in `odyssey-state.json`.

---

## 2. Gate Decision Logic

Gate evaluation compares numeric values stored in artifacts against thresholds defined in `gate-thresholds.json`.

### 2.1 Gate Evaluation Order

```
1. Artifact is saved (PostToolUse hook validates automatically)
2. Orchestrator reads the artifact to confirm the numeric value
3. Compares against gate-thresholds.json threshold
4. Pass → next Phase / Fail → recovery logic
```

### 2.2 Gate Failure Recovery

| Gate | On Failure | Max Retries | Escalation |
|------|-----------|-------------|------------|
| Ambiguity (≤ 0.2) | Re-enter Phase 2 (interview) | 10 rounds | Offer user override |
| Convergence (≥ 0.95) | Re-enter Phase 1 (Wonder) | 30 generations | Persona switch or user decision on stagnation |
| Consensus (≥ 67%) | Phase 3-4 feedback loop | 2 (normal) | User escalation |
| Semantic (≥ 0.8) | Re-enter Phase 5 (implementation) | 3 (evaluationPass) | Genesis rewind + user decision |
| Mechanical (PASS) | Enter Phase 5 (debugging) | 3 | BLOCKED verdict and exit |

### 2.3 Cross-Validation

Gate values may be self-scored by the LLM. The following cross-validation checks are performed:

- **Ambiguity**: Verify that the round count in `ambiguity-scores.json` matches the actual number of rounds in `interview-log.md`
- **Semantic**: Verify that `file:line` references in `semantic-matrix.md` point to files that actually exist
- **Mechanical**: Verify that `mechanical-result.json` reflects actual build/test execution results (run via Bash)

These checks are performed automatically by the `validate-gate.sh` hook.

---

## 3. Error Recovery

### 3.1 Agent Task Failure

When an agent Task fails (reports error via SendMessage):

```
1. Classify the failure cause:
   - TOOL_ERROR: Tool execution failed → retry (max 1)
   - SCOPE_ERROR: Out of scope → redefine task and retry
   - CONTENT_ERROR: Insufficient output quality → retry with feedback
   - FATAL: Unrecoverable → escalate to user

2. On retry, include the previous failure reason in the prompt to prevent the same failure
3. After 2 consecutive failures → ask the user via AskUserQuestion
```

### 3.2 Pipeline Phase Failure

When an entire phase fails:

```
1. Save current state to state.json (checkpoint.sh backs up automatically)
2. Present options to the user:
   - Retry: Re-run the same phase
   - Rewind: Go back to a previous phase
   - Skip: Skip the current phase (not allowed if the phase has a gate)
   - Abort: Terminate the pipeline
3. Update state.json based on the user's choice and proceed
```

### 3.3 Graceful Degradation

When external dependencies (MCP, web, etc.) fail:

```
- MCP sources unavailable → skip Source Scope Mapping (soft dependency)
- WebFetch fails → proceed with local sources only
- Agent timeout → apply the timeout protocol from team-teardown.md
```

---

## 4. Escalation Paths

Situations requiring user intervention:

| Situation | Trigger | User Options |
|-----------|---------|-------------|
| Repeated gate failure | Max retries exceeded | Override / Rewind / Abort |
| No consensus reached | Consensus < 60% twice in a row | Decide / Add perspectives / Abort |
| Repeated Themis rejection | REVISE twice consecutively | Agora debate / Override / Abort |
| Repeated evaluation failure | evaluationPass >= 3 | Genesis rewind / Override / Abort |
| Stagnation detected | Spinning/Oscillation/Diminishing | Persona switch / Change benchmark / Abort |

### 4.1 Context-Rich Escalation Rule

When escalating to the user via AskUserQuestion, the orchestrator MUST provide full context. The user is not watching the pipeline internals — they see only the question.

**Required:**
1. **What happened**: Which phase, which agent, what was attempted
2. **Why it failed**: The specific gate value, error, or disagreement
3. **What the options mean**: Concrete consequences of each choice
4. **Current state**: How far the pipeline has progressed

**Example:**
```
Tribunal Stage 2 evaluated your implementation against spec.md and found 2 of 5 ACs unmet:
  - AC #3 (error handling): No 401 response on expired tokens — src/auth/middleware.ts returns 500 instead
  - AC #5 (rate limiting): Not implemented

This is the 2nd evaluation failure (max 3). Options:
  A) Return to implementation — Prometheus will fix the 2 unmet ACs
  B) Evolve the spec — some ACs may be unrealistic given the codebase
  C) Abort — stop the pipeline
```

---

## 5. State Management

### 5.1 State File Convention

- `odyssey-state.json`: Odyssey pipeline state (phase, gates, evaluationPass, artifacts)
- `evolve-state.json`: Evolve loop state (iteration, scores, history)
- `convergence.json`: Genesis convergence state (similarity, stagnation, history)

### 5.2 State Transition Rules

State transitions are automatically validated by the `validate-state.sh` hook:

```
oracle → genesis | pantheon
genesis → pantheon
pantheon → planning
planning → execution
execution → tribunal
tribunal → completed | execution (retry)
```

Reverse transitions (e.g., Tribunal → Oracle) are not handled by modifying the phase in `state.json` directly. Instead, they are processed by re-executing the target skill (e.g., re-run `/olympus:oracle` → creates a new artifact directory).

### 5.3 Checkpoint & Recovery

The `checkpoint.sh` hook automatically backs up state files to `.checkpoints/` whenever they are saved. Recovery can resume from the most recent valid checkpoint.

---

## 6. Full Teammate Mode

Olympus uses **Full Teammate Mode** — all agents are spawned as teammates in a single team per skill execution. This provides cross-phase context retention, inter-agent direct communication, and reduced leader context pressure.

### 6.1 Core Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Team: "{skill}-${CLAUDE_SESSION_ID}"                       │
│                                                             │
│  Leader (Orchestrator / SKILL.md executor)                  │
│    ├── Phase transitions, gate checks, MCP state            │
│    ├── Teammate spawn/teardown                              │
│    └── Does NOT perform agent work directly (§0 applies)    │
│                                                             │
│  Teammates (lazy-spawned, persist across phases):           │
│    ├── hermes ←→ prometheus, apollo (codebase queries)      │
│    ├── apollo ←→ hermes, metis (interview + gap analysis)   │
│    ├── metis ←→ eris (wonder/reflect loop)                  │
│    ├── prometheus ←→ hermes, artemis, hephaestus (impl)     │
│    ├── artemis ←→ prometheus (debugging)                    │
│    ├── hephaestus ←→ prometheus (build verification)        │
│    ├── ares ←→ eris (debate)                                │
│    └── ... (all 15 agents available)                        │
│                                                             │
│  Communication: SendMessage (async, file-based mailbox)     │
│  State: MCP server (olympus_next_action per agent)          │
└─────────────────────────────────────────────────────────────┘
```

**Why full teammate over subagent:**

| Dimension | Subagent | Full Teammate |
|:----------|:---------|:-------------|
| Context retention | Fresh each call | Accumulates across turns |
| Inter-agent communication | Via leader only | Direct SendMessage |
| Implementation retry | Re-read everything | Remembers what was done |
| Leader context pressure | All results flow through | Summary-level only |
| Token efficiency | Re-initialize each time | Cache reuse |
| Agent collaboration | Not possible | Prometheus ↔ Hermes directly |

### 6.2 Team Structure per Skill

Each skill creates one team. Odyssey creates a single team that spans all sub-skills.

| Skill | Team Name | Lazy-Spawned Agents |
|:------|:----------|:-------------------|
| **Odyssey** | `odyssey-{session_id}` | All agents (up to 14, spawn on demand) |
| **Oracle** | `oracle-{session_id}` | hermes, apollo, metis, eris |
| **Genesis** | `genesis-{session_id}` | metis, eris |
| **Pantheon** | `pantheon-{session_id}` | hermes, helios, ares, poseidon, zeus, eris |
| **Tribunal** | `tribunal-{session_id}` | hephaestus, athena, ares, eris, hera |
| **Review-PR** | `review-pr-{session_id}` | hermes, helios, ares, poseidon, eris, nemesis |

When Odyssey invokes a sub-skill (e.g., Oracle phase), agents are spawned into the **Odyssey team** — not a separate Oracle team. This enables cross-phase reuse (e.g., Hermes spawned in Oracle is reused in Execution).

### 6.3 Lazy Spawn Strategy

Agents are spawned **on first need**, not all at once:

```
Phase 1 (Oracle):    spawn hermes, apollo, metis, eris     → 4 active
Phase 2 (Genesis):   reuse metis, eris                     → 4 active (2 idle)
Phase 3 (Pantheon):  spawn helios, ares, poseidon, zeus    → 8 active (reuse hermes, eris)
Phase 4 (Planning):  reuse zeus                             → 8 active (others idle)
Phase 5 (Execution): spawn prometheus, artemis, hephaestus → 11 active
Phase 6 (Tribunal):  spawn athena, hera                    → 13 active (reuse ares, eris)
```

**Spawn check pattern** (used in SKILL.md):
```
IF "{agent}" not in team:
  Agent(name: "{agent}", team_name: "${TEAM}", subagent_type: "olympus:{agent}", prompt: "...")
  olympus_register_agent_spawn(pipeline_id, "{agent}")
ELSE:
  SendMessage(to: "{agent}", "{new task}")   ← reuse existing teammate
```

Memory impact: ~125MB per concurrent in-process teammate. With lazy spawn + idle state, peak is manageable (~750MB at 6 concurrent active).

### 6.4 Inter-Agent Communication

Teammates communicate via SendMessage. The leader does NOT need to relay every message.

**Permitted direct communication paths:**

| From | To | Purpose |
|:-----|:---|:--------|
| prometheus | hermes | Codebase structure queries during implementation |
| prometheus | artemis | Debugging assistance during implementation |
| prometheus | hephaestus | Quick build checks during implementation |
| apollo | hermes | Codebase context during interview |
| apollo | metis | Gap analysis feedback during interview |
| metis | eris | Wonder/Reflect loop (Genesis) |
| ares | eris | Debate exchange (Tribunal Stage 3) |
| hera | hephaestus | Evidence collection for verdict |
| Any agent | leader | Task completion, results, escalation |

**Communication rules:**
1. All messages use `SendMessage(to: "{name}", summary: "{5-10 words}", "{content}")`
2. Agents MUST report task completion to the leader
3. Agents MUST NOT bypass the leader for phase transitions or gate checks
4. Agents MUST NOT spawn other teammates (only the leader can spawn)
5. Message order is NOT strictly guaranteed — do not rely on ordering for correctness

### 6.5 Teammate Lifecycle Rules

1. **Team creation at skill start**: `TeamCreate(team_name: "{skill}-{session_id}")` before any agent spawn
2. **Lazy spawn on first use**: `Agent(name, team_name, subagent_type, prompt)` when the phase first needs the agent
3. **Reuse across phases**: If an agent is already in the team, use `SendMessage` instead of re-spawning
4. **Gate enforcement stays with leader**: Teammates report results, leader checks gates via MCP + artifact files
5. **Permission inheritance**: Teammates inherit their agent definition's permissions. Read-only agents (Write/Edit in disallowedTools) remain read-only as teammates — they SendMessage results to the leader who writes files
6. **Cross-phase persistence**: Teammates survive across phase boundaries within the same skill execution. This is a key advantage — Prometheus remembers what it implemented when asked to fix tests
7. **Teardown at skill end**: `SendMessage(to: each, shutdown_request)` → await responses → `TeamDelete`
8. **No cross-skill persistence**: When Odyssey's sub-skills complete, the team persists. But standalone skill teams are torn down when the skill ends

### 6.6 Leader Responsibilities

The leader (orchestrator) focuses on coordination, not content:

| Responsibility | Leader | Teammates |
|:--------------|:-------|:----------|
| Phase transitions | ✅ | ❌ |
| Gate checks (MCP) | ✅ | ❌ |
| Agent spawn/teardown | ✅ | ❌ |
| Artifact writing (for read-only agents) | ✅ | ❌ |
| Codebase exploration | ❌ (→ hermes) | ✅ |
| Code implementation | ❌ (→ prometheus) | ✅ |
| Interview | ❌ (→ apollo) | ✅ |
| Analysis/review | ❌ (→ specialist) | ✅ |
| Inter-agent collaboration | Monitor only | ✅ Direct |

### 6.7 MCP Integration with Teammates

MCP tools support both leader and teammate queries:

```
Leader calls:
  olympus_start_pipeline(skill, pipeline_id)        → Initialize pipeline
  olympus_next_phase(pipeline_id)                    → Phase transition
  olympus_gate_check(pipeline_id, gate, score)       → Gate evaluation
  olympus_register_agent_spawn(pipeline_id, agent)   → Record teammate spawn

Teammate calls (new):
  olympus_next_action(pipeline_id, agent: "{name}")  → "What should I do next?"
  olympus_log_collaboration(pipeline_id, from, to, summary) → Record inter-agent exchange

Both:
  olympus_record_execution(pipeline_id, phase, agent, duration_ms, token_count)
```

### 6.8 Fallback & Graceful Degradation

When teammate features are unavailable or fail:

| Failure | Fallback |
|:--------|:---------|
| Teammate spawn fails | Retry once → fall back to subagent (Agent tool without team_name) |
| SendMessage delivery fails | Leader relays the message content manually |
| MCP server unavailable | Proceed without MCP — hooks provide validation |
| Teammate crashes mid-task | Re-spawn into same team (new context, but team persists) |
| Memory pressure (too many active) | Send idle agents `shutdown_request`, re-spawn if needed later |

**Important**: Fallback to subagent mode loses cross-phase context and inter-agent communication. Log a warning when this occurs: `"FALLBACK: {agent} teammate spawn failed, using subagent mode. Cross-phase context will be lost."`
