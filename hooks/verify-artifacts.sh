#!/usr/bin/env bash
# verify-artifacts.sh — Artifact dependency verification
# Runs as a PreToolUse(Write) hook
# stdin: JSON { tool_input: { file_path, content } }
# Looks up predecessor artifacts from artifact-contracts.json and verifies
# they exist before allowing an output artifact to be written.
# Returns a warning if predecessor artifacts are missing.

set -euo pipefail

# --- Hook response helpers (ported from Claude Code PermissionDecision type) ---
emit_allow_with_context() {
  local context="$1"
  local reason_type="${2:-contract}"
  jq -n \
    --arg ctx "$context" \
    --arg rt "$reason_type" \
    '{ behavior: "allow", additionalContext: $ctx, decisionReason: { type: $rt } }'
}

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only verify files inside .olympus/ directories
if [[ "$FILE_PATH" != *"/.olympus/"* ]]; then
  exit 0
fi

FILENAME=$(basename "$FILE_PATH")
ARTIFACT_DIR=$(dirname "$FILE_PATH")

# Load contracts from plugin root
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
CONTRACTS_FILE="${PLUGIN_ROOT}/docs/shared/artifact-contracts.json"

if [[ ! -f "$CONTRACTS_FILE" ]]; then
  exit 0
fi

# --- Map artifact to skill and look up dependencies ---
# Extract skill name from .olympus/{skill}-{date}-{uuid}/ pattern
OLYMPUS_SUBDIR=$(echo "$FILE_PATH" | sed -n 's|.*\.olympus/\([^/]*\)/.*|\1|p' || true)
if [[ -z "$OLYMPUS_SUBDIR" ]]; then
  exit 0
fi

# Extract skill name: oracle-20260305-a3f8b2c1 → oracle
SKILL_NAME=$(echo "$OLYMPUS_SUBDIR" | sed -E 's/^([a-z]+)-.*/\1/')

# Look up the current file's phase in contracts
CURRENT_PHASE=$(jq -r --arg skill "$SKILL_NAME" --arg file "$FILENAME" \
  '.[$skill][$file].phase // empty' "$CONTRACTS_FILE" 2>/dev/null || true)

# Handle gen-{n}/ pattern: gen-{n}/wonder.md
if [[ -z "$CURRENT_PHASE" ]]; then
  # Try genesis gen-{n} pattern
  PARENT_DIR=$(basename "$(dirname "$FILE_PATH")")
  if [[ "$PARENT_DIR" =~ ^gen-[0-9]+$ ]]; then
    GEN_FILENAME="gen-{n}/${FILENAME}"
    CURRENT_PHASE=$(jq -r --arg skill "$SKILL_NAME" --arg file "$GEN_FILENAME" \
      '.[$skill][$file].phase // empty' "$CONTRACTS_FILE" 2>/dev/null || true)
  fi
fi

if [[ -z "$CURRENT_PHASE" ]]; then
  # File not in contracts — skip verification
  exit 0
fi

# --- Verify predecessor phase artifacts exist ---
# Check that all artifacts from earlier phases are present
MISSING_ARTIFACTS=""

# Get all artifacts with phases lower than the current one
PREDECESSORS=$(jq -r --arg skill "$SKILL_NAME" --arg phase "$CURRENT_PHASE" \
  '.[$skill] // {} | to_entries[]
   | select(.value.phase != "all")
   | select((.value.phase | tonumber) < ($phase | tonumber))
   | .key' "$CONTRACTS_FILE" 2>/dev/null || true)

for PRED_FILE in $PREDECESSORS; do
  # Handle gen-{n} pattern
  if [[ "$PRED_FILE" == gen-\{n\}/* ]]; then
    # For gen-{n} patterns, pass if at least one matching file exists under gen-*/
    PRED_BASENAME=$(echo "$PRED_FILE" | sed 's|gen-{n}/||')
    FOUND=$(find "$ARTIFACT_DIR" -maxdepth 2 -name "$PRED_BASENAME" -path "*/gen-*/*" 2>/dev/null | head -1 || true)
    if [[ -z "$FOUND" ]]; then
      MISSING_ARTIFACTS="${MISSING_ARTIFACTS}  - ${PRED_FILE}\n"
    fi
  else
    # Regular file
    if [[ ! -f "${ARTIFACT_DIR}/${PRED_FILE}" ]]; then
      MISSING_ARTIFACTS="${MISSING_ARTIFACTS}  - ${PRED_FILE}\n"
    fi
  fi
done

if [[ -n "$MISSING_ARTIFACTS" ]]; then
  emit_allow_with_context \
    "ARTIFACT DEPENDENCY WARNING: '${FILENAME}' (phase ${CURRENT_PHASE}) requires predecessor artifacts that do not exist yet: $(echo -e "$MISSING_ARTIFACTS" | tr '\n' ' '). Check artifact-contracts.json pipeline order." \
    "contract"
  exit 0
fi

# --- Agent spawn verification ---
# Check that artifacts with a "source" agent were actually produced by that agent,
# not by the orchestrator directly. This prevents the orchestrator from doing agent work.
#
# Priority: MCP server (authoritative) > odyssey-state.json (fallback)
# If MCP binary exists, query it first. Otherwise fall back to agentTurns check.

ARTIFACT_SOURCE=$(jq -r --arg skill "$SKILL_NAME" --arg file "$FILENAME" \
  '.[$skill][$file].source // empty' "$CONTRACTS_FILE" 2>/dev/null || true)

# Handle gen-{n}/ pattern
if [[ -z "$ARTIFACT_SOURCE" && "$PARENT_DIR" =~ ^gen-[0-9]+$ ]]; then
  GEN_FILENAME="gen-{n}/${FILENAME}"
  ARTIFACT_SOURCE=$(jq -r --arg skill "$SKILL_NAME" --arg file "$GEN_FILENAME" \
    '.[$skill][$file].source // empty' "$CONTRACTS_FILE" 2>/dev/null || true)
fi

# Skip if no source agent defined (orchestrator-owned artifact) or source is an array
if [[ -n "$ARTIFACT_SOURCE" && "$ARTIFACT_SOURCE" != "null" && "$ARTIFACT_SOURCE" != "["* ]]; then
  MCP_BINARY="${PLUGIN_ROOT}/bin/olympus-mcp"
  MCP_CHECKED=false

  # Try MCP server first (authoritative source)
  if [[ -x "$MCP_BINARY" ]]; then
    # Extract pipeline ID from artifact directory name
    PIPELINE_ID=$(echo "$OLYMPUS_SUBDIR" | head -1)
    if [[ -n "$PIPELINE_ID" ]]; then
      MCP_RESULT=$("$MCP_BINARY" query is-spawned "$PIPELINE_ID" "$ARTIFACT_SOURCE" 2>/dev/null || true)
      if [[ -n "$MCP_RESULT" ]]; then
        MCP_CHECKED=true
        MCP_SPAWNED=$(echo "$MCP_RESULT" | jq -r '.spawned // false' 2>/dev/null || echo "false")
        if [[ "$MCP_SPAWNED" == "false" ]]; then
          emit_allow_with_context \
            "AGENT SPAWN WARNING (MCP): '${FILENAME}' should be produced by agent '${ARTIFACT_SOURCE}', but MCP server confirms '${ARTIFACT_SOURCE}' has NOT been spawned for pipeline '${PIPELINE_ID}'. The orchestrator MUST NOT perform agent work directly. See orchestrator-protocol.md §0." \
            "spawn"
          exit 0
        fi
      fi
    fi
  fi

  # Fallback: check odyssey-state.json if MCP was not available
  if [[ "$MCP_CHECKED" == "false" ]]; then
    # Find odyssey-state.json or {skill}-state.json in the artifact directory
    STATE_FILE=""
    for candidate in "${ARTIFACT_DIR}/odyssey-state.json" "${ARTIFACT_DIR}/../odyssey-state.json"; do
      if [[ -f "$candidate" ]]; then
        STATE_FILE="$candidate"
        break
      fi
    done
  fi

  if [[ "$MCP_CHECKED" == "false" && -n "$STATE_FILE" ]]; then
    # Map skill to odyssey phase name
    PHASE_KEY="$SKILL_NAME"

    # Check if the source agent appears in agentTurns for this phase
    AGENT_SPAWNED=$(jq -r --arg phase "$PHASE_KEY" --arg agent "$ARTIFACT_SOURCE" \
      '.phaseTimings[$phase].agentTurns[$agent] // 0' "$STATE_FILE" 2>/dev/null || echo "0")

    if [[ "$AGENT_SPAWNED" == "0" || "$AGENT_SPAWNED" == "null" ]]; then
      emit_allow_with_context \
        "AGENT SPAWN WARNING: '${FILENAME}' should be produced by agent '${ARTIFACT_SOURCE}' (per artifact-contracts.json), but '${ARTIFACT_SOURCE}' has not been spawned in phase '${PHASE_KEY}' (agentTurns shows 0). The orchestrator MUST NOT perform agent work directly — spawn the agent and let it produce this artifact. See orchestrator-protocol.md §0." \
        "spawn"
      exit 0
    fi
  fi
fi

# --- DA evaluation mandatory check ---
# If writing analysis.md (Pantheon output), verify da-evaluation.md exists and is non-empty
if [[ "$FILENAME" == "analysis.md" && "$SKILL_NAME" == "pantheon" ]]; then
  DA_FILE="${ARTIFACT_DIR}/da-evaluation.md"
  if [[ ! -f "$DA_FILE" ]]; then
    emit_allow_with_context \
      "DA MANDATORY WARNING: Writing analysis.md but da-evaluation.md does not exist. Eris (Devil's Advocate) challenge is MANDATORY for Pantheon — do NOT skip to consensus without DA evaluation. Spawn Eris and produce da-evaluation.md first." \
      "da-required"
    exit 0
  fi
  DA_SIZE=$(wc -c < "$DA_FILE" 2>/dev/null || echo "0")
  if [[ "$DA_SIZE" -lt 100 ]]; then
    emit_allow_with_context \
      "DA MANDATORY WARNING: da-evaluation.md exists but is nearly empty (${DA_SIZE} bytes). Eris must produce substantive adversarial evaluation. Re-spawn Eris if the previous attempt failed." \
      "da-required"
    exit 0
  fi
fi

# --- DA evaluation mandatory for verdict.md in tribunal ---
if [[ "$FILENAME" == "verdict.md" && "$SKILL_NAME" == "tribunal" ]]; then
  # Check consensus-record.json exists when Stage 3 should have been triggered
  SEMANTIC_FILE="${ARTIFACT_DIR}/semantic-matrix.md"
  if [[ -f "$SEMANTIC_FILE" ]]; then
    CONSENSUS_FILE="${ARTIFACT_DIR}/consensus-record.json"
    if [[ ! -f "$CONSENSUS_FILE" ]]; then
      emit_allow_with_context \
        "CONSENSUS WARNING: Writing verdict.md but consensus-record.json does not exist. If Stage 3 trigger conditions apply, the consensus debate is MANDATORY. Check Tribunal SKILL.md Stage 3 trigger conditions." \
        "consensus-required"
      exit 0
    fi
  fi
fi

exit 0
