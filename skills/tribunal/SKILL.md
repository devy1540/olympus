---
name: tribunal
description: "Trial of the Gods — 3-stage evaluation pipeline"
---

# /olympus:tribunal — Trial of the Gods

A pipeline that evaluates implementations through three stages: mechanical verification → semantic evaluation → consensus evaluation.

## Agents

**Subagent pattern** (Stages 1-2, one-shot):
- **Hephaestus**: Mechanical verification (Stage 1) → `subagent_type: "olympus:hephaestus"`
- **Athena**: Semantic evaluation (Stage 2) → `subagent_type: "olympus:athena"`

**Teammate pattern** (Stage 3, debate requires cross-reference):
- **Ares**: Consensus Proposer → `TeamCreate` name: `ares-proposer`
- **Eris**: Consensus DA → `TeamCreate` name: `eris-da`
- **Hera**: Consensus Synthesizer → `TeamCreate` name: `hera-synth`

**⚠ MANDATORY**:
- Stages 1-2: Spawn via Agent tool (one-shot analysis, no cross-reference needed).
- **Stage 3 is NOT optional** when trigger conditions apply. Do NOT skip to APPROVED after Athena alone.
- Stage 3 uses **sequential debate via teammates**: Ares proposes → Eris counter-argues (seeing Ares's position) → Hera synthesizes (seeing both). This is not possible with independent parallel subagents.
See orchestrator-protocol.md §0 and §5.

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

1. Create debate team:

   Step 1 — Create team:
     TeamCreate:
       team_name: "tribunal-debate-{id}"
       description: "Consensus debate for tribunal evaluation"

   Step 2 — Spawn debate members (parallel):
     Agent:
       description: "Ares proposer"
       name: "ares-proposer"
       team_name: "tribunal-debate-{id}"
       subagent_type: "olympus:ares"
       prompt: "You are Ares, proposer in a consensus debate.
         Artifact directory: .olympus/{id}/
         You will receive a debate prompt and must argue your position.
         Read semantic-matrix.md and relevant code to form your argument.
         Wait for messages — do not act until prompted."

     Agent:
       description: "Eris devil's advocate"
       name: "eris-da"
       team_name: "tribunal-debate-{id}"
       subagent_type: "olympus:eris"
       prompt: "You are Eris, devil's advocate in a consensus debate.
         Artifact directory: .olympus/{id}/
         You will receive Ares's position and must counter-argue.
         Read semantic-matrix.md and challenge Ares's reasoning with evidence.
         Wait for messages — do not act until prompted."

     Agent:
       description: "Hera synthesizer"
       name: "hera-synth"
       team_name: "tribunal-debate-{id}"
       subagent_type: "olympus:hera"
       prompt: "You are Hera, synthesizer in a consensus debate.
         Artifact directory: .olympus/{id}/
         You will receive both Ares's position and Eris's counter-argument.
         Synthesize both, then run tests via Bash to collect evidence.
         Produce a final synthesized verdict.
         Wait for messages — do not act until prompted."

2. Sequential debate (each sees the previous):

   Round 1 — Ares proposes:
     SendMessage(to: "ares-proposer"):
       summary: "Propose verdict"
       message: "Read .olympus/{id}/semantic-matrix.md and explore the relevant code.
         Argue for APPROVE or REJECT from a quality perspective.
         Include file:line evidence for every claim."
     → Ares responds with position + rationale

   Round 2 — Eris counter-argues (sees Ares's position):
     SendMessage(to: "eris-da"):
       summary: "Counter-argue"
       message: "Ares's position: {Ares response summary}.
         Read .olympus/{id}/semantic-matrix.md.
         Counter-argue against Ares's position with evidence.
         Challenge logical fallacies per fallacy-catalog.md."
     → Eris responds with counter-argument + evidence

   Round 3 — Hera synthesizes (sees both):
     SendMessage(to: "hera-synth"):
       summary: "Synthesize verdict"
       message: "Ares argues: {Ares summary}. Eris counters: {Eris summary}.
         Read .olympus/{id}/semantic-matrix.md.
         Synthesize both arguments, run tests for evidence, produce final verdict."
     → Hera responds with synthesized verdict

3. Tally votes:
   - Extract APPROVE/REJECT from each response
   - Supermajority >= 66%:
     - 2 of 3 approve → APPROVED
     - Only 1 approves → REJECTED + dissent recorded
     - All reject → REJECTED

4. Teardown debate team:
   SendMessage(to: "ares-proposer", message: { type: "shutdown_request" })
   SendMessage(to: "eris-da", message: { type: "shutdown_request" })
   SendMessage(to: "hera-synth", message: { type: "shutdown_request" })
   → Await shutdown_response from each
   TeamDelete: team_name: "tribunal-debate-{id}"

5. Save voting results to consensus-record.json
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
