# Agent Context Isolation Protocol

## Source

Direct port of Claude Code's subagent context creation:
- `src/utils/forkedAgent.ts` → `createSubagentContext()` (lines 344-461)
- Defines what gets inherited, cloned, created fresh, or no-op'd when spawning a worker agent.

## Overview

When the orchestrator spawns a worker agent (via Team/Task), the agent operates in an isolated context. This protocol defines the isolation boundaries, ported from Claude Code's `createSubagentContext()` pattern.

---

## 1. Context Isolation Rules

### Ported from `createSubagentContext()` (forkedAgent.ts:344-461):

| Category | Claude Code Behavior | Olympus Adaptation |
|----------|---------------------|-------------------|
| **Cloned (isolated)** | `readFileState`, `contentReplacementState`, all `Set<>` triggers | Each worker gets its own artifact working set. Writes to `.olympus/{id}/` are isolated per skill run. |
| **Inherited (shared)** | `options`, `messages`, `fileReadingLimits`, `userModified` | Workers inherit: artifact directory path, spec.md location, skill configuration. |
| **Fresh (new)** | `agentId` (new), `queryTracking.chainId` (new UUID), `queryTracking.depth` (parent+1) | Each worker gets a unique task ID. Nesting depth is tracked for debugging. |
| **No-op (disabled)** | `setAppState`, `setInProgressToolUseIDs`, UI callbacks | Workers cannot modify orchestrator state directly. They communicate only via SendMessage. |
| **Always shared** | `setAppStateForTasks` (task cleanup), `updateAttributionState` | Workers share the task system (can create/update tasks) and the artifact directory. |

### Key Design Decision from Claude Code:

```typescript
// Ported from forkedAgent.ts:395-404
// By default, subagents CANNOT show permission prompts.
// They get shouldAvoidPermissionPrompts: true
// UNLESS shareAbortController is true (interactive agent)
getAppState: () => ({
  ...parentContext.getAppState(),
  toolPermissionContext: {
    ...state.toolPermissionContext,
    shouldAvoidPermissionPrompts: true,  // ← key isolation
  },
})
```

**Olympus equivalent:** Worker agents should never prompt the user directly for permission. All user interaction goes through the orchestrator. Workers that need user input must send a BLOCKING_QUESTION via SendMessage, and the orchestrator asks the user via AskUserQuestion.

---

## 2. What Workers Receive

When the orchestrator spawns a worker agent, the task prompt must include:

### Required Context (inherited)
```
1. Artifact directory path: .olympus/{id}/
2. Task description and mission
3. worker-preamble.md reference (includes Artifact Reference Protocol)
4. Relevant artifact filenames to Read
```

### Forbidden Context (isolated — do NOT inject)
```
1. Full artifact content (worker must Read it)
2. Other workers' results (worker must Read analyst-findings.md etc.)
3. Orchestrator state (odyssey-state.json internals)
4. Prior conversation history from other phases
```

### Implicit Defaults (fresh)
```
1. Empty working memory (no prior findings from other workers)
2. Fresh denial tracking state (0 consecutive, 0 total)
3. No knowledge of other workers' existence or progress
```

---

## 3. Communication Boundaries

Ported from Claude Code's pattern where subagents use `SendMessage` as their only output channel:

```
┌──────────────────────────────────────────────────────────┐
│ Orchestrator Context                                      │
│                                                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │ Worker A     │  │ Worker B     │  │ Worker C     │      │
│  │ (isolated)   │  │ (isolated)   │  │ (isolated)   │      │
│  │              │  │              │  │              │      │
│  │ Can Read:    │  │ Can Read:    │  │ Can Read:    │      │
│  │  spec.md     │  │  spec.md     │  │  spec.md     │      │
│  │  context.md  │  │  context.md  │  │  context.md  │      │
│  │              │  │              │  │              │      │
│  │ Output:      │  │ Output:      │  │ Output:      │      │
│  │  SendMessage │  │  SendMessage │  │  SendMessage │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│         └──────────────────┼──────────────────┘              │
│                            │                                  │
│                   ┌────────▼────────┐                        │
│                   │ Orchestrator     │                        │
│                   │ Aggregates +     │                        │
│                   │ Writes artifacts │                        │
│                   └─────────────────┘                        │
└──────────────────────────────────────────────────────────┘
```

### Rules
1. **Workers cannot see each other's output** — unless the orchestrator explicitly writes aggregated results to a shared artifact and instructs the next worker to Read it.
2. **Workers cannot modify orchestrator state** — no writing to odyssey-state.json, evolve-state.json, etc.
3. **Workers communicate only via SendMessage** — results, errors, and BLOCKING_QUESTIONs all go through this channel.
4. **Workers can Read any artifact in their directory** — but should only Read what's listed in their task.

---

## 4. Denial Tracking per Worker

Ported from `createSubagentContext()` (forkedAgent.ts:438):

```typescript
// Async subagents whose setAppState is a no-op need local denial tracking
localDenialTracking: overrides?.shareSetAppState
  ? parentContext.localDenialTracking
  : createDenialTrackingState(),
```

**Olympus equivalent:** Each worker agent gets a fresh denial tracking state (`{consecutiveDenials: 0, totalDenials: 0}`). If a worker accumulates 3 consecutive denials, the `enforce-permissions.sh` hook escalates to the orchestrator.

This prevents one worker's denial history from affecting another worker's permission decisions.

---

## 5. Depth Tracking

Ported from `createSubagentContext()` (forkedAgent.ts:450):

```typescript
queryTracking: {
  chainId: randomUUID(),
  depth: (parentContext.queryTracking?.depth ?? -1) + 1,
}
```

**Olympus equivalent:** Skills track nesting depth in state files:
- Odyssey (depth 0) spawns Oracle (depth 1) which spawns Hermes (depth 2)
- Maximum recommended depth: 3 (orchestrator → skill → worker)
- Depth > 3 suggests the pipeline should be refactored to reduce nesting
