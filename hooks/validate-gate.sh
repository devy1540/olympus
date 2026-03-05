#!/usr/bin/env bash
# validate-gate.sh — 게이트 임계값 자동 검증
# PostToolUse(Write) 훅으로 실행됨
# stdin: JSON { tool_input: { file_path, content } }
# 위반 시 additionalContext로 피드백 반환

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

FILENAME=$(basename "$FILE_PATH")

case "$FILENAME" in
  ambiguity-scores.json)
    # 모호성: 1 - (goal*0.4 + constraints*0.3 + ac*0.3) ≤ 0.2
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

    VIOLATED=$(echo "$SCORE" | awk '{ print ($1 > 0.2) ? "true" : "false" }')
    if [[ "$VIOLATED" == "true" ]]; then
      echo "GATE VIOLATION: ambiguity score ${SCORE} > threshold 0.2. 게이트를 통과하려면 각 항목(goal, constraints, acceptanceCriteria)의 명확도 점수를 높여야 합니다."
      exit 0
    fi
    ;;

  convergence.json)
    # 수렴: similarity ≥ 0.95
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
    if [[ -z "$CONTENT" ]]; then
      exit 0
    fi

    SIMILARITY=$(echo "$CONTENT" | jq -r '.similarity // empty' 2>/dev/null || true)
    if [[ -z "$SIMILARITY" ]]; then
      exit 0
    fi

    VIOLATED=$(echo "$SIMILARITY" | awk '{ print ($1 < 0.95) ? "true" : "false" }')
    if [[ "$VIOLATED" == "true" ]]; then
      echo "GATE VIOLATION: convergence similarity ${SIMILARITY} < threshold 0.95. 수렴 기준을 충족하려면 similarity를 0.95 이상으로 높여야 합니다."
      exit 0
    fi
    ;;

  consensus-record.json)
    # 합의: percentage ≥ 0.67
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
    if [[ -z "$CONTENT" ]]; then
      exit 0
    fi

    PERCENTAGE=$(echo "$CONTENT" | jq -r '.percentage // .consensusPercentage // empty' 2>/dev/null || true)
    if [[ -z "$PERCENTAGE" ]]; then
      exit 0
    fi

    VIOLATED=$(echo "$PERCENTAGE" | awk '{ print ($1 < 0.67) ? "true" : "false" }')
    if [[ "$VIOLATED" == "true" ]]; then
      echo "GATE VIOLATION: consensus percentage ${PERCENTAGE} < threshold 0.67. 합의 기준을 충족하려면 67% 이상의 합의가 필요합니다."
      exit 0
    fi
    ;;

  mechanical-result.json)
    # 기계적 검증: 모든 stage가 PASS
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
    if [[ -z "$CONTENT" ]]; then
      exit 0
    fi

    FAILED_STAGES=$(echo "$CONTENT" | jq -r '
      [.. | objects | select(.status != null and .status != "PASS") | .stage // .name // "unknown"]
      | if length > 0 then join(", ") else empty end
    ' 2>/dev/null || true)

    if [[ -n "$FAILED_STAGES" ]]; then
      echo "GATE VIOLATION: mechanical check failed for stages: ${FAILED_STAGES}. 모든 stage가 PASS여야 게이트를 통과할 수 있습니다."
      exit 0
    fi
    ;;

  evolve-state.json)
    # 진화 상태: overall ≥ 0.8 (수렴 판정 시)
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
    if [[ -z "$CONTENT" ]]; then
      exit 0
    fi

    OVERALL=$(echo "$CONTENT" | jq -r '.overall // .qualityScore // empty' 2>/dev/null || true)
    if [[ -z "$OVERALL" ]]; then
      exit 0
    fi

    VIOLATED=$(echo "$OVERALL" | awk '{ print ($1 < 0.8) ? "true" : "false" }')
    if [[ "$VIOLATED" == "true" ]]; then
      echo "GATE VIOLATION: evolve overall quality ${OVERALL} < threshold 0.8. 품질 점수가 0.8 이상이어야 수렴 판정을 통과할 수 있습니다."
      exit 0
    fi
    ;;

  *)
    # 게이트 대상 파일이 아님
    exit 0
    ;;
esac

exit 0
