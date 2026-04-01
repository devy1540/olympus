#!/usr/bin/env bash
# denial-tracking.sh — Denial tracking library
#
# DIRECT PORT from Claude Code production source:
#   src/utils/permissions/denialTracking.ts (lines 1-46)
#
# Original TypeScript:
#   export type DenialTrackingState = {
#     consecutiveDenials: number
#     totalDenials: number
#   }
#   export const DENIAL_LIMITS = { maxConsecutive: 3, maxTotal: 20 }
#   export function recordDenial(state) → { ...state, consecutiveDenials+1, totalDenials+1 }
#   export function recordSuccess(state) → { ...state, consecutiveDenials: 0 }
#   export function shouldFallbackToPrompting(state) →
#     consecutiveDenials >= 3 || totalDenials >= 20
#
# Usage: source this file, then call the functions.
# State is persisted in .olympus/.denial-tracking.json

# --- Constants (ported from DENIAL_LIMITS) ---
DENIAL_MAX_CONSECUTIVE=3
DENIAL_MAX_TOTAL=20

# --- State file location ---
denial_tracking_file() {
  echo "${OLYMPUS_STATE_DIR:-.olympus}/.denial-tracking.json"
}

# --- createDenialTrackingState() ---
denial_tracking_init() {
  local state_file
  state_file=$(denial_tracking_file)
  if [[ ! -f "$state_file" ]]; then
    echo '{"consecutiveDenials":0,"totalDenials":0}' > "$state_file"
  fi
}

# --- recordDenial(state): DenialTrackingState ---
# Ported: { ...state, consecutiveDenials: state.consecutiveDenials + 1, totalDenials: state.totalDenials + 1 }
denial_tracking_record_denial() {
  local state_file
  state_file=$(denial_tracking_file)
  denial_tracking_init

  local new_state
  new_state=$(jq '{
    consecutiveDenials: (.consecutiveDenials + 1),
    totalDenials: (.totalDenials + 1)
  }' "$state_file")

  echo "$new_state" > "$state_file"
  echo "$new_state"
}

# --- recordSuccess(state): DenialTrackingState ---
# Ported: if (state.consecutiveDenials === 0) return state; return { ...state, consecutiveDenials: 0 }
denial_tracking_record_success() {
  local state_file
  state_file=$(denial_tracking_file)
  denial_tracking_init

  local current
  current=$(jq -r '.consecutiveDenials' "$state_file")

  # Early return optimization (same as CC: returns same reference if already 0)
  if [[ "$current" == "0" ]]; then
    cat "$state_file"
    return
  fi

  local new_state
  new_state=$(jq '.consecutiveDenials = 0' "$state_file")
  echo "$new_state" > "$state_file"
  echo "$new_state"
}

# --- shouldFallbackToPrompting(state): boolean ---
# Ported: state.consecutiveDenials >= DENIAL_LIMITS.maxConsecutive || state.totalDenials >= DENIAL_LIMITS.maxTotal
denial_tracking_should_escalate() {
  local state_file
  state_file=$(denial_tracking_file)
  denial_tracking_init

  local consecutive total
  consecutive=$(jq -r '.consecutiveDenials' "$state_file")
  total=$(jq -r '.totalDenials' "$state_file")

  if [[ "$consecutive" -ge "$DENIAL_MAX_CONSECUTIVE" ]] || [[ "$total" -ge "$DENIAL_MAX_TOTAL" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# --- Read current state ---
denial_tracking_get_state() {
  local state_file
  state_file=$(denial_tracking_file)
  denial_tracking_init
  cat "$state_file"
}
