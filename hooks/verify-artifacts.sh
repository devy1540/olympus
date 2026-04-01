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

exit 0
