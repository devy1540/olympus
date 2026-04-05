#!/usr/bin/env bash
# validate-agents.sh — Agent definition validation against agent-schema.json
# Runs as a PostToolUse(Write,Edit) hook for agents/*.md files
# stdin: JSON { tool_input: { file_path, content } }
#
# Validates agent frontmatter against agent-schema.json:
#   1. Required fields: name, description, model, disallowedTools
#   2. Model enum: opus | sonnet | haiku
#   3. disallowedTools items: Write | Edit | Bash | NotebookEdit
#   4. Permission-role consistency: disallowedTools vs registry permissionLevel
#   5. Name pattern: lowercase only
#
# DERIVATION: Enforces agent-schema.json, which was ported from
# Claude Code's buildTool() + TOOL_DEFAULTS pattern (Tool.ts:757-792)

set -euo pipefail

# --- Hook response helpers ---
emit_deny() {
  local message="$1"
  local reason_type="${2:-rule}"
  local reason_detail="${3:-}"
  jq -n \
    --arg msg "$message" \
    --arg rt "$reason_type" \
    --arg rd "$reason_detail" \
    '{ behavior: "deny", message: $msg, decisionReason: { type: $rt, reason: $rd } }'
}

emit_allow_with_context() {
  local context="$1"
  jq -n --arg ctx "$context" \
    '{ behavior: "allow", additionalContext: $ctx, decisionReason: { type: "rule" } }'
}

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  echo '{ "behavior": "allow" }'
  exit 0
fi

# Only validate agents/*.md files
if [[ "$FILE_PATH" != */agents/*.md ]]; then
  echo '{ "behavior": "allow" }'
  exit 0
fi

CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
if [[ -z "$CONTENT" ]]; then
  echo '{ "behavior": "allow" }'
  exit 0
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
SCHEMA_FILE="${PLUGIN_ROOT}/docs/shared/agent-schema.json"

if [[ ! -f "$SCHEMA_FILE" ]]; then
  exit 0
fi

VIOLATIONS=""
WARNINGS=""

# --- Extract YAML frontmatter ---
# Frontmatter is between first --- and second ---
FRONTMATTER=$(echo "$CONTENT" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')

if [[ -z "$FRONTMATTER" ]]; then
  emit_deny "AGENT VIOLATION: No YAML frontmatter found in $(basename "$FILE_PATH"). Agent definitions require ---frontmatter--- block." "rule" "missing frontmatter"
  exit 0
fi

# Extract fields using grep (simple YAML parsing for flat structure)
extract_field() {
  local field="$1"
  echo "$FRONTMATTER" | grep -E "^${field}:" | sed -E "s/^${field}:\s*//" | sed 's/^"//' | sed 's/"$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || true
}

NAME=$(extract_field "name")
DESCRIPTION=$(extract_field "description")
MODEL=$(extract_field "model")
MAX_TURNS=$(extract_field "maxTurns")
# disallowedTools is a YAML array — extract items
# Handle block format:  disallowedTools:\n  - Write\n  - Edit
DISALLOWED_TOOLS=$(echo "$FRONTMATTER" | sed -n '/^disallowedTools:/,/^[a-zA-Z]/p' | grep -E '^[[:space:]]*-' | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/[[:space:]]*$//' || true)
# Handle inline format: disallowedTools: [Write, Edit]
if [[ -z "$DISALLOWED_TOOLS" ]]; then
  INLINE=$(extract_field "disallowedTools")
  if [[ -n "$INLINE" && "$INLINE" != "[]" ]]; then
    DISALLOWED_TOOLS=$(echo "$INLINE" | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  fi
fi

# --- 1. Required fields ---
if [[ -z "$NAME" ]]; then
  VIOLATIONS="${VIOLATIONS}\n  - Missing required field: name"
fi
if [[ -z "$DESCRIPTION" ]]; then
  VIOLATIONS="${VIOLATIONS}\n  - Missing required field: description"
fi
if [[ -z "$MODEL" ]]; then
  VIOLATIONS="${VIOLATIONS}\n  - Missing required field: model"
fi

# --- 2. Name pattern: lowercase only ---
if [[ -n "$NAME" && ! "$NAME" =~ ^[a-z]+$ ]]; then
  VIOLATIONS="${VIOLATIONS}\n  - name '${NAME}' must be lowercase letters only (pattern: ^[a-z]+$)"
fi

# --- 3. Model enum ---
if [[ -n "$MODEL" ]]; then
  case "$MODEL" in
    opus|sonnet|haiku) ;; # valid
    *) VIOLATIONS="${VIOLATIONS}\n  - model '${MODEL}' is invalid. Must be: opus | sonnet | haiku" ;;
  esac
fi

# --- 4. disallowedTools items ---
if [[ -n "$DISALLOWED_TOOLS" ]]; then
  while IFS= read -r tool; do
    tool=$(echo "$tool" | xargs)  # trim whitespace
    [[ -z "$tool" ]] && continue
    case "$tool" in
      Write|Edit|Bash|NotebookEdit) ;; # valid
      *) VIOLATIONS="${VIOLATIONS}\n  - disallowedTools item '${tool}' is invalid. Must be: Write | Edit | Bash | NotebookEdit" ;;
    esac
  done <<< "$DISALLOWED_TOOLS"
fi

# --- 5. Permission-role consistency (cross-check with registry) ---
if [[ -n "$NAME" ]]; then
  REGISTRY_PERMISSION=$(jq -r --arg agent "$NAME" \
    '.agentRegistry.agents[$agent].permissionLevel // empty' "$SCHEMA_FILE" 2>/dev/null || true)

  if [[ -n "$REGISTRY_PERMISSION" ]]; then
    # Check: if registry says read-only, disallowedTools must include Write and Edit
    if [[ "$REGISTRY_PERMISSION" == "read-only" ]]; then
      HAS_WRITE=$(echo "$DISALLOWED_TOOLS" | grep -c "Write" || echo "0")
      HAS_EDIT=$(echo "$DISALLOWED_TOOLS" | grep -c "Edit" || echo "0")
      if [[ "$HAS_WRITE" == "0" || "$HAS_EDIT" == "0" ]]; then
        WARNINGS="${WARNINGS}\n  - Agent '${NAME}' is registered as read-only but disallowedTools doesn't include both Write and Edit"
      fi
    fi
    # Check: if registry says write, disallowedTools must include Edit (can Write but not Edit)
    if [[ "$REGISTRY_PERMISSION" == "write" ]]; then
      HAS_EDIT=$(echo "$DISALLOWED_TOOLS" | grep -c "Edit" || echo "0")
      if [[ "$HAS_EDIT" == "0" ]]; then
        WARNINGS="${WARNINGS}\n  - Agent '${NAME}' is registered as write-only but disallowedTools doesn't include Edit"
      fi
      HAS_WRITE=$(echo "$DISALLOWED_TOOLS" | grep -c "Write" || echo "0")
      if [[ "$HAS_WRITE" -gt 0 ]]; then
        WARNINGS="${WARNINGS}\n  - Agent '${NAME}' is registered as write-only but disallowedTools includes Write (should only disallow Edit)"
      fi
    fi
    # Check: if registry says full, disallowedTools should be empty
    if [[ "$REGISTRY_PERMISSION" == "full" ]]; then
      TOOL_COUNT=$(echo "$DISALLOWED_TOOLS" | grep -c '.' || echo "0")
      if [[ "$TOOL_COUNT" -gt 0 ]]; then
        WARNINGS="${WARNINGS}\n  - Agent '${NAME}' is registered as full permission but has disallowedTools entries"
      fi
    fi
  fi
fi

# --- 6. Description length ---
if [[ -n "$DESCRIPTION" ]]; then
  DESC_LEN=${#DESCRIPTION}
  if [[ "$DESC_LEN" -gt 200 ]]; then
    WARNINGS="${WARNINGS}\n  - description length (${DESC_LEN}) exceeds recommended max of 200 characters"
  fi
fi

# --- 7. maxTurns range (schema: integer, 1-50) ---
if [[ -n "$MAX_TURNS" ]]; then
  IS_INT=$(echo "$MAX_TURNS" | grep -cE '^[0-9]+$' || echo "0")
  if [[ "$IS_INT" == "0" ]]; then
    VIOLATIONS="${VIOLATIONS}\n  - maxTurns '${MAX_TURNS}' must be an integer"
  else
    if [[ "$MAX_TURNS" -lt 1 || "$MAX_TURNS" -gt 50 ]]; then
      VIOLATIONS="${VIOLATIONS}\n  - maxTurns ${MAX_TURNS} out of range [1, 50] (agent-schema.json constraint)"
    fi
  fi
fi

# --- Emit results ---
if [[ -n "$VIOLATIONS" ]]; then
  emit_deny \
    "AGENT SCHEMA VIOLATIONS in $(basename "$FILE_PATH"):${VIOLATIONS}" \
    "rule" "agent-schema.json validation"
  exit 0
fi

if [[ -n "$WARNINGS" ]]; then
  emit_allow_with_context \
    "AGENT SCHEMA WARNINGS in $(basename "$FILE_PATH"):${WARNINGS}"
  exit 0
fi

exit 0
