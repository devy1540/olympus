#!/usr/bin/env bash
# enforce-permissions.sh — Runtime permission enforcement
# Runs as a PreToolUse(Write) hook
# stdin: JSON { tool_input: { file_path, content } }
#
# DERIVATION: Ported from Claude Code's permission enforcement chain:
#   1. Tool.checkPermissions() → src/Tool.ts:500-503
#   2. getDenyRuleForTool()    → src/utils/permissions/permissions.ts:287-292
#   3. hasPermissionsToUseTool  → src/utils/permissions/permissions.ts:473-530
#
# WHAT IT DOES:
#   When an artifact is written to .olympus/, looks up the expected writer
#   in artifact-contracts.json. If the writer agent has Write in its
#   disallowedTools (from agent-schema.json registry), emits a deny decision.
#   This prevents read-only agents from writing files directly.

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"

# --- Denial tracking (ported from denialTracking.ts lines 1-46) ---
# Source the library; set state dir to artifact dir or fallback
source "${SCRIPT_DIR}/lib/denial-tracking.sh"

# --- Hook response helpers (ported from PermissionDecision type) ---
emit_deny() {
  local message="$1"
  local reason_type="${2:-rule}"
  local reason_detail="${3:-}"

  # Record denial (ported from permissions.ts line 963: persistDenialState)
  denial_tracking_record_denial > /dev/null 2>&1

  # Check if we should escalate (ported from shouldFallbackToPrompting)
  local should_escalate
  should_escalate=$(denial_tracking_should_escalate)

  if [[ "$should_escalate" == "true" ]]; then
    local state
    state=$(denial_tracking_get_state)
    local consecutive total
    consecutive=$(echo "$state" | jq -r '.consecutiveDenials')
    total=$(echo "$state" | jq -r '.totalDenials')

    # Escalate: change deny → ask (ported from hasPermissionsToUseTool line 520+)
    jq -n \
      --arg msg "ESCALATION: ${consecutive} consecutive denials (${total} total). ${message}" \
      --arg rt "$reason_type" \
      --arg rd "$reason_detail" \
      '{ behavior: "ask", message: $msg, decisionReason: { type: $rt, reason: $rd } }'
  else
    jq -n \
      --arg msg "$message" \
      --arg rt "$reason_type" \
      --arg rd "$reason_detail" \
      '{ behavior: "deny", message: $msg, decisionReason: { type: $rt, reason: $rd } }'
  fi
}

emit_allow() {
  # Record success (ported from permissions.ts line 486: recordSuccess on allow)
  denial_tracking_record_success > /dev/null 2>&1
  echo '{ "behavior": "allow" }'
}

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  echo '{ "behavior": "allow" }'
  exit 0
fi

# Only check files inside .olympus/ directories
if [[ "$FILE_PATH" != *"/.olympus/"* ]]; then
  echo '{ "behavior": "allow" }'
  exit 0
fi

FILENAME=$(basename "$FILE_PATH")
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
CONTRACTS_FILE="${PLUGIN_ROOT}/docs/shared/artifact-contracts.json"
SCHEMA_FILE="${PLUGIN_ROOT}/docs/shared/agent-schema.json"

if [[ ! -f "$CONTRACTS_FILE" || ! -f "$SCHEMA_FILE" ]]; then
  echo '{ "behavior": "allow" }'
  exit 0
fi

# --- Extract skill name from path ---
# .olympus/{skill}-{date}-{uuid}/ pattern
OLYMPUS_SUBDIR=$(echo "$FILE_PATH" | sed -n 's|.*\.olympus/\([^/]*\)/.*|\1|p' || true)
if [[ -z "$OLYMPUS_SUBDIR" ]]; then
  echo '{ "behavior": "allow" }'
  exit 0
fi
SKILL_NAME=$(echo "$OLYMPUS_SUBDIR" | sed -E 's/^([a-z-]+)-.*/\1/')

# --- Look up expected writer from artifact-contracts.json ---
# Mirrors getDenyRuleForTool(): find the rule that matches this tool+input
WRITER=$(jq -r --arg skill "$SKILL_NAME" --arg file "$FILENAME" \
  '.[$skill][$file].writer // empty' "$CONTRACTS_FILE" 2>/dev/null || true)

# Handle gen-{n}/ pattern
if [[ -z "$WRITER" ]]; then
  PARENT_DIR=$(basename "$(dirname "$FILE_PATH")")
  if [[ "$PARENT_DIR" =~ ^gen-[0-9]+$ ]]; then
    GEN_FILENAME="gen-{n}/${FILENAME}"
    WRITER=$(jq -r --arg skill "$SKILL_NAME" --arg file "$GEN_FILENAME" \
      '.[$skill][$file].writer // empty' "$CONTRACTS_FILE" 2>/dev/null || true)
  fi
fi

if [[ -z "$WRITER" ]]; then
  # Not in contracts — allow (unknown files are not enforced)
  echo '{ "behavior": "allow" }'
  exit 0
fi

# --- Check if writer has Write permission ---
# Mirrors hasPermissionsToUseTool → getDenyRuleForTool chain
# "orchestrator" always has write permission (it's the host)
if [[ "$WRITER" == "orchestrator" ]]; then
  echo '{ "behavior": "allow" }'
  exit 0
fi

# Look up writer's permission level from agent-schema.json registry
PERMISSION_LEVEL=$(jq -r --arg agent "$WRITER" \
  '.agentRegistry.agents[$agent].permissionLevel // empty' "$SCHEMA_FILE" 2>/dev/null || true)

if [[ -z "$PERMISSION_LEVEL" ]]; then
  # Agent not in registry — allow (unregistered agents are not enforced)
  echo '{ "behavior": "allow" }'
  exit 0
fi

# Check: read-only agents should not be writing directly
# This mirrors the deny rule matching in getDenyRuleForTool
if [[ "$PERMISSION_LEVEL" == "read-only" ]]; then
  # Check if contract explicitly allows this via writerRequires
  WRITER_REQUIRES=$(jq -r --arg skill "$SKILL_NAME" --arg file "$FILENAME" \
    '.[$skill][$file].writerRequires // empty' "$CONTRACTS_FILE" 2>/dev/null || true)

  if [[ -z "$WRITER_REQUIRES" || "$WRITER_REQUIRES" == "null" ]]; then
    # No writerRequires and agent is read-only: this artifact should be
    # written by the orchestrator on behalf of the agent (via SendMessage)
    emit_deny \
      "PERMISSION DENIED: Agent '${WRITER}' (permission: read-only) cannot write '${FILENAME}' directly. Per artifact-contracts.json, this agent should send results via SendMessage and the orchestrator writes on their behalf. See orchestrator-protocol.md section 1.1." \
      "rule" "disallowedTools:Write for agent ${WRITER}"
    exit 0
  fi
fi

echo '{ "behavior": "allow" }'
exit 0
