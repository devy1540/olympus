#!/usr/bin/env bash
# validate-gate.sh — Automatic gate threshold validation
# Runs as a PostToolUse(Write) hook
# stdin: JSON { tool_input: { file_path, content } }
# Thresholds are loaded from docs/shared/gate-thresholds.json (falls back to hardcoded defaults)
# Returns feedback via additionalContext on violation

set -euo pipefail

# --- Hook response helpers (ported from Claude Code PermissionDecision type) ---
# See docs/shared/hook-responses.json for schema definition
emit_deny() {
  local message="$1"
  local reason_type="${2:-gate}"
  local reason_detail="${3:-}"
  jq -n \
    --arg msg "$message" \
    --arg rt "$reason_type" \
    --arg rd "$reason_detail" \
    '{ behavior: "deny", message: $msg, decisionReason: { type: $rt, reason: $rd } }'
}

emit_allow_with_context() {
  local context="$1"
  local reason_type="${2:-gate}"
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

# Load thresholds
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
THRESHOLDS_FILE="${PLUGIN_ROOT}/docs/shared/gate-thresholds.json"

if [[ -f "$THRESHOLDS_FILE" ]]; then
  AMBIGUITY_THRESHOLD=$(jq -r '.ambiguity.threshold' "$THRESHOLDS_FILE")
  CONVERGENCE_THRESHOLD=$(jq -r '.convergence.threshold' "$THRESHOLDS_FILE")
  CONSENSUS_THRESHOLD=$(jq -r '.consensus.threshold' "$THRESHOLDS_FILE")
  SEMANTIC_THRESHOLD=$(jq -r '.semantic.threshold' "$THRESHOLDS_FILE")
else
  # Fallback: hardcoded defaults
  AMBIGUITY_THRESHOLD=0.2
  CONVERGENCE_THRESHOLD=0.95
  CONSENSUS_THRESHOLD=0.67
  SEMANTIC_THRESHOLD=0.8
fi

FILENAME=$(basename "$FILE_PATH")

case "$FILENAME" in
  ambiguity-scores.json)
    # Ambiguity: 1 - (goal*0.4 + constraints*0.3 + ac*0.3) <= threshold
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
    if [[ -z "$CONTENT" ]]; then
      exit 0
    fi

    SCORE=$(echo "$CONTENT" | jq -r '
      if (.goal != null and .constraints != null and .acceptanceCriteria != null) then
        (1 - (.goal * 0.4 + .constraints * 0.3 + .acceptanceCriteria * 0.3))
      elif (.goal != null and .constraints != null and .ac != null) then
        (1 - (.goal * 0.4 + .constraints * 0.3 + .ac * 0.3))
      else
        empty
      end
    ' 2>/dev/null || true)

    if [[ -z "$SCORE" ]]; then
      exit 0
    fi

    VIOLATED=$(echo "$SCORE $AMBIGUITY_THRESHOLD" | awk '{ print ($1 > $2) ? "true" : "false" }')
    if [[ "$VIOLATED" == "true" ]]; then
      emit_deny \
        "GATE VIOLATION: ambiguity score ${SCORE} > threshold ${AMBIGUITY_THRESHOLD}. Improve clarity scores for each dimension (goal, constraints, acceptanceCriteria)." \
        "gate" "ambiguity"
      exit 0
    fi

    # --- Evidence cross-validation: verify interview-log.md exists ---
    DIR=$(dirname "$FILE_PATH")
    if [[ ! -f "${DIR}/interview-log.md" ]]; then
      emit_allow_with_context \
        "EVIDENCE WARNING: ambiguity-scores.json saved but interview-log.md does not exist yet. Ambiguity scores must be grounded in interview evidence." \
        "evidence"
      exit 0
    fi

    # --- Evidence cross-validation: round count consistency ---
    ROUNDS_IN_SCORES=$(echo "$CONTENT" | jq -r '.rounds // .round // empty' 2>/dev/null || true)
    if [[ -n "$ROUNDS_IN_SCORES" ]]; then
      ROUNDS_IN_LOG=$(grep -cE '^#{1,3}\s+(Round|Q[0-9]|Question)' "${DIR}/interview-log.md" 2>/dev/null || echo "0")
      if [[ "$ROUNDS_IN_LOG" -gt 0 && "$ROUNDS_IN_SCORES" -gt 0 ]]; then
        DIFF=$((ROUNDS_IN_SCORES - ROUNDS_IN_LOG))
        if [[ ${DIFF#-} -gt 2 ]]; then
          emit_allow_with_context \
            "EVIDENCE WARNING: Round count in ambiguity-scores.json (${ROUNDS_IN_SCORES}) differs from interview-log.md (${ROUNDS_IN_LOG}) by >2. Verify scores match the actual interview." \
            "evidence"
          exit 0
        fi
      fi
    fi

    # --- Suspiciously low score warning ---
    # If ambiguity score is very low (< 0.1), check if codebase-context.md exists
    # and has substantial content — extremely low scores on complex projects
    # are a sign of insufficient interview depth
    if [[ -n "$SCORE" ]]; then
      IS_VERY_LOW=$(echo "$SCORE" | awk '{ print ($1 < 0.1) ? "true" : "false" }')
      if [[ "$IS_VERY_LOW" == "true" ]]; then
        CONTEXT_FILE="${DIR}/codebase-context.md"
        if [[ -f "$CONTEXT_FILE" ]]; then
          CONTEXT_LINES=$(wc -l < "$CONTEXT_FILE" 2>/dev/null || echo "0")
          # If codebase context is substantial (50+ lines = complex project)
          # but ambiguity is < 0.1, the interview may have been too shallow
          if [[ "$CONTEXT_LINES" -gt 50 ]]; then
            emit_allow_with_context \
              "AMBIGUITY CALIBRATION WARNING: Score ${SCORE} is unusually low for a project with substantial codebase context (${CONTEXT_LINES} lines in codebase-context.md). Complex projects rarely have ambiguity < 0.1 after only a few interview rounds. Consider whether edge cases, error handling, and technical constraints have been fully explored." \
              "calibration"
            exit 0
          fi
        fi
      fi
    fi
    ;;

  convergence.json)
    # Convergence: similarity >= threshold
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
    if [[ -z "$CONTENT" ]]; then
      exit 0
    fi

    SIMILARITY=$(echo "$CONTENT" | jq -r '.similarity // empty' 2>/dev/null || true)
    if [[ -z "$SIMILARITY" ]]; then
      exit 0
    fi

    VIOLATED=$(echo "$SIMILARITY $CONVERGENCE_THRESHOLD" | awk '{ print ($1 < $2) ? "true" : "false" }')
    if [[ "$VIOLATED" == "true" ]]; then
      emit_deny "GATE VIOLATION: convergence similarity ${SIMILARITY} < threshold ${CONVERGENCE_THRESHOLD}. Similarity must be >= ${CONVERGENCE_THRESHOLD}." "gate" "convergence"
      exit 0
    fi
    ;;

  consensus-record.json)
    # Consensus: percentage >= threshold
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
    if [[ -z "$CONTENT" ]]; then
      exit 0
    fi

    PERCENTAGE=$(echo "$CONTENT" | jq -r '.percentage // .consensusPercentage // empty' 2>/dev/null || true)
    if [[ -z "$PERCENTAGE" ]]; then
      exit 0
    fi

    VIOLATED=$(echo "$PERCENTAGE $CONSENSUS_THRESHOLD" | awk '{ print ($1 < $2) ? "true" : "false" }')
    if [[ "$VIOLATED" == "true" ]]; then
      emit_deny "GATE VIOLATION: consensus percentage ${PERCENTAGE} < threshold ${CONSENSUS_THRESHOLD}." "gate" "consensus"
      exit 0
    fi
    ;;

  mechanical-result.json)
    # Mechanical: all stages must be PASS
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
    if [[ -z "$CONTENT" ]]; then
      exit 0
    fi

    FAILED_STAGES=$(echo "$CONTENT" | jq -r '
      [.. | objects | select(.status != null and .status != "PASS") | .stage // .name // "unknown"]
      | if length > 0 then join(", ") else empty end
    ' 2>/dev/null || true)

    if [[ -n "$FAILED_STAGES" ]]; then
      emit_deny "GATE VIOLATION: mechanical check failed for stages: ${FAILED_STAGES}. All stages must PASS." "gate" "mechanical"
      exit 0
    fi
    ;;

  evolve-state.json)
    # Evolve: overall quality >= threshold
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
    if [[ -z "$CONTENT" ]]; then
      exit 0
    fi

    OVERALL=$(echo "$CONTENT" | jq -r '.overall // .qualityScore // empty' 2>/dev/null || true)
    if [[ -z "$OVERALL" ]]; then
      exit 0
    fi

    VIOLATED=$(echo "$OVERALL $SEMANTIC_THRESHOLD" | awk '{ print ($1 < $2) ? "true" : "false" }')
    if [[ "$VIOLATED" == "true" ]]; then
      emit_deny "GATE VIOLATION: evolve overall quality ${OVERALL} < threshold ${SEMANTIC_THRESHOLD}. Quality score must be >= ${SEMANTIC_THRESHOLD}." "gate" "semantic"
      exit 0
    fi
    ;;

  semantic-matrix.md)
    # Semantic evaluation: verify mechanical-result.json passed + file:line reference validation
    DIR=$(dirname "$FILE_PATH")

    # Precondition: mechanical-result.json must be PASS
    if [[ -f "${DIR}/mechanical-result.json" ]]; then
      MECH_OVERALL=$(jq -r '.overall // empty' "${DIR}/mechanical-result.json" 2>/dev/null || true)
      if [[ -n "$MECH_OVERALL" && "$MECH_OVERALL" != "PASS" ]]; then
        emit_deny "mechanical-result.json must be PASS before writing semantic-matrix.md. Current: ${MECH_OVERALL}. Complete Tribunal Stage 1 first." "contract" "semantic-matrix precondition"
        exit 0
      fi
    else
      emit_allow_with_context "EVIDENCE WARNING: semantic-matrix.md written but mechanical-result.json does not exist. Run Tribunal Stage 1 first." "evidence"
      exit 0
    fi

    # file:line reference validation: at least 1 valid reference required
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
    if [[ -n "$CONTENT" ]]; then
      # Extract file:line patterns (e.g., src/auth.ts:42, ./lib/utils.js:15)
      FILE_REFS=$(echo "$CONTENT" | grep -oE '[a-zA-Z0-9_./-]+\.[a-zA-Z]+:[0-9]+' || true)
      if [[ -z "$FILE_REFS" ]]; then
        REF_COUNT=0
      else
        REF_COUNT=$(echo "$FILE_REFS" | wc -l | tr -d ' ')
      fi

      if [[ "$REF_COUNT" -lt 1 ]]; then
        emit_allow_with_context "EVIDENCE WARNING: semantic-matrix.md contains no file:line references. AC verification must include implementation evidence (file:line)." "evidence"
        exit 0
      fi

      # Check up to 5 referenced files for existence
      INVALID_REFS=""
      CHECKED=0
      for REF in $FILE_REFS; do
        if [[ $CHECKED -ge 5 ]]; then break; fi
        REF_FILE=$(echo "$REF" | cut -d: -f1)
        # Check against absolute path or CWD-relative path
        if [[ -n "$REF_FILE" && ! -f "$REF_FILE" ]]; then
          if [[ ! -f "${PWD}/${REF_FILE}" ]]; then
            INVALID_REFS="${INVALID_REFS}  - ${REF}\n"
          fi
        fi
        CHECKED=$((CHECKED + 1))
      done

      if [[ -n "$INVALID_REFS" ]]; then
        emit_allow_with_context "EVIDENCE WARNING: file:line references in semantic-matrix.md point to non-existent files: $(echo -e "$INVALID_REFS" | tr '\n' ' ')" "evidence"
        exit 0
      fi
    fi
    ;;

  verdict.md)
    # Verdict: verify spec.md exists (verdicts must be spec-grounded)
    DIR=$(dirname "$FILE_PATH")
    if [[ ! -f "${DIR}/spec.md" && ! -f "${DIR}/../spec.md" ]]; then
      # For odyssey, spec.md may be in a parent or sibling artifact directory
      OLYMPUS_ROOT=$(echo "$FILE_PATH" | sed -n 's|\(.*\.olympus/\).*|\1|p' || true)
      # Re-validate: path must end with /.olympus/
      if [[ -n "$OLYMPUS_ROOT" && "$OLYMPUS_ROOT" != *"/.olympus/" ]]; then
        OLYMPUS_ROOT=""
      fi
      if [[ -n "$OLYMPUS_ROOT" ]]; then
        SPEC_FOUND=$(find "$OLYMPUS_ROOT" -name "spec.md" -maxdepth 3 2>/dev/null | head -1 || true)
        if [[ -z "$SPEC_FOUND" ]]; then
          emit_allow_with_context "EVIDENCE WARNING: verdict.md written but no spec.md found under .olympus/. Verdicts must be grounded in a specification." "evidence"
          exit 0
        fi
      fi
    fi
    ;;

  *)
    # Not a gate-relevant file
    exit 0
    ;;
esac

exit 0
