#!/usr/bin/env bash
# validate-state.sh — 상태 전이 검증
# PostToolUse(Write) 훅으로 실행됨
# stdin: JSON { tool_input: { file_path, content } }
# odyssey-state.json 또는 evolve-state.json의 phase 전이를 검증

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

FILENAME=$(basename "$FILE_PATH")

# odyssey-state.json 또는 evolve-state.json만 처리
case "$FILENAME" in
  odyssey-state.json) ;;
  evolve-state.json) ;;
  *) exit 0 ;;
esac

CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
if [[ -z "$CONTENT" ]]; then
  exit 0
fi

CURRENT_PHASE=$(echo "$CONTENT" | jq -r '.phase // empty' 2>/dev/null || true)
if [[ -z "$CURRENT_PHASE" ]]; then
  exit 0
fi

# --- Phase enum 검증 ---
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
    echo "STATE VIOLATION: '${CURRENT_PHASE}' is not a valid Odyssey phase. 허용된 phase: ${VALID_PHASES}"
    exit 0
  fi
fi

# --- 체크포인트에서 이전 phase 읽기 ---
DIR=$(dirname "$FILE_PATH")
CHECKPOINT_DIR="${DIR}/.checkpoints"

if [[ -d "$CHECKPOINT_DIR" ]]; then
  # 가장 최근 체크포인트 찾기
  LATEST_CHECKPOINT=$(ls -1 "${CHECKPOINT_DIR}/${FILENAME}".*.json 2>/dev/null | sort -t. -k2 -n | tail -1 || true)

  if [[ -n "$LATEST_CHECKPOINT" && -f "$LATEST_CHECKPOINT" ]]; then
    PREV_PHASE=$(jq -r '.phase // empty' "$LATEST_CHECKPOINT" 2>/dev/null || true)

    if [[ -n "$PREV_PHASE" && "$FILENAME" == "odyssey-state.json" ]]; then
      # --- 상태 전이 규칙 검증 ---
      TRANSITION_VALID=false

      case "$PREV_PHASE" in
        oracle)
          [[ "$CURRENT_PHASE" == "genesis" || "$CURRENT_PHASE" == "pantheon" ]] && TRANSITION_VALID=true
          ;;
        genesis)
          [[ "$CURRENT_PHASE" == "pantheon" ]] && TRANSITION_VALID=true
          ;;
        pantheon)
          [[ "$CURRENT_PHASE" == "planning" ]] && TRANSITION_VALID=true
          ;;
        planning)
          [[ "$CURRENT_PHASE" == "execution" ]] && TRANSITION_VALID=true
          ;;
        execution)
          [[ "$CURRENT_PHASE" == "tribunal" ]] && TRANSITION_VALID=true
          ;;
        tribunal)
          [[ "$CURRENT_PHASE" == "completed" || "$CURRENT_PHASE" == "execution" ]] && TRANSITION_VALID=true
          ;;
        completed)
          # completed에서는 전이 불가
          TRANSITION_VALID=false
          ;;
      esac

      # 동일 phase 유지는 허용
      if [[ "$PREV_PHASE" == "$CURRENT_PHASE" ]]; then
        TRANSITION_VALID=true
      fi

      if [[ "$TRANSITION_VALID" == "false" ]]; then
        echo "STATE VIOLATION: invalid transition '${PREV_PHASE}' → '${CURRENT_PHASE}'. 허용 전이: oracle→genesis|pantheon, genesis→pantheon, pantheon→planning, planning→execution, execution→tribunal, tribunal→completed|execution"
        exit 0
      fi
    fi
  fi
fi

# --- evaluationPass ≤ maxPasses 검증 ---
if [[ "$FILENAME" == "odyssey-state.json" ]]; then
  EVAL_PASS=$(echo "$CONTENT" | jq -r '.evaluationPass // empty' 2>/dev/null || true)
  MAX_PASSES=$(echo "$CONTENT" | jq -r '.maxPasses // empty' 2>/dev/null || true)

  if [[ -n "$EVAL_PASS" && -n "$MAX_PASSES" ]]; then
    EXCEEDED=$(echo "$EVAL_PASS $MAX_PASSES" | awk '{ print ($1 > $2) ? "true" : "false" }')
    if [[ "$EXCEEDED" == "true" ]]; then
      echo "STATE VIOLATION: evaluationPass (${EVAL_PASS}) > maxPasses (${MAX_PASSES}). 최대 평가 횟수를 초과했습니다."
      exit 0
    fi
  fi
fi

# --- Phase별 게이트 통과 검증 ---
if [[ "$FILENAME" == "odyssey-state.json" ]]; then
  case "$CURRENT_PHASE" in
    pantheon)
      AMB_SCORE=$(echo "$CONTENT" | jq -r '.gates.ambiguityScore // empty' 2>/dev/null || true)
      if [[ -n "$AMB_SCORE" ]]; then
        VIOLATED=$(echo "$AMB_SCORE" | awk '{ print ($1 > 0.2) ? "true" : "false" }')
        if [[ "$VIOLATED" == "true" ]]; then
          echo "STATE VIOLATION: pantheon phase requires gates.ambiguityScore ≤ 0.2, got ${AMB_SCORE}. 모호성 게이트를 먼저 통과해야 합니다."
          exit 0
        fi
      fi
      ;;
    planning)
      CONSENSUS=$(echo "$CONTENT" | jq -r '.gates.consensusLevel // empty' 2>/dev/null || true)
      if [[ -n "$CONSENSUS" ]]; then
        VIOLATED=$(echo "$CONSENSUS" | awk '{ print ($1 < 0.67) ? "true" : "false" }')
        if [[ "$VIOLATED" == "true" ]]; then
          echo "STATE VIOLATION: planning phase requires gates.consensusLevel ≥ 0.67, got ${CONSENSUS}. 합의 게이트를 먼저 통과해야 합니다."
          exit 0
        fi
      fi
      ;;
    completed)
      BUILD_PASS=$(echo "$CONTENT" | jq -r '.gates.buildPass // empty' 2>/dev/null || true)
      if [[ -n "$BUILD_PASS" && "$BUILD_PASS" != "true" ]]; then
        echo "STATE VIOLATION: completed phase requires gates.buildPass = true, got ${BUILD_PASS}. 빌드 게이트를 먼저 통과해야 합니다."
        exit 0
      fi
      ;;
  esac
fi

exit 0
