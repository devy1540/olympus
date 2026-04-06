#!/usr/bin/env bash
# validate-state.sh — Pipeline state transition validation
# Runs as a PostToolUse(Write) hook
# stdin: JSON { tool_input: { file_path, content } }
#
# Validates odyssey-state.json and evolve-state.json against:
#   1. pipeline-states.json schema (Terminal/Continue types, phase enum)
#   2. Transition rules (which phase can follow which)
#   3. Gate preconditions (must pass gate before advancing)
#   4. Retry tracking limits (evaluationPass <= maxPasses)
#
# DERIVATION: Enforces the schema defined in pipeline-states.json,
# which was ported from Claude Code's query.ts State/Terminal/Continue types.

set -euo pipefail

# --- Hook response helpers (ported from PermissionDecision type) ---
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
  local reason_type="${2:-other}"
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

FILENAME=$(basename "$FILE_PATH")

# Only process state files
case "$FILENAME" in
  odyssey-state.json) ;;
  evolve-state.json) ;;
  *) exit 0 ;;
esac

CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
# PostToolUse: for Edit operations, content is empty — read file directly (already applied)
if [[ -z "$CONTENT" && -f "$FILE_PATH" ]]; then
  CONTENT=$(cat "$FILE_PATH" 2>/dev/null || true)
fi
if [[ -z "$CONTENT" ]]; then
  exit 0
fi

CURRENT_PHASE=$(echo "$CONTENT" | jq -r '.phase // empty' 2>/dev/null || true)
if [[ -z "$CURRENT_PHASE" ]]; then
  exit 0
fi

# Load pipeline-states.json for schema validation
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
STATES_FILE="${PLUGIN_ROOT}/docs/shared/pipeline-states.json"

# --- 1. Phase enum validation (from pipeline-states.json OdysseyPhases) ---
if [[ "$FILENAME" == "odyssey-state.json" ]]; then
  VALID_PHASES="oracle genesis pantheon planning execution tribunal completed"
  PHASE_VALID=false
  for p in $VALID_PHASES; do
    if [[ "$CURRENT_PHASE" == "$p" ]]; then
      PHASE_VALID=true
      break
    fi
  done

  if [[ "$PHASE_VALID" == "false" ]]; then
    emit_deny \
      "STATE VIOLATION: '${CURRENT_PHASE}' is not a valid Odyssey phase. Valid phases: ${VALID_PHASES}" \
      "rule" "invalid phase enum"
    exit 0
  fi
fi

# --- 2. Transition validation (from pipeline-states.json transitions) ---
DIR=$(dirname "$FILE_PATH")
CHECKPOINT_DIR="${DIR}/.checkpoints"

if [[ -d "$CHECKPOINT_DIR" ]]; then
  LATEST_CHECKPOINT=$(ls -1 "${CHECKPOINT_DIR}/${FILENAME}".*.json 2>/dev/null | sort -V | tail -1 || true)

  if [[ -n "$LATEST_CHECKPOINT" && -f "$LATEST_CHECKPOINT" ]]; then
    PREV_PHASE=$(jq -r '.phase // empty' "$LATEST_CHECKPOINT" 2>/dev/null || true)

    if [[ -n "$PREV_PHASE" && "$FILENAME" == "odyssey-state.json" ]]; then
      TRANSITION_VALID=false

      # Transition rules ported from pipeline-states.json OdysseyPhases.transitions
      case "$PREV_PHASE" in
        oracle)    [[ "$CURRENT_PHASE" == "genesis" || "$CURRENT_PHASE" == "pantheon" ]] && TRANSITION_VALID=true ;;
        genesis)   [[ "$CURRENT_PHASE" == "pantheon" ]] && TRANSITION_VALID=true ;;
        pantheon)  [[ "$CURRENT_PHASE" == "planning" ]] && TRANSITION_VALID=true ;;
        planning)  [[ "$CURRENT_PHASE" == "execution" ]] && TRANSITION_VALID=true ;;
        execution) [[ "$CURRENT_PHASE" == "tribunal" ]] && TRANSITION_VALID=true ;;
        tribunal)  [[ "$CURRENT_PHASE" == "completed" || "$CURRENT_PHASE" == "execution" ]] && TRANSITION_VALID=true ;;
        completed) TRANSITION_VALID=false ;;
      esac

      # Same phase is allowed (state update without transition)
      [[ "$PREV_PHASE" == "$CURRENT_PHASE" ]] && TRANSITION_VALID=true

      # Terminal rewind: tribunal rejection can rewind to any earlier phase
      # via Terminal.returnToPhase (REJECTED_SPEC→oracle, REJECTED_ARCHITECTURE→pantheon)
      if [[ "$TRANSITION_VALID" == "false" ]]; then
        RETURN_TO=$(echo "$CONTENT" | jq -r '.transition.returnToPhase // empty' 2>/dev/null || true)
        if [[ -n "$RETURN_TO" && "$RETURN_TO" == "$CURRENT_PHASE" ]]; then
          TRANSITION_VALID=true
        fi
      fi

      if [[ "$TRANSITION_VALID" == "false" ]]; then
        emit_deny \
          "STATE VIOLATION: invalid transition '${PREV_PHASE}' -> '${CURRENT_PHASE}'. Allowed forward: oracle->genesis|pantheon, genesis->pantheon, pantheon->planning, planning->execution, execution->tribunal, tribunal->completed|execution. Rewinds (via transition.returnToPhase): tribunal->oracle|pantheon." \
          "rule" "invalid phase transition"
        exit 0
      fi
    fi
  fi
fi

# --- 3. Transition field validation (enforces pipeline-states.json Terminal/Continue schema) ---
TRANSITION_STATUS=$(echo "$CONTENT" | jq -r '.transition.status // empty' 2>/dev/null || true)

if [[ -n "$TRANSITION_STATUS" ]]; then
  case "$TRANSITION_STATUS" in
    terminal)
      # Validate Terminal.reason against schema enum
      REASON=$(echo "$CONTENT" | jq -r '.transition.reason // empty' 2>/dev/null || true)
      VALID_TERMINAL_REASONS="completed approved rejected blocked incomplete aborted max_retries stagnation user_override error"
      REASON_VALID=false
      for r in $VALID_TERMINAL_REASONS; do
        [[ "$REASON" == "$r" ]] && REASON_VALID=true && break
      done
      if [[ "$REASON_VALID" == "false" && -n "$REASON" ]]; then
        emit_deny \
          "STATE VIOLATION: transition.reason '${REASON}' is not a valid Terminal reason. Valid: ${VALID_TERMINAL_REASONS}" \
          "rule" "invalid Terminal.reason"
        exit 0
      fi
      ;;
    continue)
      # Validate Continue.reason against schema enum
      REASON=$(echo "$CONTENT" | jq -r '.transition.reason // empty' 2>/dev/null || true)
      VALID_CONTINUE_REASONS="next_phase gate_retry feedback_loop implementation_retry debug_retry generation_next persona_switch user_directed"
      REASON_VALID=false
      for r in $VALID_CONTINUE_REASONS; do
        [[ "$REASON" == "$r" ]] && REASON_VALID=true && break
      done
      if [[ "$REASON_VALID" == "false" && -n "$REASON" ]]; then
        emit_deny \
          "STATE VIOLATION: transition.reason '${REASON}' is not a valid Continue reason. Valid: ${VALID_CONTINUE_REASONS}" \
          "rule" "invalid Continue.reason"
        exit 0
      fi

      # Validate retryCount <= maxRetries if present
      RETRY_COUNT=$(echo "$CONTENT" | jq -r '.transition.retryCount // empty' 2>/dev/null || true)
      MAX_RETRIES=$(echo "$CONTENT" | jq -r '.transition.maxRetries // empty' 2>/dev/null || true)
      if [[ -n "$RETRY_COUNT" && -n "$MAX_RETRIES" ]]; then
        EXCEEDED=$(echo "$RETRY_COUNT $MAX_RETRIES" | awk '{ print ($1 > $2) ? "true" : "false" }')
        if [[ "$EXCEEDED" == "true" ]]; then
          emit_deny \
            "STATE VIOLATION: transition.retryCount (${RETRY_COUNT}) > maxRetries (${MAX_RETRIES}). Must terminate or escalate." \
            "rule" "retry limit exceeded"
          exit 0
        fi
      fi
      ;;
    *)
      emit_deny \
        "STATE VIOLATION: transition.status '${TRANSITION_STATUS}' is invalid. Must be 'terminal' or 'continue'." \
        "rule" "invalid transition status"
      exit 0
      ;;
  esac
fi

# --- 4. Retry tracking validation (retryTracking.evaluationPass <= maxPasses) ---
if [[ "$FILENAME" == "odyssey-state.json" ]]; then
  # Support both flat and nested retryTracking format
  EVAL_PASS=$(echo "$CONTENT" | jq -r '.retryTracking.evaluationPass // .evaluationPass // empty' 2>/dev/null || true)
  MAX_PASSES=$(echo "$CONTENT" | jq -r '.retryTracking.maxPasses // .maxPasses // empty' 2>/dev/null || true)

  if [[ -n "$EVAL_PASS" && -n "$MAX_PASSES" ]]; then
    EXCEEDED=$(echo "$EVAL_PASS $MAX_PASSES" | awk '{ print ($1 > $2) ? "true" : "false" }')
    if [[ "$EXCEEDED" == "true" ]]; then
      emit_deny \
        "STATE VIOLATION: evaluationPass (${EVAL_PASS}) > maxPasses (${MAX_PASSES}). Maximum evaluation retries exceeded." \
        "rule" "evaluationPass limit"
      exit 0
    fi
  fi

  # Debug cycle circuit breaker (Phase 5 build→debug→build loop limit)
  DEBUG_FAILURES=$(echo "$CONTENT" | jq -r '.retryTracking.consecutiveDebugFailures // empty' 2>/dev/null || true)
  MAX_DEBUG=$(echo "$CONTENT" | jq -r '.retryTracking.maxDebugCycles // empty' 2>/dev/null || true)

  if [[ -n "$DEBUG_FAILURES" && -n "$MAX_DEBUG" ]]; then
    EXCEEDED=$(echo "$DEBUG_FAILURES $MAX_DEBUG" | awk '{ print ($1 > $2) ? "true" : "false" }')
    if [[ "$EXCEEDED" == "true" ]]; then
      emit_deny \
        "STATE VIOLATION: consecutiveDebugFailures (${DEBUG_FAILURES}) > maxDebugCycles (${MAX_DEBUG}). Debug circuit breaker exceeded — proceed to Tribunal." \
        "rule" "debug cycle limit"
      exit 0
    fi
  fi
fi

# --- 5. Gate precondition validation (phase requires prior gate to have passed) ---
if [[ "$FILENAME" == "odyssey-state.json" ]]; then
  # Load thresholds from gate-thresholds.json
  THRESHOLDS_FILE="${PLUGIN_ROOT}/docs/shared/gate-thresholds.json"

  if [[ -f "$THRESHOLDS_FILE" ]]; then
    case "$CURRENT_PHASE" in
      pantheon)
        AMB_SCORE=$(echo "$CONTENT" | jq -r '.gates.ambiguityScore // empty' 2>/dev/null || true)
        AMB_THRESHOLD=$(jq -r '.ambiguity.threshold' "$THRESHOLDS_FILE" 2>/dev/null || echo "0.2")
        if [[ -n "$AMB_SCORE" ]]; then
          VIOLATED=$(echo "$AMB_SCORE $AMB_THRESHOLD" | awk '{ print ($1 > $2) ? "true" : "false" }')
          if [[ "$VIOLATED" == "true" ]]; then
            emit_deny \
              "STATE VIOLATION: pantheon phase requires gates.ambiguityScore <= ${AMB_THRESHOLD}, got ${AMB_SCORE}. Pass the ambiguity gate first." \
              "gate" "ambiguity precondition"
            exit 0
          fi
        fi
        ;;
      planning)
        CONSENSUS=$(echo "$CONTENT" | jq -r '.gates.consensusLevel // empty' 2>/dev/null || true)
        CON_THRESHOLD=$(jq -r '.consensus.threshold' "$THRESHOLDS_FILE" 2>/dev/null || echo "0.66")
        if [[ -n "$CONSENSUS" ]]; then
          VIOLATED=$(echo "$CONSENSUS $CON_THRESHOLD" | awk '{ print ($1 < $2) ? "true" : "false" }')
          if [[ "$VIOLATED" == "true" ]]; then
            emit_deny \
              "STATE VIOLATION: planning phase requires gates.consensusLevel >= ${CON_THRESHOLD}, got ${CONSENSUS}. Pass the consensus gate first." \
              "gate" "consensus precondition"
            exit 0
          fi
        fi
        ;;
      execution)
        THEMIS_VERDICT=$(echo "$CONTENT" | jq -r '.gates.themisVerdict // empty' 2>/dev/null || true)
        if [[ -n "$THEMIS_VERDICT" && "$THEMIS_VERDICT" != "APPROVE" ]]; then
          emit_deny \
            "STATE VIOLATION: execution phase requires gates.themisVerdict = APPROVE, got ${THEMIS_VERDICT}. Themis must approve the plan before execution." \
            "gate" "themis precondition"
          exit 0
        fi
        ;;
      completed)
        # Use explicit null-check instead of // to handle JSON false correctly
        # (jq // treats false as falsy and skips to next alternative)
        BUILD_PASS=$(echo "$CONTENT" | jq -r '
          if (.gates.mechanicalPass != null) then (.gates.mechanicalPass | tostring)
          elif (.gates.buildPass != null) then (.gates.buildPass | tostring)
          else empty end
        ' 2>/dev/null || true)
        if [[ -n "$BUILD_PASS" && "$BUILD_PASS" != "true" ]]; then
          emit_deny \
            "STATE VIOLATION: completed phase requires gates.mechanicalPass = true, got ${BUILD_PASS}. Pass the mechanical gate first." \
            "gate" "mechanical precondition"
          exit 0
        fi
        ;;
    esac
  fi
fi

exit 0
