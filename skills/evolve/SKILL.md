---
name: evolve
description: "Self-Evolution — improve Olympus itself through real-world testing and behavioral evaluation"
---

# /olympus:evolve — Self-Evolution

Runs Olympus against real tasks, evaluates the results, and improves agent prompts in a self-improvement loop.
While `/olympus:audit` guards structure (skeleton), `/olympus:evolve` builds capability (muscle).

## Agents (subagent_type bindings)
- **Athena**: Output quality evaluation (Semantic Evaluator) → `subagent_type: "olympus:athena"`
- **Eris**: Evaluation challenge + root cause diagnosis (Devil's Advocate) → `subagent_type: "olympus:eris"`
- **Metis**: Expected-actual gap analysis (Analyst) → `subagent_type: "olympus:metis"`
- **Prometheus**: Prompt improvement implementation (Executor) → `subagent_type: "olympus:prometheus"`

**⚠ MANDATORY**: All 4 agents MUST be spawned via Agent tool. Metis and Eris in Phase 4 MUST run in parallel. See orchestrator-protocol.md §0.

## Gates
- Quality score ≥ 0.8 (improvement target met)
- `/olympus:audit` CLEAN (structural consistency maintained)

## Artifact Contracts
| File | Phase | Writer | Readers |
|---|---|---|---|
| `.olympus/{id}/benchmark.md` | 1 | Orchestrator | All phases |
| `.olympus/{id}/dogfood-result.md` | 2 | Orchestrator | Athena, Metis |
| `.olympus/{id}/eval-matrix.md` | 3 | Orchestrator (from Athena) | Eris, Metis |
| `.olympus/{id}/diagnosis.md` | 4 | Orchestrator (from Metis+Eris) | Prometheus |
| `.olympus/{id}/refinement-log.md` | 5 | Orchestrator | Tracking |
| `.olympus/{id}/evolve-state.json` | all | Orchestrator | State recovery |

---

## Execution Flow

```
Phase 1 (Benchmark) → Phase 2 (Dogfood) → Phase 3 (Evaluate) → Phase 4 (Diagnose)
                                                                       ↓
Phase 7 (Lineage) ← Phase 6 (Audit) ← Phase 5 (Refine) ←─────────────┘
      ↓ target not met
      └──→ Phase 2 retry (max 5)
```

### Phase 1: Benchmark Selection

Select or generate the benchmark task to run.

```
Input classification:
  - User-provided: user specifies the benchmark task directly
  - Auto-generated: Olympus generates its own benchmark
  - History: reuse benchmark from a previous evolve run

Auto-generation:
  AskUserQuestion:
    question: "Which skill should be tested?"
    options:
      - "Oracle": requirements refinement quality test
      - "Pantheon": multi-perspective analysis quality test
      - "Tribunal": evaluation accuracy test
      - "Full pipeline": full Odyssey test

Benchmark definition:
  ## Benchmark

  ### Target Skill
  {skill to test}

  ### Scenario
  {test scenario description}

  ### Expected Quality
  | Dimension | Minimum | Ideal |
  |---|---|---|
  | Specificity | 0.7 | 0.9 |
  | Evidence Density | 0.6 | 0.8 |
  | Role Adherence | 0.8 | 1.0 |
  | Efficiency | 0.6 | 0.8 |
  | Actionability | 0.7 | 0.9 |

  ### Test Input
  {test input data}

Save as benchmark.md
```

### Phase 2: Dogfood (Real Execution)

Execute the target skill against the benchmark task.

```
1. Identify the Target Skill from benchmark
2. Execute the skill with Test Input:
   - Oracle → produces spec.md
   - Pantheon → produces analysis.md
   - Tribunal → produces verdict.md
   - Odyssey → full pipeline execution

3. Collect observation data during execution:
   - Each agent's output (SendMessage content)
   - Round counts (efficiency measurement)
   - Gate pass/fail history
   - Agent handoff records

4. Save all outputs and observation data to dogfood-result.md

Note: execution may require real user interaction (e.g., Apollo interview).
      User should provide benchmark answers in advance or respond during execution.
```

### Phase 3: Evaluate (Behavioral Assessment)

Spawn Athena as a Task to evaluate output quality across 5 dimensions.

```
Athena prompt: artifact directory path
Instruction: "Use Read to load benchmark.md and dogfood-result.md directly"

Evaluation dimensions:

3-1. Specificity — 0.0~1.0
  How concrete are the claims in the output?
  - 1.0: all claims include file:line, numbers, specific examples
  - 0.5: some claims are concrete, others are generic
  - 0.0: mostly "it appears to be" level

3-2. Evidence Density — 0.0~1.0
  Ratio of evidence-backed claims to total claims
  - claims_with_evidence / total_claims
  - Factor in clarity-enforcement violation count

3-3. Role Adherence — 0.0~1.0
  Did each agent stay within their role boundaries?
  - 1.0: all agents operated strictly within their role
  - 0.5: some role drift (e.g., Ares flagging security issues)
  - 0.0: role boundaries were meaningless

3-4. Efficiency — 0.0~1.0
  Did the pipeline reach the goal without unnecessary rounds?
  - Gate retry count
  - Stagnation occurrences
  - Effective rounds / total rounds ratio

3-5. Actionability — 0.0~1.0
  Is the output immediately actionable?
  - 1.0: can start the next step right away
  - 0.5: some parts need further clarification
  - 0.0: cannot proceed based on output alone

Output: eval-matrix.md
  ## Evaluation Matrix

  | Dimension | Score | Evidence | Benchmark Target |
  |---|---|---|---|
  | Specificity | {n} | {evidence} | {target} |
  | Evidence Density | {n} | {evidence} | {target} |
  | Role Adherence | {n} | {evidence} | {target} |
  | Efficiency | {n} | {evidence} | {target} |
  | Actionability | {n} | {evidence} | {target} |

  ### Overall Score: {weighted average}
  ### Weakest Dimension: {lowest scoring dimension}
  ### Strongest Dimension: {highest scoring dimension}
```

### Phase 4: Diagnose (Root Cause Analysis)

Spawn Metis and Eris as parallel Tasks to trace quality issues back to agent prompts.

```
Metis (gap analysis):
  Prompt: artifact directory path
  Instruction: "Use Read to load eval-matrix.md, dogfood-result.md, and agents/*.md directly"
  Mission: trace quality degradation causes to specific agent prompts

  Analysis protocol:
  1. Select the lowest-scoring dimension
  2. Identify the specific output that was problematic
  3. Identify the agent that produced it
  4. Trace the cause in the agent's prompt:
     - Is Investigation_Protocol insufficient?
     - Does Output_Format fail to enforce specificity?
     - Do Constraints allow role drift?
     - Are Examples showing the wrong behavior?
     - Does Failure_Modes_To_Avoid miss actual failures?
  5. Derive specific improvement proposals

Eris (challenge):
  Prompt: artifact directory path
  Instruction: "Use Read to load eval-matrix.md and dogfood-result.md directly"
  Mission: verify Athena's evaluation accuracy + identify additional problems

  Verification items:
  - Is the scoring too generous? (Generous Scoring)
  - Are there missed problems?
  - Did the analysis find root causes or just symptoms?

Synthesize both results into diagnosis.md:

  ## Diagnosis

  ### Root Causes
  | # | Symptom | Agent | Prompt Location | Root Cause | Severity |
  |---|---|---|---|---|---|
  | 1 | {symptom} | {agent} | {section:line} | {cause} | CRITICAL/HIGH/MEDIUM |

  ### Improvement Proposals
  | # | Target | Current | Proposed | Expected Impact |
  |---|---|---|---|---|
  | 1 | {agent.md:section} | {current content} | {proposed content} | {expected effect} |

  ### Eris Challenges
  - {challenge content + resolution status}
```

### Phase 5: Refine (Prompt Improvement)

```
1. Present diagnosis.md to the user:
   AskUserQuestion:
     question: "Apply these improvements?"
     options:
       - "Apply all": apply all improvements
       - "Select": choose which to apply
       - "Modify": edit improvements before applying
       - "Skip": skip this cycle

2. Spawn Prometheus as a Task for approved improvements:
   - Prompt: artifact directory path
   - Instruction: "Use Read to load diagnosis.md Improvement Proposals directly"
   - Mission: edit agent prompts per diagnosis specifications
   - Constraint: only perform changes specified in diagnosis.md (no scope creep)

3. Record changes in refinement-log.md:

   ## Refinement Log — Iteration {n}

   ### Changes Applied
   | # | File | Section | Change | Rationale |
   |---|---|---|---|---|
   | 1 | {file} | {section} | {change} | {rationale} |

   ### Changes Rejected
   | # | Proposal | Reason |
   |---|---|---|
   | 1 | {proposal} | {rejection reason} |
```

### Phase 6: Audit (Consistency Verification)

```
Run /olympus:audit on modified agent prompts:

1. Verify structural consistency:
   - Permission-role consistency maintained?
   - Cross-references intact?
   - Artifact contract consistency maintained?

2. Verdict:
   - CLEAN → Phase 7
   - VIOLATION → return to Phase 5 (modification broke structure)
   - WARNING → notify user, then Phase 7
```

### Phase 7: Lineage & Convergence

```
Update evolve-state.json:
{
  "id": "evolve-{YYYYMMDD}-{short-uuid}",
  "iteration": n,
  "maxIterations": 5,
  "benchmark": "benchmark.md",
  "history": [
    {
      "iteration": 1,
      "scores": {
        "specificity": 0.6,
        "evidence_density": 0.5,
        "role_adherence": 0.9,
        "efficiency": 0.7,
        "actionability": 0.6
      },
      "overall": 0.66,
      "changes": ["apollo.md: Investigation_Protocol strengthened", ...],
      "audit": "CLEAN"
    }
  ],
  "target": 0.8,
  "converged": false
}

Convergence check:
  if overall >= 0.8:
    → Converged. Generate final report.
    transition: { status: "terminal", reason: "completed" }
  elif iteration >= maxIterations:
    → Notify user:
      AskUserQuestion:
        - "Continue": extend maxIterations (+3)
        - "Accept": accept current state
        - "Reset benchmark": change benchmark and retry
  elif score_delta < 0.02 for 2 iterations:
    → Stagnation detected. Notify user:
      "Improvement has been minimal for 2 consecutive iterations.
       Change benchmark or focus on a different dimension?"
    transition: { status: "continue", reason: "persona_switch" }
  else:
    → Return to Phase 2 (same benchmark)
    transition: { status: "continue", reason: "generation_next", retryCount: n, maxRetries: 5 }

Final report:
  ## Evolution Report

  ### Iterations: {total iterations}
  ### Score Progression
  | Iteration | Specificity | Evidence | Role | Efficiency | Action | Overall |
  |---|---|---|---|---|---|---|
  | 1 | ... | ... | ... | ... | ... | 0.66 |
  | 2 | ... | ... | ... | ... | ... | 0.74 |
  | 3 | ... | ... | ... | ... | ... | 0.82 |

  ### Key Improvements
  - {key improvement 1}
  - {key improvement 2}

  ### Files Modified
  | File | Total Changes | Most Impactful Change |
  |---|---|---|
  | {file} | {count} | {most impactful change} |

  ### Remaining Weaknesses
  - {areas still needing improvement}
```

### Team Teardown

Shut down Athena, Eris, Metis, and Prometheus per the team-teardown.md protocol.

---

## Benchmark Library

Reusable benchmarks for common scenarios:

### Oracle Benchmark: "User Authentication System"
```
Target: Oracle
Input: "Build a login feature"
Expected: concrete spec.md from vague input
Focus: Apollo interview quality, Metis gap analysis depth
```

### Pantheon Benchmark: "Payment Module Analysis"
```
Target: Pantheon
Input: sample payment code + spec.md
Expected: domain-specific perspectives (not generic)
Focus: Helios perspective quality, Ares/Poseidon analysis depth
```

### Tribunal Benchmark: "Intentionally Flawed Code"
```
Target: Tribunal
Input: code with intentionally unmet ACs
Expected: accurate detection of unmet ACs
Focus: Athena accuracy, Hephaestus mechanical verification completeness
```
