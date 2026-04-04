---
name: audit
description: "Olympus Audit — automated plugin internal consistency validation"
---

<Purpose>
Validate the internal consistency of the Olympus plugin: agent permissions, cross-references,
artifact contracts, gate thresholds, and clarity rules.
Hephaestus and Athena operate as teammates for cross-phase context sharing.
</Purpose>

<Execution_Policy>
- This skill uses FULL TEAMMATE mode. Hephaestus and Athena are teammates.
- Each Step MUST call the specified MCP tool. Do NOT skip MCP calls.
- Do NOT perform validation directly. Hephaestus handles mechanical, Athena handles semantic.
- Leader handles ONLY: team management, report synthesis.
- IMPORTANT: Do NOT skip ToolSearch at Step 0.
- PROACTIVE SPAWN RULE (§6.3): Every Agent() call MUST include IMMEDIATE TASK in prompt.
  NEVER use "Wait for messages — do not act until prompted."
- MANDATORY CONSULTATION (§7): Athena MUST read hephaestus results before reporting.
  Athena's report without reference to audit-mechanical.json is incomplete.
- RESPONSE RULE: If teammate doesn't report, retry up to 3 times. NEVER do agent's work directly.
</Execution_Policy>

<Team_Structure>
  team_name: "audit-${CLAUDE_SESSION_ID}"

  Teammates:
  | Agent | Role | Comm Targets |
  |-------|------|-------------|
  | hephaestus | Mechanical validation (YAML, files, structure) | leader |
  | athena | Semantic validation (permissions, contracts, gates) | hephaestus (evidence), leader |
</Team_Structure>

<Steps>

## Step 0: Load MCP Tools (REQUIRED FIRST)

```
Call ToolSearch("+olympus pipeline") to load MCP tools.
```

---

## Step 1: Initialize

```
1. TeamCreate(team_name: "audit-${CLAUDE_SESSION_ID}")
2. olympus_start_pipeline(skill: "audit", pipeline_id: ...)
3. Create artifact directory: .olympus/audit-{YYYYMMDD}-{short-uuid}/
```

---

## Step 2: Hephaestus Mechanical Validation

```
IF "hephaestus" not in team:
  Agent(name: "hephaestus", team_name: ${TEAM},
        subagent_type: "olympus:hephaestus",
        run_in_background: true,
        prompt: "You are Hephaestus, mechanical validator in ${TEAM}.
          Artifact directory: ${ARTIFACT_DIR}/
          IMMEDIATE TASK: Validate Olympus plugin structural integrity:
          1-1. YAML Frontmatter: validate agents/*.md against agent-schema.json
          1-2. File existence: verify cross-references between agents and skills
          1-3. Shared doc references: verify docs/shared/ references exist
          1-4. artifact-contracts.json: verify writer/reader agents exist
          1-5. Hook scripts: verify hooks.json scripts exist, are executable, pass bash -n
          Report audit-mechanical.json to leader via SendMessage.
          STAY AVAILABLE — athena will query you for additional mechanical evidence.")
  olympus_register_agent_spawn(pipeline_id, "hephaestus")

SendMessage(to: "hephaestus", summary: "기계적 검증",
  "Validate Olympus plugin structural integrity:
   1-1. YAML Frontmatter: validate agents/*.md against agent-schema.json
   1-2. File existence: verify cross-references between agents and skills
   1-3. Shared doc references: verify docs/shared/ references exist
   1-4. artifact-contracts.json: verify writer/reader agents exist
   1-5. Hook scripts: verify hooks.json scripts exist, are executable, pass bash -n
   Report audit-mechanical.json to leader.")

WAIT → leader writes audit-mechanical.json
olympus_record_execution(pipeline_id, "audit", "hephaestus", ...)
```

---

## Step 3: Athena Semantic Validation

```
IF "athena" not in team:
  Agent(name: "athena", team_name: ${TEAM},
        subagent_type: "olympus:athena",
        run_in_background: true,
        prompt: "You are Athena, semantic validator in ${TEAM}.
          Artifact directory: ${ARTIFACT_DIR}/
          IMMEDIATE TASK: Wait for audit-mechanical.json to appear in ${ARTIFACT_DIR}/.
          Once available, read it to understand hephaestus mechanical findings,
          then perform semantic validation (agents/*.md, skills/*.md, docs/shared/*).
          You may SendMessage(to: 'hephaestus') to query additional mechanical evidence.
          Report audit-semantic.json to leader via SendMessage.
          STAY AVAILABLE.")
  olympus_register_agent_spawn(pipeline_id, "athena")

SendMessage(to: "athena", summary: "의미적 검증",
  "DO NOT write files — you are read-only.
   SEQUENTIAL DEPENDENCY: hephaestus has completed mechanical validation.
   Step 1 — Read ${ARTIFACT_DIR}/audit-mechanical.json (hephaestus results).
             Note all mechanical findings — use them as context for semantic checks.
             If you need clarification on any mechanical finding, SendMessage(to: 'hephaestus').
   Step 2 — Read agents/*.md, skills/*.md, docs/shared/*.
   Step 3 — Validate (referencing audit-mechanical.json findings where relevant):
   2-1. Permission-Role Consistency: disallowedTools vs prompt content
   2-2. Artifact Contract Completeness: skill files vs contracts
   2-3. Gate Consistency: gate-thresholds.json vs SKILL.md values
   2-4. Clarity Scan: banned phrases from clarity-enforcement.md
   2-5. Delegation Pattern: Write/Edit disabled agents have SendMessage + handoff
   2-6. Pipeline State Schema: state structures match pipeline-states.json
   Include reference to hephaestus findings in your report where applicable.
   Report audit-semantic.json to leader.")

WAIT → leader writes audit-semantic.json
olympus_record_execution(pipeline_id, "audit", "athena", ...)
```

---

## Step 4: Audit Report

```
Leader synthesizes both results:

# Olympus Audit Report

## Summary
- Mechanical: {PASS/FAIL}
- Semantic: {CLEAN/WARNING/VIOLATION}
- **Overall: {CLEAN/WARNING/VIOLATION}**

## Violations (immediate fix required)
| # | Category | Target | Issue | Location |

## Warnings (manual review recommended)
| # | Category | Target | Issue | Location |

## Coverage
- Agents: {n}/{total}, Skills: {n}/{total}
- Schemas validated: agent-schema.json, pipeline-states.json, gate-thresholds.json

Save to ${ARTIFACT_DIR}/audit-report.md

Verdict: CLEAN / WARNING / VIOLATION
```

---

## Step 5: Teardown

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
  - Agent (name + team_name): spawn hephaestus, athena
  - SendMessage: sequential (athena reads hephaestus results)
  - TeamDelete: Step 5
</Tool_Usage>

<Artifact_Contracts>
  | File | Step | Writer | Readers |
  |------|------|--------|---------|
  | audit-mechanical.json | 2 | Leader (from hephaestus) | athena |
  | audit-semantic.json | 3 | Leader (from athena) | Leader |
  | audit-report.md | 4 | Leader | User |
</Artifact_Contracts>
