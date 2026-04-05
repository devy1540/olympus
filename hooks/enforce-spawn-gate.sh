#!/usr/bin/env bash
# enforce-spawn-gate.sh — Spawn gate enforcement
# Runs as a PreToolUse(Write|Edit) hook
# stdin: JSON { tool_input: { file_path, content } }
#
# DERIVATION: Extends enforce-permissions.sh pattern to enforce §0 of
# orchestrator-protocol.md: agents listed in artifact-contracts.json
# "required_spawn" must be registered via olympus_register_agent_spawn
# BEFORE the orchestrator writes that artifact. Prevents orchestrator
# from bypassing agent spawns entirely.
#
# WHAT IT DOES:
#   When an artifact is written to .olympus/, looks up "required_spawn"
#   in artifact-contracts.json. If set, queries olympus-mcp to verify
#   each required agent was spawned for this pipeline. If any are missing,
#   emits deny: "SPAWN REQUIRED: {agent} must be spawned before writing
#   {artifact}. Violates §0."

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"

# --- Denial tracking (ported from denialTracking.ts lines 1-46) ---
source "${SCRIPT_DIR}/lib/denial-tracking.sh"

# --- Hook response helpers (ported from PermissionDecision type) ---
emit_deny() {
  local message="$1"
  local reason_type="${2:-rule}"
  local reason_detail="${3:-}"

  denial_tracking_record_denial > /dev/null 2>&1

  local should_escalate
  should_escalate=$(denial_tracking_should_escalate)

  if [[ "$should_escalate" == "true" ]]; then
    local state
    state=$(denial_tracking_get_state)
    local consecutive total
    consecutive=$(echo "$state" | jq -r '.consecutiveDenials')
    total=$(echo "$state" | jq -r '.totalDenials')

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

if [[ ! -f "$CONTRACTS_FILE" ]]; then
  echo '{ "behavior": "allow" }'
  exit 0
fi

# --- Extract pipeline_id and skill from .olympus/{skill}-{date}-{uuid}/ path ---
# pipeline_id is the full subdir name (e.g., "odyssey-20260405-abc123")
OLYMPUS_SUBDIR=$(echo "$FILE_PATH" | sed -n 's|.*\.olympus/\([^/]*\)/.*|\1|p' || true)
if [[ -z "$OLYMPUS_SUBDIR" ]]; then
  echo '{ "behavior": "allow" }'
  exit 0
fi

PIPELINE_ID="$OLYMPUS_SUBDIR"
SKILL_NAME=$(echo "$OLYMPUS_SUBDIR" | sed -E 's/^([a-z-]+)-.*/\1/')

# --- Look up required_spawn from artifact-contracts.json ---
REQUIRED_SPAWN_RAW=$(jq -r --arg skill "$SKILL_NAME" --arg file "$FILENAME" \
  '.[$skill][$file].required_spawn // empty' "$CONTRACTS_FILE" 2>/dev/null || true)

# Handle gen-{n}/ pattern (Genesis skill)
if [[ -z "$REQUIRED_SPAWN_RAW" ]]; then
  PARENT_DIR=$(basename "$(dirname "$FILE_PATH")")
  if [[ "$PARENT_DIR" =~ ^gen-[0-9]+$ ]]; then
    GEN_FILENAME="gen-{n}/${FILENAME}"
    REQUIRED_SPAWN_RAW=$(jq -r --arg skill "$SKILL_NAME" --arg file "$GEN_FILENAME" \
      '.[$skill][$file].required_spawn // empty' "$CONTRACTS_FILE" 2>/dev/null || true)
  fi
fi

if [[ -z "$REQUIRED_SPAWN_RAW" || "$REQUIRED_SPAWN_RAW" == "null" ]]; then
  # No spawn requirement — allow
  echo '{ "behavior": "allow" }'
  exit 0
fi

# --- Find olympus-mcp binary ---
MCP_BIN="${PLUGIN_ROOT}/bin/olympus-mcp"
if [[ ! -x "$MCP_BIN" ]]; then
  if command -v olympus-mcp &>/dev/null; then
    MCP_BIN="olympus-mcp"
  else
    # Binary not available — fail open with warning rather than blocking all writes
    echo "[enforce-spawn-gate] WARNING: olympus-mcp binary not found at ${MCP_BIN}, skipping spawn check for ${FILENAME}" >&2
    echo '{ "behavior": "allow" }'
    exit 0
  fi
fi

# --- Normalize required_spawn: string or array → newline-separated agent names ---
REQUIRED_AGENTS=$(echo "$REQUIRED_SPAWN_RAW" | \
  jq -r 'if type == "array" then .[] else . end' 2>/dev/null || echo "$REQUIRED_SPAWN_RAW")

# --- Check each required agent was spawned ---
MISSING_AGENTS=()
while IFS= read -r agent; do
  [[ -z "$agent" ]] && continue
  RESULT=$("$MCP_BIN" query is-spawned "$PIPELINE_ID" "$agent" 2>/dev/null || echo '{"spawned":false}')
  SPAWNED=$(echo "$RESULT" | jq -r '.spawned // false' 2>/dev/null || echo "false")
  if [[ "$SPAWNED" != "true" ]]; then
    MISSING_AGENTS+=("$agent")
  fi
done <<< "$REQUIRED_AGENTS"

if [[ ${#MISSING_AGENTS[@]} -eq 0 ]]; then
  emit_allow
  exit 0
fi

MISSING_LIST=$(IFS=', '; echo "${MISSING_AGENTS[*]}")
emit_deny \
  "SPAWN REQUIRED: [${MISSING_LIST}] must be spawned before writing '${FILENAME}'. Violates §0 of orchestrator-protocol.md. Call olympus_register_agent_spawn for each agent first." \
  "rule" \
  "required_spawn:[${MISSING_LIST}] for artifact ${FILENAME} in pipeline ${PIPELINE_ID}"
