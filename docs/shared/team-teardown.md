# Team Teardown Protocol

## Overview

At the end of a skill execution, the orchestrator calls `TeamDelete` to remove the team configuration and release team resources. This is the standard teardown pattern used by all Olympus skills.

## Standard Teardown (All Skills)

```
# Step N: Teardown
TeamDelete(team_name: "${TEAM}")
```

**Rules:**
- Call `TeamDelete` after all agents have reported results and all artifacts have been written.
- If called from inside Odyssey, skip `TeamDelete` — Odyssey manages the team lifecycle.
- Skills that do not create teams (e.g., hestia, setup) skip this step.

## When to Teardown

| Condition | Action |
|-----------|--------|
| Skill completes successfully | Call `TeamDelete` |
| User cancels mid-execution | Call `TeamDelete` if team was created |
| Gate failure → terminal state | Call `TeamDelete` before returning |
| Called from Odyssey sub-skill | Do NOT call `TeamDelete` (Odyssey owns the team) |
| No team was created (hestia, setup) | Skip |

## Olympus Sub-skill Pattern

When Odyssey invokes a sub-skill (oracle, genesis, pantheon, etc.), agents are spawned into the **Odyssey team** — not a separate sub-skill team. The sub-skill does not create or delete its own team:

```
# Oracle called standalone
TeamCreate(team_name: "oracle-${CLAUDE_SESSION_ID}")
...
TeamDelete(team_name: "oracle-${CLAUDE_SESSION_ID}")  # Step 8

# Oracle called from Odyssey
# NO TeamCreate, NO TeamDelete — use existing Odyssey team
Agent(name: "hermes", team_name: "odyssey-${CLAUDE_SESSION_ID}", ...)
```

## Error Handling

If `TeamDelete` fails:
1. Log the error.
2. Retry once.
3. If still failing, report the error to the user but proceed — cleanup failure does not invalidate skill results.

---

**CC Source Lineage**: Ported from `query.ts` sub-agent lifecycle management. TeamDelete maps to the cleanup phase of Claude Code's team-based agent execution model.
