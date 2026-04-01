---
name: tribunal
description: "Trial of the Gods — 3-stage evaluation pipeline"
---

# /olympus:tribunal — Trial of the Gods

A pipeline that evaluates implementations through three stages: mechanical verification → semantic evaluation → consensus evaluation.

## Agents (subagent_type bindings)
- **Hephaestus**: Mechanical verification (Stage 1) → `subagent_type: "olympus:hephaestus"`
- **Athena**: Semantic evaluation (Stage 2) → `subagent_type: "olympus:athena"`
- **Ares**: Consensus Proposer (Stage 3) → `subagent_type: "olympus:ares"`
- **Eris**: Consensus DA (Stage 3) → `subagent_type: "olympus:eris"`
- **Hera**: Consensus Synthesizer (Stage 3) → `subagent_type: "olympus:hera"`

## Final Verdict
APPROVED / BLOCKED / INCOMPLETE / REJECTED

## Artifact Contracts
| File | Stage | Writer | Readers |
|---|---|---|---|
| `.olympus/{id}/mechanical-result.json` | 1 | Hephaestus | Athena |
| `.olympus/{id}/semantic-matrix.md` | 2 | Athena | Stage 3 |
| `.olympus/{id}/consensus-record.json` | 3 | Orchestrator | Final verdict |
| `.olympus/{id}/verdict.md` | 3 | Orchestrator | User |

---

## Execution Flow

```
Stage 1 (Mechanical) → FAIL? → BLOCKED
                     → PASS → Stage 2 (Semantic) → FAIL? → INCOMPLETE
                                                  → PASS → Stage 3? → Verdict
```

### Stage 1: Hephaestus Mechanical Verification

```
1. Spawn Hephaestus as a Task:
   - Prompt: "Run build, lint, test, and type-check for the project"
2. Hephaestus executes in order:
   a. Build: run build command
   b. Lint: run lint check
   c. Type check: run type checker
   d. Test: run test suite
3. Save results to mechanical-result.json
4. Decision:
   - All items PASS → proceed to Stage 2
   - Any item FAIL → BLOCKED verdict + detailed error report
     Record in verdict.md and exit
```

### Stage 2: Athena Semantic Evaluation

```
1. Spawn Athena as a Task:
   - Prompt: artifact directory path
   - Instruction: "Use Read to load .olympus/{id}/spec.md and .olympus/{id}/mechanical-result.json directly" (do NOT inject full content)
2. Athena evaluates:
   a. Extract AC list from spec.md
   b. For each AC, search for implementation evidence (file:line)
   c. Determine AC status: MET (1.0) / PARTIALLY_MET (0.5) / NOT_MET (0.0)
   d. Calculate overall score: sum / count
3. Save results to semantic-matrix.md
4. Decision:
   - AC compliance = 100% AND overall score >= 0.8 → check Stage 3 trigger conditions
   - Otherwise → INCOMPLETE verdict
     Record unmet AC list in verdict.md
```

### Stage 3: Consensus Evaluation (conditional trigger)

**Trigger conditions** (execute if any apply):
- Spec was modified
- Overall score < 0.8
- Scope deviation detected
- User explicitly requested

If no trigger conditions apply, Stage 2 result yields APPROVED directly.

```
When triggered:
1. Spawn three agents as Tasks in parallel:

   Ares (Proposer):
   - Role: argue for approval or rejection from a quality perspective
   - Instruction: "Use Read to load .olympus/{id}/semantic-matrix.md directly, then explore the relevant code"
   - Output: approve or reject + rationale

   Eris (Devil's Advocate):
   - Role: counter-argue against Ares's position
   - Instruction: "Use Read to load .olympus/{id}/semantic-matrix.md directly, then counter Ares's argument"
   - Output: counter-argument + evidence

   Hera (Synthesizer):
   - Role: synthesize both arguments + collect test execution evidence
   - Instruction: "Synthesize both arguments, then run tests via Bash to collect evidence"
   - Output: synthesized verdict

2. Approval criterion: supermajority >= 66%
   - 2 of 3 approve → APPROVED
   - Only 1 approves → REJECTED + dissent recorded
   - All reject → REJECTED

3. Save voting results to consensus-record.json
```

### Final Verdict

```
Generate verdict.md:

# Tribunal Verdict

## Stage Results
- Stage 1 (Mechanical): {PASS/FAIL}
- Stage 2 (Semantic): {score} — {PASS/FAIL}
- Stage 3 (Consensus): {executed or not} — {result}

## Final Verdict: {APPROVED / BLOCKED / INCOMPLETE / REJECTED_*}

REJECTED subtypes (auto-classified based on Stage 2/3 analysis):
- REJECTED_IMPLEMENTATION: implementation quality issue → recommend returning to Odyssey Phase 5 (execution)
- REJECTED_SPEC: requirement defect (contradictory ACs, incomplete spec) → recommend returning to Oracle
- REJECTED_ARCHITECTURE: design/architecture issue (structural redesign needed) → recommend returning to Pantheon

Classification criteria:
- NOT_MET AC due to implementation omission → REJECTED_IMPLEMENTATION
- NOT_MET AC due to AC contradiction/incompleteness → REJECTED_SPEC
- NOT_MET AC due to architecture constraints making it infeasible → REJECTED_ARCHITECTURE

## Details
{per-verdict detailed content}

## Recommendations
{follow-up action recommendations + target Phase for return}
```

### Team Teardown

Shut down all evaluation agents per the team-teardown.md protocol.
