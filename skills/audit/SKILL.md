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
- RESULT CAPTURE RULE: Read-only agents deliver results via SendMessage(to: "team-lead").
  Orchestrator writes artifacts from these results. Write-capable agents write files directly.
- SEQUENTIAL SPAWN: hephaestus first → athena after hephaestus completes.
  Wait for prerequisite agent results before spawning dependent agents.
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
heph_result = Agent(name: "hephaestus", team_name: ${TEAM},
      subagent_type: "olympus:hephaestus",
      prompt: "You are Hephaestus, mechanical validator. Artifact directory: ${ARTIFACT_DIR}/
        LEADER_NAME: team-lead
        IMMEDIATE TASK: Validate Olympus plugin structural integrity:
        1-1. YAML Frontmatter: validate agents/*.md against agent-schema.json
        1-2. File existence: verify cross-references between agents and skills
        1-3. Shared doc references: verify docs/shared/ references exist
        1-4. artifact-contracts.json: verify writer/reader agents exist
        1-5. Hook scripts: verify hooks.json scripts exist, are executable, pass bash -n
        Output audit-mechanical.json content as your final response.")
olympus_register_agent_spawn(pipeline_id, "hephaestus")

→ Write audit-mechanical.json from heph_result
olympus_record_execution(pipeline_id, "audit", "hephaestus", ...)

Decision:
  All PASS → proceed to Step 3
  Any FAIL → note failures, proceed to Step 3 (audit reports findings, does not block)
  ENV_UNAVAILABLE → proceed to Step 3 with caveat (audit-mechanical.json notes environment unavailable)
```

---

## Step 3: Athena Semantic Validation

```
athena_result = Agent(name: "athena", team_name: ${TEAM},
      subagent_type: "olympus:athena",
      prompt: "You are Athena, semantic validator. Artifact directory: ${ARTIFACT_DIR}/
        LEADER_NAME: team-lead
        DO NOT write files — you are read-only.
        IMMEDIATE TASK: Perform semantic validation of Olympus plugin.
        Step 1 — Read ${ARTIFACT_DIR}/audit-mechanical.json (hephaestus results).
        Step 2 — Read agents/*.md, skills/*.md, docs/shared/*.
        Step 3 — Validate:
        2-1. Permission-Role Consistency: disallowedTools vs prompt content
        2-2. Artifact Contract Completeness: skill files vs contracts
        2-3. Gate Consistency: gate-thresholds.json vs SKILL.md values
        2-4. Clarity Scan: banned phrases from clarity-enforcement.md
        2-5. Delegation Pattern: Write/Edit disabled agents use final text output for results
        2-6. Pipeline State Schema: state structures match pipeline-states.json
        2-7. LEADER_NAME Consistency: every agent spawn prompt in SKILL.md files contains
             "LEADER_NAME: team-lead" (literal). Missing LEADER_NAME is a configuration violation.
        MANDATORY CONSULTATION: Before outputting final results, you MUST:
          SendMessage(to: 'hephaestus') with at least one cross-check question.
          Wait for response. Include consultation exchange in your output.
        Output audit-semantic.json content as your final response.")
olympus_register_agent_spawn(pipeline_id, "athena")

→ Write audit-semantic.json from athena_result
olympus_record_execution(pipeline_id, "audit", "athena", ...)
olympus_log_collaboration(pipeline_id, "athena", "hephaestus", "의미 검증: athena↔hephaestus 크로스검증")

DEADLOCK FALLBACK: If athena does not send a cross-check question to hephaestus within 3 minutes:
  → SendMessage(to: "athena", "Cross-check consultation timeout. Finalize audit-semantic.json using audit-mechanical.json findings only. Note 'hephaestus consultation pending'.")
  → Leader flags incomplete cross-verification in audit-report.md.
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
  - olympus_log_collaboration: Step 3 athena↔hephaestus consultation (SHOULD)

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
