#!/usr/bin/env bash
# compact-context.sh — Auto-compaction trigger on phase transitions
# Runs as a PostToolUse(Write) hook
# stdin: JSON { tool_input: { file_path, content } }
#
# When odyssey-state.json phase changes, injects compaction instructions
# per context-management.md into additionalContext.
#
# DERIVATION: Ported from Claude Code's auto-compact trigger logic:
#   src/services/compact/autoCompact.ts — shouldAutoCompact() decides WHEN
#   src/query.ts — compaction is injected between iterations
#
# In olympus, phase transitions are the compaction trigger points
# (equivalent to Claude Code's token-threshold trigger).

set -euo pipefail

emit_allow_with_context() {
  local context="$1"
  jq -n --arg ctx "$context" \
    '{ behavior: "allow", additionalContext: $ctx, decisionReason: { type: "other", reason: "auto-compact" } }'
}

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

FILENAME=$(basename "$FILE_PATH")

# Only trigger on odyssey-state.json phase transitions
if [[ "$FILENAME" != "odyssey-state.json" ]]; then
  exit 0
fi

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

# Read previous phase from checkpoint
DIR=$(dirname "$FILE_PATH")
CHECKPOINT_DIR="${DIR}/.checkpoints"
PREV_PHASE=""

if [[ -d "$CHECKPOINT_DIR" ]]; then
  LATEST_CHECKPOINT=$(ls -1 "${CHECKPOINT_DIR}/${FILENAME}".*.json 2>/dev/null | sort -V | tail -1 || true)
  if [[ -n "$LATEST_CHECKPOINT" && -f "$LATEST_CHECKPOINT" ]]; then
    PREV_PHASE=$(jq -r '.phase // empty' "$LATEST_CHECKPOINT" 2>/dev/null || true)
  fi
fi

# No transition detected (same phase or first write)
if [[ -z "$PREV_PHASE" || "$PREV_PHASE" == "$CURRENT_PHASE" ]]; then
  exit 0
fi

# --- Phase transition detected: inject compaction instructions ---
# Compaction actions ported from context-management.md per-skill table

COMPACT_MSG=""

case "${PREV_PHASE}→${CURRENT_PHASE}" in
  "oracle→genesis"|"oracle→pantheon")
    COMPACT_MSG="CONTEXT COMPACTION: Oracle -> ${CURRENT_PHASE} transition. Summarize interview-log.md to key decisions only. Drop full Q&A history from active context. Full artifact remains on disk for Read access."
    ;;
  "genesis→pantheon")
    COMPACT_MSG="CONTEXT COMPACTION: Genesis -> Pantheon transition. Carry only the final gen-{n}/spec.md. Drop intermediate generation snapshots from active context. Full lineage remains on disk."
    ;;
  "pantheon→planning")
    COMPACT_MSG="CONTEXT COMPACTION: Pantheon -> Planning transition. Summarize analysis.md to recommendations and key findings only. Drop per-perspective details and DA challenge history from active context."
    ;;
  "planning→execution")
    # plan.md is already compact; no action needed
    ;;
  "execution→tribunal")
    COMPACT_MSG="CONTEXT COMPACTION: Execution -> Tribunal transition. Summarize implementation changes to: files modified, files created, key modifications. Drop build/debug iteration history from active context."
    ;;
  "tribunal→execution")
    COMPACT_MSG="CONTEXT COMPACTION: Tribunal -> Execution retry. Prune prior verdict details. Carry only: failure reasons, unmet ACs, and recommended fix direction. This is retry #$(echo "$CONTENT" | jq -r '.retryTracking.evaluationPass // .evaluationPass // "?"')."
    ;;
  "tribunal→completed")
    # Terminal state; no compaction needed
    ;;
  "tribunal→oracle")
    COMPACT_MSG="CONTEXT COMPACTION: Tribunal -> Oracle rewind (REJECTED_SPEC). Drop all implementation/execution history. Carry only: rejection reason, unmet ACs, and spec defects to fix. Restart Oracle with clear focus on identified gaps."
    ;;
  "tribunal→pantheon")
    COMPACT_MSG="CONTEXT COMPACTION: Tribunal -> Pantheon rewind (REJECTED_ARCHITECTURE). Drop all implementation/execution history. Carry only: rejection reason, architectural issues, and analysis gaps to address. Restart Pantheon with architectural focus."
    ;;
esac

# --- Phase timing reminder ---
# Append timing instruction to compaction message on every phase transition
TIMING_MSG="PHASE TIMING: Record completedAt for '${PREV_PHASE}' and startedAt for '${CURRENT_PHASE}' in odyssey-state.json phaseTimings."

if [[ -n "$COMPACT_MSG" ]]; then
  emit_allow_with_context "${COMPACT_MSG} ${TIMING_MSG}"
  exit 0
fi

# Phase transition detected but no compaction needed — still emit timing reminder
emit_allow_with_context "$TIMING_MSG"
exit 0
