#!/usr/bin/env bash
# checkpoint.sh — 상태 파일 체크포인트 백업
# PostToolUse(Write) 훅으로 실행됨
# stdin: JSON { tool_input: { file_path, content } }
# *-state.json 파일 저장 시 자동 백업 생성

set -euo pipefail

MAX_CHECKPOINTS=20

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

FILENAME=$(basename "$FILE_PATH")

# *-state.json 파일만 처리
case "$FILENAME" in
  *-state.json) ;;
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

DIR=$(dirname "$FILE_PATH")
CHECKPOINT_DIR="${DIR}/.checkpoints"

# .checkpoints 디렉토리 생성
mkdir -p "$CHECKPOINT_DIR"

# Compare with LATEST CHECKPOINT (not the current file, since PostToolUse fires after write).
# If no prior checkpoint exists OR content differs from latest checkpoint, create a new one.
LATEST_CHECKPOINT=$(ls -1 "${CHECKPOINT_DIR}/${FILENAME}".*.json 2>/dev/null | sort -t. -k2 -n | tail -1 || true)
if [[ -n "$LATEST_CHECKPOINT" && -f "$LATEST_CHECKPOINT" ]]; then
  LAST_CONTENT=$(cat "$LATEST_CHECKPOINT" 2>/dev/null || true)
  # 최신 체크포인트와 내용이 동일하면 백업 불필요 (중복 방지)
  if [[ "$LAST_CONTENT" == "$CONTENT" ]]; then
    exit 0
  fi
fi

# 다음 순번 결정
LAST_NUM=$(ls -1 "${CHECKPOINT_DIR}/${FILENAME}".*.json 2>/dev/null | sed -E "s/.*\.([0-9]+)\.json$/\1/" | sort -n | tail -1 || echo "0")
if [[ -z "$LAST_NUM" ]]; then
  LAST_NUM=0
fi
NEXT_NUM=$((LAST_NUM + 1))
PADDED_NUM=$(printf "%03d" "$NEXT_NUM")

# 체크포인트 저장: $CONTENT를 직접 저장 (PostToolUse이므로 현재 파일 = 새 내용)
echo "$CONTENT" > "${CHECKPOINT_DIR}/${FILENAME}.${PADDED_NUM}.json"

# 최대 개수 초과 시 가장 오래된 체크포인트 삭제
CHECKPOINT_COUNT=$(ls -1 "${CHECKPOINT_DIR}/${FILENAME}".*.json 2>/dev/null | wc -l | tr -d ' ')
if [[ "$CHECKPOINT_COUNT" -gt "$MAX_CHECKPOINTS" ]]; then
  DELETE_COUNT=$((CHECKPOINT_COUNT - MAX_CHECKPOINTS))
  ls -1 "${CHECKPOINT_DIR}/${FILENAME}".*.json | sort -t. -k2 -n | head -"$DELETE_COUNT" | while read -r OLD_FILE; do
    rm -f "$OLD_FILE"
  done
fi

exit 0
