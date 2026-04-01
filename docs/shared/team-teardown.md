# Team Teardown Protocol

## Overview

This protocol defines the graceful shutdown procedure for team members at the end of a skill execution. It ensures all agents complete their work, report final status, and resources are cleaned up properly.

## Step 1: Enumerate Active Members

**Objective:** Identify all currently active team members.

**Actions:**
1. Read the team configuration to get the list of registered members.
2. Filter for members with `active` status.
3. Create a shutdown tracking list with each member's ID and status set to `pending`.

## Step 2: Send Shutdown Requests

**Objective:** Notify all active members that shutdown is imminent.

**Actions:**
1. For each active member, call `SendMessage` with:
   - `type`: `"shutdown_request"`
   - `content`: Reason for shutdown (e.g., "Skill execution complete", "User cancelled")
2. Record the timestamp of each request sent.

## Step 3: Await Responses

**Objective:** Collect shutdown acknowledgments from all members.

**Actions:**
1. Wait for `shutdown_response` messages from each member.
2. For each response received:
   - If `acknowledged`: Mark the member as `shutdown_confirmed` in the tracking list.
   - If `rejected` (member has pending work): Log the rejection reason and retry after a brief delay.
3. Handle timeouts:
   - **First timeout (30s):** Resend the shutdown request.
   - **Second timeout (30s):** Log a forced shutdown warning and proceed.

**Timeout handling matrix:**

| Attempt | Timeout | Action                                    |
|---------|---------|-------------------------------------------|
| 1       | 30s     | Resend shutdown_request                    |
| 2       | 30s     | Log forced shutdown, mark as force_closed  |

## Step 4: Cleanup

**Objective:** Remove team resources and verify cleanup.

**Actions:**
1. Call `TeamDelete` to remove the team configuration.
2. Verify cleanup:
   - Confirm no orphaned message channels remain.
   - Confirm no tasks are left in `in_progress` status.
3. Log the teardown summary:
   - Number of members gracefully shut down
   - Number of members force-closed
   - Any errors encountered

## Error Handling

### Retry Cycles

- Maximum **2 retry cycles** for unresponsive members.
- Each retry cycle includes sending a new `shutdown_request` and waiting for the timeout period.

### Force Logging

When a member is force-closed (did not respond after all retries):
1. Log the member's ID and last known status.
2. Log any tasks that were `in_progress` for that member.
3. Mark those tasks as `abandoned` with a note explaining the forced shutdown.
4. Include the force-close event in the teardown summary.

### Partial Failure

If `TeamDelete` fails:
1. Log the failure with error details.
2. Retry once after a 5-second delay.
3. If still failing, log a critical error and notify the orchestrator.
4. The skill should still report its results even if cleanup fails.

## Teardown Summary Format

```json
{
  "team_id": "team-xyz",
  "teardown_started": "2025-01-15T10:30:00Z",
  "teardown_completed": "2025-01-15T10:30:45Z",
  "members": {
    "graceful": ["agent-1", "agent-2"],
    "force_closed": ["agent-3"],
    "errors": []
  },
  "cleanup": {
    "team_deleted": true,
    "orphaned_channels": 0,
    "abandoned_tasks": 1
  }
}
```
