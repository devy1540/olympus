---
name: audit
description: "Olympus Audit — automated plugin internal consistency validation"
---

# /olympus:audit — Olympus Audit

Automatically validates the internal consistency of the Olympus plugin: agent permissions, cross-references, artifact contracts, gate thresholds, and clarity rules.

**Enhanced with runtime schemas:** This skill now leverages `agent-schema.json` (ported from Claude Code's `buildTool()` pattern) and `pipeline-states.json` (ported from Claude Code's `Terminal`/`Continue` types) for programmatic validation alongside semantic checks.

## Agents (subagent_type bindings)
- **Hephaestus**: Mechanical validation (YAML, file existence, structure) → `subagent_type: "olympus:hephaestus"`
- **Athena**: Semantic validation (permission-role consistency, contract completeness) → `subagent_type: "olympus:athena"`

**⚠ MANDATORY**: Hephaestus and Athena MUST be spawned via Agent tool. The orchestrator only synthesizes the final report (Phase 3). See orchestrator-protocol.md §0.

## Verdict
- CLEAN: all validations pass
- WARNING: non-critical inconsistencies found (manual review recommended)
- VIOLATION: critical consistency breach (fix required)

## Artifact Contracts
| File | Phase | Writer | Readers |
|---|---|---|---|
| `.olympus/{id}/audit-mechanical.json` | 1 | Hephaestus | Athena |
| `.olympus/{id}/audit-semantic.json` | 2 | Athena | Orchestrator |
| `.olympus/{id}/audit-report.md` | 3 | Orchestrator | User |

---

## Execution Flow

```
Phase 1 (Mechanical) → Phase 2 (Semantic) → Phase 3 (Report)
```

### Phase 1: Hephaestus Mechanical Validation

Spawn Hephaestus as a Task to check structural integrity.

```
Input: plugin root path
Checks:

1-1. YAML Frontmatter validity
  - Validate against agent-schema.json required fields: name, description, model, disallowedTools
  - Validate model enum: opus | sonnet | haiku
  - Validate name pattern: ^[a-z]+$
  - Validate disallowedTools items: Write | Edit | Bash | NotebookEdit
  - Validate skills/*/SKILL.md frontmatter: name, description
  Note: validate-agents.sh hook performs this check at write time;
        audit performs it as a batch sweep.

1-2. File existence verification
  - Extract "Hand off to:" or "→ {AgentName}" patterns from agents/*.md
  - Verify referenced agent names exist in agents/ directory
  - Extract agent names from skills/*/SKILL.md "## Agents" sections
  - Verify referenced agents exist in agents/ directory

1-3. Shared document references
  - Extract docs/shared/ file references from agents/*.md and skills/*.md
  - Verify referenced documents exist in docs/shared/

1-4. artifact-contracts.json cross-check
  - Verify all writer agents in artifact-contracts.json exist
  - Verify all reader agents in artifact-contracts.json exist
  - Cross-check with agent-schema.json agentRegistry

1-5. Hook script validation
  - Verify all scripts referenced in hooks.json exist and are executable
  - Syntax check: bash -n on each script

Output: audit-mechanical.json
{
  "yaml_validity": { "pass": [], "fail": [] },
  "cross_references": { "valid": [], "broken": [] },
  "doc_references": { "valid": [], "broken": [] },
  "contract_agents": { "valid": [], "missing": [] },
  "hook_scripts": { "valid": [], "broken": [] },
  "overall": "PASS | FAIL"
}
```

### Phase 2: Athena Semantic Validation

Spawn Athena as a Task to check logical consistency.

```
Input: artifact directory path (contains audit-mechanical.json)
Instruction: "Use Read to load audit-mechanical.json, then read agents/*.md, skills/*.md, docs/shared/* for semantic checks"

Checks:

2-1. Permission-Role Consistency
  For each agent:
  a. Parse disallowedTools
  b. Scan prompt body for file-saving expressions:
     - Write/Edit disabled agents: "save", "create", "write file", etc.
     - Exception: "send via SendMessage" context is allowed
  c. Verify Tool_Usage section tools don't conflict with disallowedTools
  d. Cross-check against agent-schema.json agentRegistry.permissionLevel
  On violation: VIOLATION + agent name + conflict location

2-2. Artifact Contract Completeness
  For each skill:
  a. Extract filename patterns from SKILL.md (*.md, *.json)
  b. Cross-reference with artifact-contracts.md (or .json)
  c. Files mentioned in skill but absent from contracts → WARNING
  d. Files in contracts but not mentioned in any skill → INFO (orphan)

2-3. Gate Consistency
  Extract gate thresholds from:
  a. gate-thresholds.json (single source of truth)
  b. oracle/SKILL.md ambiguity gate value
  c. consensus-levels.md Normal/Hell thresholds
  d. pantheon/SKILL.md consensus threshold
  e. tribunal/SKILL.md semantic score threshold
  f. genesis/SKILL.md convergence threshold
  Verify all references to the same gate match gate-thresholds.json values
  On inconsistency: VIOLATION + locations + value differences

2-4. Clarity Scan
  Extract banned phrases from clarity-enforcement.md
  Scan all agent Output_Format and Examples sections for banned phrases
  (Exclude template placeholders {}, intentional bad examples)
  On violation: WARNING + agent name + location + phrase

2-5. Delegation Pattern Consistency
  Extract list of agents with Write/Edit disabled
  For each:
  a. Verify Tool_Usage includes SendMessage
  b. Verify Final_Checklist mentions orchestrator handoff
  On missing: WARNING + agent name

2-6. Pipeline State Schema Compliance
  Verify odyssey/SKILL.md state structure matches pipeline-states.json PipelineState schema
  Verify evolve/SKILL.md state structure matches pipeline-states.json definitions
  On mismatch: WARNING + location + expected vs actual

Output: audit-semantic.json
{
  "permission_role": { "violations": [], "clean": [] },
  "contract_completeness": { "missing": [], "orphans": [] },
  "gate_consistency": { "consistent": [], "inconsistent": [] },
  "clarity_scan": { "violations": [], "clean": [] },
  "delegation_pattern": { "compliant": [], "non_compliant": [] },
  "pipeline_schema": { "compliant": [], "non_compliant": [] },
  "overall": "CLEAN | WARNING | VIOLATION"
}
```

### Phase 3: Audit Report Generation

Orchestrator synthesizes both validation results into the report.

```markdown
# Olympus Audit Report

## Timestamp
{ISO 8601}

## Summary
- Mechanical: {PASS/FAIL}
- Semantic: {CLEAN/WARNING/VIOLATION}
- **Overall: {CLEAN/WARNING/VIOLATION}**

## Violations (immediate fix required)
| # | Category | Target | Issue | Location |
|---|---|---|---|---|
| 1 | {category} | {target} | {issue} | {location} |

## Warnings (manual review recommended)
| # | Category | Target | Issue | Location |
|---|---|---|---|---|
| 1 | {category} | {target} | {issue} | {location} |

## Info
- {notes}

## Coverage
- Agents scanned: {n}/{total}
- Skills scanned: {n}/{total}
- Docs referenced: {n}/{total}
- Contracts verified: {n}/{total}
- Hooks verified: {n}/{total}
- Schemas validated: agent-schema.json, pipeline-states.json, gate-thresholds.json
```

### Team Teardown

Shut down Hephaestus and Athena per the team-teardown.md protocol.

---

## Usage Scenarios

### 1. Post-modification validation
Run `/olympus:audit` after modifying agents or skills to verify consistency.

### 2. Periodic validation
Run after adding new agents or skills to check overall integrity.

### 3. Category-specific validation
Specify a category in the prompt for partial validation:
- "permission check only" → Phase 2-1 only
- "contract check only" → Phase 2-2 only
- "gate check only" → Phase 2-3 only
