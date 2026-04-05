#!/usr/bin/env bash
# test-hooks.sh — Simulate hook inputs and verify all hooks work correctly
# Run: bash hooks/test-hooks.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export CLAUDE_PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0
TOTAL=0

test_hook() {
  local name="$1"
  local hook="$2"
  local input="$3"
  local expected_behavior="$4"
  local description="$5"

  TOTAL=$((TOTAL + 1))
  local output
  output=$(echo "$input" | bash "$hook" 2>/dev/null || true)

  local actual_behavior=""
  if [[ -z "$output" ]]; then
    actual_behavior="allow"
  else
    actual_behavior=$(echo "$output" | jq -r '.behavior // "text"' 2>/dev/null || echo "text")
  fi

  if [[ "$actual_behavior" == "$expected_behavior" ]]; then
    echo "  PASS  $name: $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name: $description"
    echo "        expected: $expected_behavior, got: $actual_behavior"
    if [[ -n "$output" ]]; then
      echo "        output: $(echo "$output" | head -1)"
    fi
    FAIL=$((FAIL + 1))
  fi
}

# --- Setup test fixtures ---
TEST_DIR=$(mktemp -d)
ARTIFACT_DIR="${TEST_DIR}/.olympus/oracle-20260401-test1234"
mkdir -p "$ARTIFACT_DIR"
mkdir -p "${ARTIFACT_DIR}/.checkpoints"
export OLYMPUS_STATE_DIR="$TEST_DIR/.olympus"

echo ""
echo "=== Olympus Hook Test Suite ==="
echo ""

# ============================================================
echo "--- enforce-permissions.sh ---"
# ============================================================

# Test: non-olympus file → silent (allow)
test_hook "enforce-perm" "$SCRIPT_DIR/enforce-permissions.sh" \
  '{"tool_input":{"file_path":"/tmp/random.txt","content":"hello"}}' \
  "allow" "Non-.olympus file passes through"

# Test: orchestrator-written file → silent (allow)
test_hook "enforce-perm" "$SCRIPT_DIR/enforce-permissions.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/spec.md\",\"content\":\"# Spec\"}}" \
  "allow" "Orchestrator-written artifact passes"

# ============================================================
echo "--- verify-artifacts.sh ---"
# ============================================================

# Test: non-olympus file → silent
test_hook "verify-art" "$SCRIPT_DIR/verify-artifacts.sh" \
  '{"tool_input":{"file_path":"/tmp/random.txt","content":"hello"}}' \
  "allow" "Non-.olympus file passes through"

# Test: spec.md (phase 5) without predecessor artifacts → warning
test_hook "verify-art" "$SCRIPT_DIR/verify-artifacts.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/spec.md\",\"content\":\"# Spec\"}}" \
  "allow" "spec.md without predecessors emits warning"

# Test: codebase-context.md (phase 1, no predecessors) → silent
test_hook "verify-art" "$SCRIPT_DIR/verify-artifacts.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/codebase-context.md\",\"content\":\"# Context\"}}" \
  "allow" "Phase 1 artifact with no predecessors passes"

# Test: DA mandatory — analysis.md without da-evaluation.md → warning
PANTHEON_DIR=$(mktemp -d)/pantheon-test/.olympus/pantheon-20260404-test
mkdir -p "$PANTHEON_DIR"
test_hook "verify-art" "$SCRIPT_DIR/verify-artifacts.sh" \
  "{\"tool_input\":{\"file_path\":\"${PANTHEON_DIR}/analysis.md\",\"content\":\"# Analysis\"}}" \
  "allow" "Pantheon analysis.md without da-evaluation.md → DA warning"
rm -rf "$(dirname "$(dirname "$(dirname "$PANTHEON_DIR")")")"

# Test: DA mandatory — review-pr verdict.md without da-evaluation.md → warning
REVIEW_PR_DIR=$(mktemp -d)/.olympus/review-pr-20260404-test
mkdir -p "$REVIEW_PR_DIR"
test_hook "verify-art" "$SCRIPT_DIR/verify-artifacts.sh" \
  "{\"tool_input\":{\"file_path\":\"${REVIEW_PR_DIR}/verdict.md\",\"content\":\"# Verdict\"}}" \
  "allow" "review-pr verdict.md without da-evaluation.md → DA warning"
rm -rf "$(dirname "$REVIEW_PR_DIR")" 

# ============================================================
echo "--- enforce-spawn-gate.sh ---"
# ============================================================

# Test: non-olympus file → allow (bypass)
test_hook "spawn-gate" "$SCRIPT_DIR/enforce-spawn-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"/tmp/random.txt\",\"content\":\"hello\"}}" \
  "allow" "Non-olympus file → allow"

# Test: olympus file without required_spawn → allow
test_hook "spawn-gate" "$SCRIPT_DIR/enforce-spawn-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/spec.md\",\"content\":\"# Spec\"}}" \
  "allow" "Oracle spec.md (no required_spawn) → allow"

# Test: file with required_spawn, agent not spawned → deny
EVOLVE_DIR="${TEST_DIR}/.olympus/evolve-20260401-test1234"
mkdir -p "$EVOLVE_DIR"
test_hook "spawn-gate" "$SCRIPT_DIR/enforce-spawn-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${EVOLVE_DIR}/eval-matrix.md\",\"content\":\"# Eval\"}}" \
  "deny" "Evolve eval-matrix.md (athena not spawned) → deny"

# Test: oracle interview-log with required_spawn, agent not spawned → deny
test_hook "spawn-gate" "$SCRIPT_DIR/enforce-spawn-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/interview-log.md\",\"content\":\"# Log\"}}" \
  "deny" "Oracle interview-log (apollo not spawned) → deny"

# ============================================================
echo "--- validate-gate.sh ---"
# ============================================================

# Test: ambiguity score violation
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/ambiguity-scores.json\",\"content\":\"{\\\"goal\\\":0.3,\\\"constraints\\\":0.4,\\\"ac\\\":0.5}\"}}" \
  "deny" "Ambiguity score violation (high ambiguity) → deny"

# Test: ambiguity score pass (high clarity = low ambiguity)
echo '{"interview_round":1}' > "${ARTIFACT_DIR}/interview-log.md"
echo "## Round 1" >> "${ARTIFACT_DIR}/interview-log.md"
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/ambiguity-scores.json\",\"content\":\"{\\\"goal\\\":0.9,\\\"constraints\\\":0.9,\\\"ac\\\":0.9}\"}}" \
  "allow" "Ambiguity score pass (high clarity) → allow"

# Test: ambiguity without interview-log → evidence warning
rm -f "${ARTIFACT_DIR}/interview-log.md"
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/ambiguity-scores.json\",\"content\":\"{\\\"goal\\\":0.9,\\\"constraints\\\":0.9,\\\"ac\\\":0.9}\"}}" \
  "allow" "Ambiguity pass but no interview-log → evidence warning"

# Test: suspiciously low ambiguity on complex project → calibration warning
echo '## Round 1' > "${ARTIFACT_DIR}/interview-log.md"
# Create a 60-line codebase-context.md to simulate complex project
printf '# Context\n%.0s' {1..60} > "${ARTIFACT_DIR}/codebase-context.md"
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/ambiguity-scores.json\",\"content\":\"{\\\"goal\\\":0.95,\\\"constraints\\\":0.95,\\\"ac\\\":0.95}\"}}" \
  "allow" "Suspiciously low ambiguity on complex project → calibration warning"
rm -f "${ARTIFACT_DIR}/codebase-context.md"

# Test: mechanical-result.json all pass → silent
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/mechanical-result.json\",\"content\":\"{\\\"results\\\":{\\\"build\\\":{\\\"status\\\":\\\"PASS\\\"},\\\"test\\\":{\\\"status\\\":\\\"PASS\\\"}},\\\"overall\\\":\\\"PASS\\\"}\"}}" \
  "allow" "Mechanical result all PASS → allow"

# Test: mechanical-result.json with failure → deny
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/mechanical-result.json\",\"content\":\"{\\\"results\\\":{\\\"build\\\":{\\\"status\\\":\\\"FAIL\\\",\\\"stage\\\":\\\"build\\\"}},\\\"overall\\\":\\\"FAIL\\\"}\"}}" \
  "deny" "Mechanical result FAIL → deny"

# Test: mechanical-result.json FAIL without stage field → deny (stage key from results key, not .stage)
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/mechanical-result.json\",\"content\":\"{\\\"results\\\":{\\\"lint\\\":{\\\"status\\\":\\\"FAIL\\\"}},\\\"overall\\\":\\\"FAIL\\\"}\"}}" \
  "deny" "Mechanical result FAIL (no .stage field) → deny with correct stage name"

# Test: mechanical-result.json ENV_UNAVAILABLE → allow (no build system is valid)
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/mechanical-result.json\",\"content\":\"{\\\"overall\\\":\\\"ENV_UNAVAILABLE\\\",\\\"results\\\":{\\\"build\\\":{\\\"status\\\":\\\"SKIP\\\"},\\\"test\\\":{\\\"status\\\":\\\"SKIP\\\"}}}\"}}" \
  "allow" "Mechanical result ENV_UNAVAILABLE → allow"

# Test: consensus-record.json above threshold → allow
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/consensus-record.json\",\"content\":\"{\\\"level\\\":\\\"working\\\",\\\"percentage\\\":0.6667}\"}}" \
  "allow" "Consensus record 0.6667 (2/3) → allow"

# Test: consensus-record.json below threshold → deny
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/consensus-record.json\",\"content\":\"{\\\"level\\\":\\\"partial\\\",\\\"percentage\\\":0.5}\"}}" \
  "deny" "Consensus record 0.5 < 0.66 → deny"

# Test: convergence.json above threshold → allow
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/convergence.json\",\"content\":\"{\\\"similarity\\\":0.97,\\\"converged\\\":true}\"}}" \
  "allow" "Convergence 0.97 >= 0.95 → allow"

# Test: convergence.json below threshold → deny
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/convergence.json\",\"content\":\"{\\\"similarity\\\":0.8,\\\"converged\\\":false}\"}}" \
  "deny" "Convergence 0.8 < 0.95 → deny"

# Test: non-gate file → silent
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/random.txt\",\"content\":\"hello\"}}" \
  "allow" "Non-gate file → allow"

# ============================================================
echo "--- validate-state.sh ---"
# ============================================================

# Test: valid odyssey phase
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"oracle\\\"}\"}}" \
  "allow" "Valid phase 'oracle' → allow"

# Test: invalid odyssey phase
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"invalid_phase\\\"}\"}}" \
  "deny" "Invalid phase → deny"

# Test: valid Terminal transition
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"completed\\\",\\\"transition\\\":{\\\"status\\\":\\\"terminal\\\",\\\"reason\\\":\\\"completed\\\"}}\"}}" \
  "allow" "Valid Terminal transition → allow"

# Test: invalid Terminal reason
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"oracle\\\",\\\"transition\\\":{\\\"status\\\":\\\"terminal\\\",\\\"reason\\\":\\\"bogus\\\"}}\"}}" \
  "deny" "Invalid Terminal reason → deny"

# Test: invalid Continue reason
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"oracle\\\",\\\"transition\\\":{\\\"status\\\":\\\"continue\\\",\\\"reason\\\":\\\"bogus\\\"}}\"}}" \
  "deny" "Invalid Continue reason → deny"

# Test: valid Continue with retry tracking
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"execution\\\",\\\"transition\\\":{\\\"status\\\":\\\"continue\\\",\\\"reason\\\":\\\"implementation_retry\\\",\\\"retryCount\\\":1,\\\"maxRetries\\\":3}}\"}}" \
  "allow" "Valid Continue with retry within limit → allow"

# Test: Continue with exceeded retries
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"execution\\\",\\\"transition\\\":{\\\"status\\\":\\\"continue\\\",\\\"reason\\\":\\\"implementation_retry\\\",\\\"retryCount\\\":5,\\\"maxRetries\\\":3}}\"}}" \
  "deny" "Continue with exceeded retries → deny"

# Test: evaluationPass > maxPasses
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"execution\\\",\\\"retryTracking\\\":{\\\"evaluationPass\\\":4,\\\"maxPasses\\\":3}}\"}}" \
  "deny" "evaluationPass > maxPasses → deny"

# Test: Terminal rewind — tribunal→oracle via returnToPhase
echo '{"phase":"tribunal"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.1.json"
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"oracle\\\",\\\"transition\\\":{\\\"status\\\":\\\"terminal\\\",\\\"reason\\\":\\\"rejected\\\",\\\"returnToPhase\\\":\\\"oracle\\\"}}\"}}" \
  "allow" "Terminal rewind tribunal→oracle via returnToPhase → allow"
rm -f "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.1.json"

# Test: execution phase with themisVerdict=APPROVE → allow
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh"   "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"execution\\\",\\\"gates\\\":{\\\"themisVerdict\\\":\\\"APPROVE\\\"}}\"}}"  "allow" "execution phase with APPROVE themisVerdict → allow"

# Test: execution phase with themisVerdict=REVISE → deny
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh"   "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"execution\\\",\\\"gates\\\":{\\\"themisVerdict\\\":\\\"REVISE\\\"}}\"}}"  "deny" "execution phase with REVISE themisVerdict → deny"

# ============================================================
echo "--- validate-agents.sh ---"
# ============================================================

# Test: valid agent file
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/agents/hermes.md\",\"content\":\"---\nname: hermes\ndescription: Explorer agent\nmodel: haiku\ndisallowedTools:\n  - Write\n  - Edit\n---\n# Hermes\"}}" \
  "allow" "Valid agent definition → allow"

# Test: missing required field
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/agents/broken.md\",\"content\":\"---\ndescription: Broken agent\nmodel: opus\ndisallowedTools: []\n---\n# Broken\"}}" \
  "deny" "Missing name field → deny"

# Test: invalid model
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/agents/bad.md\",\"content\":\"---\nname: bad\ndescription: Bad agent\nmodel: gpt4\ndisallowedTools: []\n---\n# Bad\"}}" \
  "deny" "Invalid model enum → deny"

# Test: invalid name pattern
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/agents/BadName.md\",\"content\":\"---\nname: BadName\ndescription: Bad name\nmodel: opus\ndisallowedTools: []\n---\"}}" \
  "deny" "Uppercase in name → deny"

# Test: non-agent file → silent
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/skills/oracle/SKILL.md\",\"content\":\"# Oracle\"}}" \
  "allow" "Non-agents/ file → allow"

# ============================================================
echo "--- compact-context.sh ---"
# ============================================================

# Test: no phase transition → silent
test_hook "compact-ctx" "$SCRIPT_DIR/compact-context.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"oracle\\\"}\"}}" \
  "allow" "No phase transition → allow"

# Test: phase transition with checkpoint
echo '{"phase":"oracle"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.001.json"
test_hook "compact-ctx" "$SCRIPT_DIR/compact-context.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"pantheon\\\"}\"}}" \
  "allow" "oracle→pantheon transition → compaction instruction"

# Test: non-state file → silent
test_hook "compact-ctx" "$SCRIPT_DIR/compact-context.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/spec.md\",\"content\":\"# Spec\"}}" \
  "allow" "Non-state file → allow"

# ============================================================
echo "--- denial-tracking.sh ---"
# ============================================================

source "$SCRIPT_DIR/lib/denial-tracking.sh"
export OLYMPUS_STATE_DIR="$TEST_DIR"

TOTAL=$((TOTAL + 1))
denial_tracking_init
STATE=$(denial_tracking_get_state)
CONSECUTIVE=$(echo "$STATE" | jq -r '.consecutiveDenials')
if [[ "$CONSECUTIVE" == "0" ]]; then
  echo "  PASS  denial-track: Init state has 0 consecutive denials"
  PASS=$((PASS + 1))
else
  echo "  FAIL  denial-track: Expected 0 consecutive, got $CONSECUTIVE"
  FAIL=$((FAIL + 1))
fi

TOTAL=$((TOTAL + 1))
denial_tracking_record_denial > /dev/null
denial_tracking_record_denial > /dev/null
denial_tracking_record_denial > /dev/null
SHOULD=$(denial_tracking_should_escalate)
if [[ "$SHOULD" == "true" ]]; then
  echo "  PASS  denial-track: 3 consecutive denials triggers escalation"
  PASS=$((PASS + 1))
else
  echo "  FAIL  denial-track: Expected escalation at 3 denials, got $SHOULD"
  FAIL=$((FAIL + 1))
fi

TOTAL=$((TOTAL + 1))
denial_tracking_record_success > /dev/null
SHOULD=$(denial_tracking_should_escalate)
STATE=$(denial_tracking_get_state)
CONSECUTIVE=$(echo "$STATE" | jq -r '.consecutiveDenials')
TOTAL_D=$(echo "$STATE" | jq -r '.totalDenials')
if [[ "$CONSECUTIVE" == "0" && "$TOTAL_D" == "3" ]]; then
  echo "  PASS  denial-track: Success resets consecutive but keeps total"
  PASS=$((PASS + 1))
else
  echo "  FAIL  denial-track: Expected consecutive=0, total=3, got consecutive=$CONSECUTIVE, total=$TOTAL_D"
  FAIL=$((FAIL + 1))
fi

# ============================================================
# Cleanup
rm -rf "$TEST_DIR"

echo ""
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
