---
name: evolve
description: "Self-Evolution — improve Olympus itself through real-world testing and behavioral evaluation"
---

<Purpose>
Run Olympus against real tasks, evaluate results, and improve agent prompts in a self-improvement loop.
While /olympus:audit guards structure (skeleton), /olympus:evolve builds capability (muscle).
All agents operate as teammates for iterative evaluation and refinement with context retention.
</Purpose>

<Execution_Policy>
- This skill uses FULL TEAMMATE mode. All agents are teammates.
- Each Step MUST call the specified MCP tool. Do NOT skip MCP calls.
- Do NOT perform evaluation or diagnosis directly. Spawn agents and delegate.
- Metis and Eris MUST run in parallel for diagnosis (Step 5).
- Prometheus MUST implement improvements (Step 6) — do NOT edit agent files directly.
- Leader handles ONLY: team management, benchmark selection, convergence check, user approval.
- IMPORTANT: Do NOT skip ToolSearch at Step 0.
- TEAMMATE RESPONSE RULE: When a teammate goes idle without sending results,
  send a follow-up: SendMessage(to: "{agent}", "Report your findings now via SendMessage. Keep under 5000 chars.")
  Retry up to 3 times. NEVER do the agent's work directly — this violates §0.
</Execution_Policy>

<Team_Structure>
  team_name: "evolve-${CLAUDE_SESSION_ID}"

  Teammates:
  | Agent | Role | Comm Targets |
  |-------|------|-------------|
  | athena | Quality evaluation (5 dimensions) | leader |
  | eris | Evaluation challenge + root cause | metis (cross-reference), leader |
  | metis | Expected-actual gap analysis | eris (cross-reference), leader |
  | prometheus | Prompt improvement implementation | leader |

  Direct communication: metis ↔ eris (cross-reference during diagnosis)
</Team_Structure>

<Steps>

## Step 0: Load MCP Tools (REQUIRED FIRST)

```
Call ToolSearch("+olympus pipeline") to load MCP tools.
```

---

## Step 1: Initialize

```
1. TeamCreate(team_name: "evolve-${CLAUDE_SESSION_ID}")
2. olympus_start_pipeline(skill: "evolve", pipeline_id: ...)
3. Create artifact directory: .olympus/evolve-{YYYYMMDD}-{short-uuid}/
```

---

## Step 2: Benchmark Selection

```
Input classification:
  - User-provided: user specifies benchmark directly
  - Auto-generated: AskUserQuestion to select target skill
  - History: reuse from previous evolve run

Generate benchmark.md:
  ## Benchmark
  ### Target Skill: {skill}
  ### Scenario: {description}
  ### Expected Quality (5 dimensions: Specificity, Evidence Density, Role Adherence, Efficiency, Actionability)
  ### Test Input: {data}

Save to ${ARTIFACT_DIR}/benchmark.md
```

---

## Step 3: Dogfood (Real Execution)

```
Execute target skill against benchmark:
  - Oracle → spec.md
  - Pantheon → analysis.md
  - Tribunal → verdict.md
  - Odyssey → full pipeline

Collect observation data:
  - Each agent output
  - Round counts, gate history, handoff records

Save to ${ARTIFACT_DIR}/dogfood-result.md
```

---

## Step 4: Evaluate (Athena)

```
IF "athena" not in team:
  Agent(name: "athena", team_name: ${TEAM},
        subagent_type: "olympus:athena",
        prompt: "You are Athena, quality evaluator in ${TEAM}.
          Artifact directory: ${ARTIFACT_DIR}/
          Wait for messages — do not act until prompted.")
  olympus_register_agent_spawn(pipeline_id, "athena")

SendMessage(to: "athena", summary: "품질 평가",
  "Read ${ARTIFACT_DIR}/benchmark.md and dogfood-result.md.
   Evaluate across 5 dimensions (0.0~1.0):
     1. Specificity: concrete claims with file:line?
     2. Evidence Density: evidence-backed claims ratio
     3. Role Adherence: agents stayed within boundaries?
     4. Efficiency: goal reached without unnecessary rounds?
     5. Actionability: output immediately actionable?
   Report eval-matrix.md to leader.")

WAIT → leader writes eval-matrix.md
olympus_record_execution(pipeline_id, "evolve", "athena", ...)
```

---

## Step 5: Diagnose (Metis + Eris in PARALLEL)

```
IF "metis" not in team:
  Agent(name: "metis", team_name: ${TEAM},
        subagent_type: "olympus:metis",
        prompt: "You are Metis, gap analyst in ${TEAM}.
          You may cross-reference with 'eris' during diagnosis.
          Artifact directory: ${ARTIFACT_DIR}/
          Wait for messages — do not act until prompted.")
  olympus_register_agent_spawn(pipeline_id, "metis")

IF "eris" not in team:
  Agent(name: "eris", team_name: ${TEAM},
        subagent_type: "olympus:eris",
        prompt: "You are Eris, evaluation challenger in ${TEAM}.
          You may cross-reference with 'metis' during diagnosis.
          Artifact directory: ${ARTIFACT_DIR}/
          Wait for messages — do not act until prompted.")
  olympus_register_agent_spawn(pipeline_id, "eris")

Send BOTH in parallel:

SendMessage(to: "metis", summary: "갭 분석",
  "Read ${ARTIFACT_DIR}/eval-matrix.md, dogfood-result.md, and agents/*.md.
   Trace quality issues to specific agent prompts:
     - Investigation_Protocol insufficient?
     - Output_Format fails to enforce specificity?
     - Constraints allow role drift?
   Derive improvement proposals. Report to leader.")

SendMessage(to: "eris", summary: "평가 챌린지",
  "Read ${ARTIFACT_DIR}/eval-matrix.md and dogfood-result.md.
   Verify Athena's evaluation accuracy:
     - Scoring too generous?
     - Missed problems?
     - Root causes or just symptoms?
   Report to leader.")

WAIT for both → leader synthesizes into diagnosis.md
olympus_record_execution for each
```

---

## Step 6: Refine (Prometheus)

```
Present diagnosis.md to user:
  AskUserQuestion: "Apply these improvements?"
  ["Apply all", "Select", "Modify", "Skip"]

IF user approves:
  IF "prometheus" not in team:
    Agent(name: "prometheus", team_name: ${TEAM},
          subagent_type: "olympus:prometheus",
          prompt: "You are Prometheus, prompt improver in ${TEAM}.
            ONLY perform changes specified in diagnosis.md. No scope creep.
            Artifact directory: ${ARTIFACT_DIR}/
            Wait for messages — do not act until prompted.")
    olympus_register_agent_spawn(pipeline_id, "prometheus")

  SendMessage(to: "prometheus", summary: "프롬프트 개선",
    "Read ${ARTIFACT_DIR}/diagnosis.md Improvement Proposals.
     Edit agent prompts per specifications. No scope creep.
     Report changes to leader.")

  WAIT → leader writes refinement-log.md
  olympus_record_execution(pipeline_id, "evolve", "prometheus", ...)
```

---

## Step 7: Audit (Consistency Check)

```
Run /olympus:audit on modified prompts:
  CLEAN → Step 8
  VIOLATION → return to Step 6 (modification broke structure)
  WARNING → notify user, then Step 8
```

---

## Step 8: Convergence Check

```
Update evolve-state.json:
  { iteration, scores, changes, audit result }

Convergence:
  IF overall >= 0.8: converged → generate final report
  ELIF iteration >= maxIterations (5): AskUserQuestion [Continue, Accept, Reset]
  ELIF score_delta < 0.02 for 2 iterations: stagnation → notify user
  ELSE: return to Step 3 (same benchmark)
    ← Teammates REMEMBER previous iterations — evaluation improves

Generate final report: score progression, key improvements, remaining weaknesses
```

---

## Step 9: Teardown

```
Shutdown all teammates → TeamDelete
```

</Steps>

<Tool_Usage>
  MCP Tools:
  - olympus_start_pipeline: Step 1 (MUST)
  - olympus_register_agent_spawn: after each spawn (MUST)
  - olympus_record_execution: after each agent (SHOULD)

  Team Tools:
  - TeamCreate: Step 1
  - Agent (name + team_name): spawn athena, eris, metis, prometheus
  - SendMessage: PARALLEL for metis+eris, sequential for others
  - TeamDelete: Step 9
</Tool_Usage>

<Artifact_Contracts>
  | File | Step | Writer | Readers |
  |------|------|--------|---------|
  | benchmark.md | 2 | Leader | All |
  | dogfood-result.md | 3 | Leader | athena, metis |
  | eval-matrix.md | 4 | Leader (from athena) | eris, metis |
  | diagnosis.md | 5 | Leader (from metis+eris) | prometheus |
  | refinement-log.md | 6 | Leader | Tracking |
  | evolve-state.json | All | Leader | Convergence |
</Artifact_Contracts>

<Benchmark_Library>
  Oracle: "Build a login feature" → spec.md from vague input
  Pantheon: sample payment code → domain-specific perspectives
  Tribunal: intentionally flawed code → accurate detection of unmet ACs
</Benchmark_Library>
