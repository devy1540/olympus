---
name: pantheon
description: "Council of the Gods — multi-perspective analysis pipeline"
---

# /olympus:pantheon — Council of the Gods

A pipeline that analyzes problems from multiple perspectives and validates logical soundness through Devil's Advocate challenge.

## Agents (subagent_type bindings)
- **Hermes**: Codebase exploration → `subagent_type: "olympus:hermes"`
- **Helios**: Complexity assessment + perspective generation → `subagent_type: "olympus:helios"`
- **Ares**: Code quality perspective analysis → `subagent_type: "olympus:ares"`
- **Poseidon**: Security perspective analysis → `subagent_type: "olympus:poseidon"`
- **Zeus**: Architecture perspective analysis → `subagent_type: "olympus:zeus"`
- **Eris**: Devil's Advocate challenge → `subagent_type: "olympus:eris"`

**⚠ MANDATORY**: All agents above MUST be spawned via the Agent tool. In particular:
- **Helios MUST be spawned** for perspective generation (Phase 1). Do NOT skip to direct analysis.
- **Eris MUST be spawned** for DA challenge (Phase 4). Do NOT skip Eris even if analysts agree.
- Analyst agents MUST run in parallel via separate Agent tool calls.
See orchestrator-protocol.md §0.

## Gate
- Normal: Consensus ≥ Working (67%)
- Hell mode (--hell): Unanimous

## Artifact Contracts
| File | Phase | Writer | Readers |
|---|---|---|---|
| `.olympus/{id}/source-catalog.md` | 0 | Orchestrator | All agents |
| `.olympus/{id}/source-scope-analyst.md` | 0 | Orchestrator | Analyst agents |
| `.olympus/{id}/source-scope-da.md` | 0 | Orchestrator | Eris |
| `.olympus/{id}/perspectives.md` | 2 | Helios | All agents |
| `.olympus/{id}/context.md` | 2 | Orchestrator | All agents |
| `.olympus/{id}/analyst-findings.md` | 3 | Analyst agents | Eris |
| `.olympus/{id}/da-evaluation.md` | 4 | Eris | Consensus stage |
| `.olympus/{id}/prior-iterations.md` | 5 | Orchestrator | Re-entry |
| `.olympus/{id}/analysis.md` | 5 | Orchestrator | Downstream skills |

---

## Execution Flow

```
Phase 0 (OSM) → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
                                       ↑                      ↓
                                       └──── Feedback Loop ───┘
```

### Phase 0: Source Scope Mapping (optional)

Activated when the `--scope` flag is used or MCP resources are detected.
Default behavior: use local codebase + spec.md only and proceed directly to Phase 1.

When activated, follow the source-scope-mapping.md protocol:

```
Step 1: MCP data source discovery
  - Enumerate available MCP resources via ListMcpResourcesTool
  - Search for additional data tools via ToolSearch
  - Build an available source catalog

Step 2: Source selection
  - AskUserQuestion (multiSelect=true):
    "Select data sources for the analysis"
    - Discovered MCP sources
    - Local file system
    - Web search

Step 3: Add external sources (loop)
  - AskUserQuestion: "Any external sources to add? (URL, file path, or 'done')"
  - URL → collect content via WebFetch
  - File → collect content via Read
  - 'done' → exit loop

Step 4: Confirm pool
  - AskUserQuestion:
    - Proceed: continue with current pool
    - Reselect: go back to Step 2
    - Add more: go back to Step 3
    - Cancel: skip OSM entirely

Step 5: Generate scope blocks
  - Create source-catalog.md
  - Create source-scope-analyst.md (for analysts)
  - Create source-scope-da.md (for Eris)

Note: If no MCP is available, skip Steps 1-2 and start from Step 3 (soft dependency)
Note: If --scope flag is absent and no MCP is detected, skip Phase 0 entirely
```

### Phase 1: Helios Complexity Assessment + Perspective Generation

```
1. Spawn Helios as a Task:
   - Prompt: artifact directory path
   - Instruction: "Use Read to load: spec.md, codebase-context.md (if present), source-catalog.md (if present)"
2. Helios evaluates 6 complexity dimensions:
   - Domain, Technical, Risk, Stakeholders, Timeline, Novelty
3. Derives 3-6 orthogonal perspectives based on complexity profile
4. Applies perspective-quality-gate:
   - Orthogonality (overlap < 20%)
   - Evidence-based
   - Domain-specific
   - Actionable
5. Maps analyst agents to each perspective:
   - Code quality → olympus:ares
   - Security → olympus:poseidon
   - Architecture → olympus:zeus (Analysis_Mode)
   - Other → general-purpose with perspective prompt injection
```

### Phase 2: Perspective Approval

```
AskUserQuestion:
  question: "The following perspectives will be used for analysis:"
  options:
    - "Proceed": continue with confirmed perspectives
    - "Add perspective": add a perspective
    - "Remove perspective": remove a perspective
    - "Modify perspective": modify a perspective

Confirmed perspectives → saved to perspectives.md (immutable after this point)
Generate context.md: synthesize spec + perspectives + ontology
```

### Phase 3: Parallel Analysis

```
Spawn agents as Tasks in parallel, one per perspective:

Each agent prompt must include:
  - worker-preamble.md (includes Artifact Reference Protocol)
  - Artifact directory path: .olympus/{id}/
  - Assigned perspective's key questions
  - Instruction: "Use Read to load the following artifacts directly:
      1. .olympus/{id}/spec.md (ground truth — no summarization or modification)
      2. .olympus/{id}/context.md
      3. .olympus/{id}/source-scope-analyst.md (if present)"

⚠ Token efficiency: Do NOT inject full content of spec.md or context.md into prompts.
  Having agents Read via tool prevents N× duplication.

Agent mapping:
  - Code quality perspective → olympus:ares (subagent_type: "olympus:ares")
  - Security perspective → olympus:poseidon (subagent_type: "olympus:poseidon")
  - Architecture perspective → olympus:zeus (subagent_type: "olympus:zeus", Analysis_Mode)
  - Other perspectives → general-purpose (subagent_type: "general-purpose") + perspective prompt

Aggregate all analysis results into analyst-findings.md
```

### Phase 4: Eris Challenge

```
1. Spawn Eris as a Task:
   - Prompt: artifact directory path
   - Instruction: "Use Read to load: .olympus/{id}/analyst-findings.md, docs/shared/fallacy-catalog.md, .olympus/{id}/source-scope-da.md (if present)"
2. Eris scans all analysis results:
   - Detect logical fallacies per fallacy-catalog
   - Identify claims lacking evidence
3. Challenge-Response (max 2 rounds):
   - Round 1: core challenges → forwarded to analysts
   - Round 2: residual challenges (if needed)
4. BLOCKING_QUESTION resolution priority:
   - Solvable via tools → execute tool
   - Analyst can answer → forward to analyst
   - Only user can answer → AskUserQuestion
5. Verdict: SUFFICIENT / NOT_SUFFICIENT / NEEDS_TRIBUNAL
```

### Phase 5: Consensus & Synthesis

```
Apply consensus-levels.md criteria:

if consensus >= threshold:  # Normal: Working, Hell: Strong
    → Generate analysis.md (synthesis of all perspectives)
    → Proceed to Phase 6
else:
    → Feedback loop:
      - Preserve existing analysis results (save to prior-iterations.md)
      - Add new perspectives only
      - Re-run Phase 3-4
      - Max 2 iterations (normal) / unlimited (--hell)
      - After 2 failures → escalate to user

analysis.md structure:
  ## Per-Perspective Summary
  ## Cross-Perspective Findings
  ## DA Verification Results
  ## Consensus Level and Dissent
  ## Recommendations
```

### Phase 6: Team Teardown

Shut down all analyst agents per the team-teardown.md protocol.
