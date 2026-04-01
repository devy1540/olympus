# Olympus v1.0.0 — Claude Code Production Architecture Port

## Overview

Olympus v1.0.0 is a ground-up rebuild of the harness infrastructure, using Anthropic's Claude Code production source (`@anthropic-ai/claude-code`, restored from npm source maps) as the architectural reference. The plugin's design philosophy (14 agents, 4 mathematical gates, adversarial collaboration) is unchanged — what changed is the **enforcement layer** beneath it.

**Key metric:** ~685 lines of Claude Code production source directly referenced across 6 core modules.

---

## What Changed

### Hook System: 3 → 8 scripts + 1 library

| Hook | Event | Source | Purpose |
|------|-------|--------|---------|
| `enforce-permissions.sh` | PreToolUse(Write) | `permissions.ts:287-530` | Block read-only agents from direct Write |
| `verify-artifacts.sh` | PreToolUse(Write) | `Tool.ts validateInput()` | Verify predecessor artifacts exist |
| `validate-agents.sh` | PostToolUse(Write) | `Tool.ts buildTool()` | Validate agent frontmatter against schema |
| `validate-gate.sh` | PostToolUse(Write) | `permissions.ts PermissionDecision` | Gate threshold + evidence cross-validation |
| `validate-state.sh` | PostToolUse(Write) | `query.ts Terminal/Continue` | Pipeline state machine enforcement |
| `checkpoint.sh` | PostToolUse(Write) | — | Auto-backup state files |
| `compact-context.sh` | PostToolUse(Write) | `autoCompact.ts` | Auto-inject compaction on phase transition |
| `lib/denial-tracking.sh` | (library) | `denialTracking.ts:1-46` | **1:1 port** of denial state management |

All hooks now return structured JSON responses matching the `PermissionDecision` type (ported from `src/types/permissions.ts:174-324`).

### Schemas: 2 → 5 (all runtime-enforced)

| Schema | Source | Enforced By |
|--------|--------|-------------|
| `hook-responses.json` | `PermissionDecision` (allow/deny/ask) + `PermissionDecisionReason` (11 types) | All hooks |
| `pipeline-states.json` | `query.ts State` (line 204), `Terminal` (10 reasons), `Continue` (8 reasons) | `validate-state.sh` |
| `agent-schema.json` | `TOOL_DEFAULTS` (line 757), `buildTool()` (line 783), `getDenyRuleForTool()` (line 287) | `validate-agents.sh` |
| `gate-thresholds.json` | (existing) | `validate-gate.sh` + `validate-state.sh` |
| `artifact-contracts.json` | (existing) | `verify-artifacts.sh` + `enforce-permissions.sh` |

### Protocols: 9 → 13

| New Protocol | Source | Purpose |
|-------------|--------|---------|
| `orchestrator-protocol.md` | `query.ts` loop + error recovery | Orchestrator decision logic, gate failure recovery, escalation paths |
| `context-management.md` | `autoCompact.ts:71-239` | Token budget thresholds (13k/20k/3k), 4 compaction strategies, per-skill compaction points |
| `agent-context.md` | `forkedAgent.ts:344-461` | Worker isolation rules (Cloned/Inherited/Fresh/No-op), communication boundaries, depth tracking |
| `worker-preamble.md` (updated) | `contentReplacementState` | Artifact Reference Protocol: Read don't Receive, path references, targeted reading |

### Skills: 8/8 English + protocol-connected

All skills rewritten in English and connected to new infrastructure:
- **odyssey** references `pipeline-states.json`, `validate-state.sh`, `compact-context.sh`, `orchestrator-protocol.md`
- **audit** integrates `agent-schema.json` validation + hook script verification
- All skills use Artifact Reference Protocol (agents Read artifacts by path, no full-content injection)

### Agents: 14/14 enhanced

- `<Context_Protocol>` section added (Artifact Reference Protocol awareness)
- `isReadOnly` / `isConcurrencySafe` frontmatter fields (from `TOOL_DEFAULTS`)
- `maxTurns` field (from `BaseAgentDefinition`) — prevents runaway agents
- Hardcoded thresholds → `gate-thresholds.json` dynamic references (Apollo, Athena)
- **Hermes** ← CC Explore Agent: "Strictly PROHIBITED from creating/modifying/deleting files"
- **Athena** ← CC Verification Agent: "Your job is to BREAK implementations, not confirm they work"
- **Zeus** ← CC Plan Agent: "Critical Files for Implementation" output section

### Tests: 0 → 52

- `test-hooks.sh`: 30 unit tests (7 hooks × 3-7 cases each + denial tracking)
- `test-integration.sh`: 22 integration tests (Oracle pipeline, Tribunal pipeline, Odyssey state machine, 14-agent batch validation)
- All 52 tests passing on macOS

---

## Claude Code Source Reference Map

| Olympus Result | CC Source File:Lines | Port Type |
|---|---|---|
| `hook-responses.json` | `permissions.ts:174-324` | Type → JSON Schema |
| `pipeline-states.json` | `query.ts:204-217` | Type → JSON Schema |
| `agent-schema.json` | `Tool.ts:757-792` | Factory → Schema |
| `lib/denial-tracking.sh` | `denialTracking.ts:1-46` | **1:1 function port** |
| `enforce-permissions.sh` | `permissions.ts:287-530` | Logic adaptation |
| `validate-gate.sh` | `permissions.ts:174-236` | Response format port |
| `validate-state.sh` | `query.ts:204-217` | Enum enforcement |
| `compact-context.sh` | `autoCompact.ts:71-239` | Trigger logic port |
| `context-management.md` | `autoCompact.ts` thresholds | Strategy documentation |
| `agent-context.md` | `forkedAgent.ts:344-461` | Isolation pattern |
| `orchestrator-protocol.md` | `query.ts` loop + recovery | Decision logic |
| Hermes constraints | `exploreAgent.ts` | Prompt porting |
| Athena mindset | `verificationAgent.ts` | Prompt porting |
| Zeus output | `planAgent.ts` | Output format |
| 14× `maxTurns` | `BaseAgentDefinition` | Field porting |

**Total:** ~685 lines directly referenced from ~1,100 lines of harness-relevant CC source (62%).

---

## Commits

```
682a904  P0: artifact verification, gate cross-validation, token efficiency
941abcb  P1: PermissionDecision, Terminal/Continue, buildTool type porting
63bff53  P1: denial tracking, auto-compact, agent context logic porting
df3b3be  P2: validate-state/validate-agents/compact-context runtime enforcement
2323c49  P2: macOS compatibility + 30/30 unit tests
86df5ff  P2: 52/52 integration tests (Oracle→Tribunal pipeline simulation)
b378b75  Remaining 4 skills English + protocol connection
553a1d5  v1.0.0: version reset
7f8845d  CC agent patterns: Explore→Hermes, Verification→Athena, Plan→Zeus
ad2a945  14 agents: Context_Protocol, CC frontmatter, dynamic thresholds
```

---

## What's NOT included (and why)

| CC Module | Why Not Ported |
|-----------|---------------|
| React/Ink UI | CLI rendering — plugin doesn't own the UI |
| OAuth/Analytics | Authentication/telemetry — handled by host CLI |
| MCP server management | External integrations — handled by host CLI |
| Streaming API client | HTTP transport — handled by host CLI |
| Coordinator mode (full) | 80% already implemented; remaining 20% (tool restriction) not possible at plugin level |
| Async hook registry | Synchronous hooks sufficient for current needs |
| Transcript classifier | AI-based permissions — overkill for current scale |
