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

# Test: olympus file NOT in contracts → allow (unknown files not enforced)
test_hook "enforce-perm" "$SCRIPT_DIR/enforce-permissions.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/not-in-contracts.md\",\"content\":\"custom file\"}}" \
  "allow" "Olympus file not in artifact-contracts.json → allow (not enforced)"

# Test: orchestrator-written file → silent (allow)
test_hook "enforce-perm" "$SCRIPT_DIR/enforce-permissions.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/spec.md\",\"content\":\"# Spec\"}}" \
  "allow" "Orchestrator-written artifact passes"

# Test: genesis gen-{n}/ path pattern → writer is orchestrator → allow
GENESIS_ARTIFACT_DIR="${TEST_DIR}/.olympus/genesis-20260401-test5678/gen-1"
mkdir -p "$GENESIS_ARTIFACT_DIR"
test_hook "enforce-perm" "$SCRIPT_DIR/enforce-permissions.sh" \
  "{\"tool_input\":{\"file_path\":\"${GENESIS_ARTIFACT_DIR}/wonder.md\",\"content\":\"wonder\"}}" \
  "allow" "Genesis gen-{n}/ pattern resolves to orchestrator writer → allow"

# Test: full-permission agent (zeus) as contract writer → allow
ODYSSEY_ARTIFACT_DIR="${TEST_DIR}/.olympus/odyssey-20260401-test9012"
mkdir -p "$ODYSSEY_ARTIFACT_DIR"
test_hook "enforce-perm" "$SCRIPT_DIR/enforce-permissions.sh" \
  "{\"tool_input\":{\"file_path\":\"${ODYSSEY_ARTIFACT_DIR}/plan.md\",\"content\":\"plan\"}}" \
  "allow" "Full-permission agent (zeus) as contract writer → allow"

# Test: read-only agent as contract writer → deny
# Inject a test contract entry with athena (read-only) as writer
TEMP_PLUGIN_ROOT=$(mktemp -d)
mkdir -p "${TEMP_PLUGIN_ROOT}/docs/shared"
jq '.oracle["readonly-test.md"] = {"phase": 99, "writer": "athena", "readers": ["all"]}' \
  "${CLAUDE_PLUGIN_ROOT}/docs/shared/artifact-contracts.json" \
  > "${TEMP_PLUGIN_ROOT}/docs/shared/artifact-contracts.json"
cp "${CLAUDE_PLUGIN_ROOT}/docs/shared/agent-schema.json" "${TEMP_PLUGIN_ROOT}/docs/shared/"
ORACLE_PERM_DIR="${TEST_DIR}/.olympus/oracle-20260401-permtest"
mkdir -p "$ORACLE_PERM_DIR"
ORIG_PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT"
export CLAUDE_PLUGIN_ROOT="$TEMP_PLUGIN_ROOT"
test_hook "enforce-perm" "$SCRIPT_DIR/enforce-permissions.sh" \
  "{\"tool_input\":{\"file_path\":\"${ORACLE_PERM_DIR}/readonly-test.md\",\"content\":\"test\"}}" \
  "deny" "Read-only agent (athena) as contract writer → deny"
export CLAUDE_PLUGIN_ROOT="$ORIG_PLUGIN_ROOT"
rm -rf "$TEMP_PLUGIN_ROOT"
# Reset consecutive denial count so downstream deny tests don't escalate to ask
source "$SCRIPT_DIR/lib/denial-tracking.sh"
denial_tracking_record_success > /dev/null 2>&1

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

# Test: ambiguity at exact boundary (0.8 clarity → 0.2 ambiguity) → allow
echo '{"interview_round":1}' > "${ARTIFACT_DIR}/interview-log.md"
echo "## Round 1" >> "${ARTIFACT_DIR}/interview-log.md"
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/ambiguity-scores.json\",\"content\":\"{\\\"goal\\\":0.8,\\\"constraints\\\":0.8,\\\"ac\\\":0.8}\"}}" \
  "allow" "Ambiguity 0.2 (at boundary) → allow"

# Test: ambiguity just above threshold (0.79 clarity → 0.21 ambiguity) → deny
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/ambiguity-scores.json\",\"content\":\"{\\\"goal\\\":0.79,\\\"constraints\\\":0.79,\\\"ac\\\":0.79}\"}}" \
  "deny" "Ambiguity 0.21 (just above 0.2 threshold) → deny"

# Test: ambiguity-scores.json missing required fields → evidence warning (allow)
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/ambiguity-scores.json\",\"content\":\"{\\\"rounds\\\":3}\"}}" \
  "allow" "Ambiguity-scores missing goal/constraints/ac → evidence warning (allow)"

# Test: ambiguity score pass (high clarity = low ambiguity)
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

# Test: ambiguity round-count inconsistency (rounds=5 in scores, 1 in log) → warning
# interview-log.md has 1 Round heading, but rounds=5 in scores → diff > 2 → warning
echo '## Round 1' > "${ARTIFACT_DIR}/interview-log.md"
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/ambiguity-scores.json\",\"content\":\"{\\\"goal\\\":0.9,\\\"constraints\\\":0.9,\\\"ac\\\":0.9,\\\"rounds\\\":5}\"}}" \
  "allow" "Ambiguity rounds=5 in scores but 1 in log (diff>2) → evidence warning (allow)"

# Test: ambiguity round-count within tolerance (rounds=2, log=1) → allow
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/ambiguity-scores.json\",\"content\":\"{\\\"goal\\\":0.9,\\\"constraints\\\":0.9,\\\"ac\\\":0.9,\\\"rounds\\\":2}\"}}" \
  "allow" "Ambiguity rounds=2 in scores, 1 in log (diff<=2) → allow"

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

# Test: mechanical-result.json with SKIP stages but overall PASS → allow (optional stage skipped)
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/mechanical-result.json\",\"content\":\"{\\\"overall\\\":\\\"PASS\\\",\\\"results\\\":{\\\"build\\\":{\\\"status\\\":\\\"PASS\\\"},\\\"typecheck\\\":{\\\"status\\\":\\\"SKIP\\\"},\\\"test\\\":{\\\"status\\\":\\\"PASS\\\"}}}\"}}" \
  "allow" "Mechanical result: SKIP stage with overall PASS → allow"

# Test: consensus-record.json missing percentage field → evidence warning (allow)
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/consensus-record.json\",\"content\":\"{\\\"level\\\":\\\"working\\\",\\\"votes\\\":{\\\"ares\\\":\\\"APPROVE\\\"}}\"}}" \
  "allow" "Consensus-record missing percentage field → evidence warning (allow)"

# Test: consensus-record.json above threshold → allow
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/consensus-record.json\",\"content\":\"{\\\"level\\\":\\\"working\\\",\\\"percentage\\\":0.6667}\"}}" \
  "allow" "Consensus record 0.6667 (2/3) → allow"

# Test: consensus-record.json at exact threshold (0.66) → allow
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/consensus-record.json\",\"content\":\"{\\\"level\\\":\\\"working\\\",\\\"percentage\\\":0.66}\"}}" \
  "allow" "Consensus record 0.66 (at boundary) → allow"

# Test: consensus-record.json just below threshold (0.659) → deny
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/consensus-record.json\",\"content\":\"{\\\"level\\\":\\\"partial\\\",\\\"percentage\\\":0.659}\"}}" \
  "deny" "Consensus record 0.659 (below 0.66) → deny"

# Test: consensus-record.json below threshold → deny
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/consensus-record.json\",\"content\":\"{\\\"level\\\":\\\"partial\\\",\\\"percentage\\\":0.5}\"}}" \
  "deny" "Consensus record 0.5 < 0.66 → deny"

# Test: consensus-record.json with consensus_pct field (tribunal format) → deny below threshold
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/consensus-record.json\",\"content\":\"{\\\"votes\\\":{\\\"ares\\\":\\\"APPROVE\\\",\\\"eris\\\":\\\"REJECT\\\",\\\"hera\\\":\\\"REJECT\\\"},\\\"consensus_pct\\\":0.33}\"}}" \
  "deny" "Consensus record using consensus_pct field (0.33) → deny"

# Test: convergence.json above threshold → allow
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/convergence.json\",\"content\":\"{\\\"similarity\\\":0.97,\\\"converged\\\":true}\"}}" \
  "allow" "Convergence 0.97 >= 0.95 → allow"

# Test: convergence.json below threshold → deny
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/convergence.json\",\"content\":\"{\\\"similarity\\\":0.8,\\\"converged\\\":false}\"}}" \
  "deny" "Convergence 0.8 < 0.95 → deny"

# Test: convergence.json exactly at threshold (0.95) → allow (boundary)
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/convergence.json\",\"content\":\"{\\\"similarity\\\":0.95,\\\"converged\\\":true}\"}}" \
  "allow" "Convergence exactly 0.95 (at boundary) → allow"

# Test: convergence.json just below threshold (0.94) → deny
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/convergence.json\",\"content\":\"{\\\"similarity\\\":0.94,\\\"converged\\\":false}\"}}" \
  "deny" "Convergence 0.94 (just below 0.95) → deny"

# Test: convergence.json missing similarity field → evidence warning (allow)
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/convergence.json\",\"content\":\"{\\\"generation\\\":1,\\\"converged\\\":false}\"}}" \
  "allow" "Convergence.json missing similarity field → evidence warning (allow)"

# Test: evolve-state.json overall pass + all dims pass → allow
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/evolve-state.json\",\"content\":\"{\\\"overall\\\":0.85,\\\"scores\\\":{\\\"specificity\\\":0.8,\\\"evidence\\\":0.75,\\\"efficiency\\\":0.9}}\"}}" \
  "allow" "Evolve-state overall 0.85 + dims all >= 0.6 → allow"

# Test: evolve-state.json overall below threshold → deny
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/evolve-state.json\",\"content\":\"{\\\"overall\\\":0.7,\\\"scores\\\":{\\\"specificity\\\":0.8,\\\"evidence\\\":0.75,\\\"efficiency\\\":0.9}}\"}}" \
  "deny" "Evolve-state overall 0.7 < 0.8 threshold → deny"

# Test: evolve-state.json overall pass but one dim below min → warning (allow with context)
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/evolve-state.json\",\"content\":\"{\\\"overall\\\":0.85,\\\"scores\\\":{\\\"specificity\\\":0.8,\\\"evidence\\\":0.5,\\\"efficiency\\\":0.9}}\"}}" \
  "allow" "Evolve-state dim below 0.6 → warning allow"

# Test: evolve-state.json overall exactly at threshold (0.8) → allow (boundary)
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/evolve-state.json\",\"content\":\"{\\\"overall\\\":0.8,\\\"scores\\\":{\\\"specificity\\\":0.8,\\\"evidence\\\":0.75,\\\"efficiency\\\":0.9}}\"}}" \
  "allow" "Evolve-state overall exactly 0.8 (at boundary) → allow"

# Test: evolve-state.json overall just below threshold (0.79) → deny
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/evolve-state.json\",\"content\":\"{\\\"overall\\\":0.79,\\\"scores\\\":{\\\"specificity\\\":0.8,\\\"evidence\\\":0.75,\\\"efficiency\\\":0.9}}\"}}" \
  "deny" "Evolve-state overall 0.79 (just below 0.8) → deny"

# Test: evolve-state.json dim exactly at minimum (0.6) → allow (boundary)
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/evolve-state.json\",\"content\":\"{\\\"overall\\\":0.85,\\\"scores\\\":{\\\"specificity\\\":0.8,\\\"evidence\\\":0.6,\\\"efficiency\\\":0.9}}\"}}" \
  "allow" "Evolve-state dim exactly at 0.6 minimum → allow (boundary)"

# Test: semantic-matrix.md without mechanical-result.json → evidence warning
SEMANTIC_DIR=$(mktemp -d)/.olympus/tribunal-20260401-sem
mkdir -p "$SEMANTIC_DIR"
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${SEMANTIC_DIR}/semantic-matrix.md\",\"content\":\"# Semantic Matrix\n## AC1: PASS\"}}" \
  "allow" "semantic-matrix.md without mechanical-result.json → evidence warning (allow)"

# Test: semantic-matrix.md with FAIL mechanical → deny precondition
echo '{"overall":"FAIL","results":{"build":{"status":"FAIL"}}}' > "${SEMANTIC_DIR}/mechanical-result.json"
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${SEMANTIC_DIR}/semantic-matrix.md\",\"content\":\"# Semantic Matrix\n## AC1: PASS\"}}" \
  "deny" "semantic-matrix.md with FAIL mechanical-result.json → deny precondition"

# Test: semantic-matrix.md with PASS mechanical but no file:line refs → evidence warning
echo '{"overall":"PASS","results":{"build":{"status":"PASS"}}}' > "${SEMANTIC_DIR}/mechanical-result.json"
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${SEMANTIC_DIR}/semantic-matrix.md\",\"content\":\"# Semantic Matrix\n## AC1: PASS — implementation verified\"}}" \
  "allow" "semantic-matrix.md with PASS mechanical but no file:line refs → evidence warning (allow)"

# Test: semantic-matrix.md with PASS mechanical and valid file:line refs → allow
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${SEMANTIC_DIR}/semantic-matrix.md\",\"content\":\"# Semantic Matrix\n## AC1: PASS — src/auth.ts:42 validates token\"}}" \
  "allow" "semantic-matrix.md with PASS mechanical and file:line ref → allow"
rm -rf "$(dirname "$SEMANTIC_DIR")"

# Test: verdict.md without spec.md → evidence warning
VERDICT_DIR=$(mktemp -d)/.olympus/tribunal-20260401-verdict
mkdir -p "$VERDICT_DIR"
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${VERDICT_DIR}/verdict.md\",\"content\":\"# Verdict\n## Final: APPROVED\"}}" \
  "allow" "verdict.md without spec.md → evidence warning (allow)"

# Test: verdict.md with spec.md present → allow (no warning)
echo "# Spec" > "${VERDICT_DIR}/spec.md"
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${VERDICT_DIR}/verdict.md\",\"content\":\"# Verdict\n## Final: APPROVED\"}}" \
  "allow" "verdict.md with spec.md present → allow"
rm -f "${VERDICT_DIR}/spec.md"

# Test: verdict.md with spec-context.md present → allow (review-pr without --spec)
REVIEWPR_VERDICT_DIR=$(mktemp -d)/.olympus/review-pr-20260401-verdict
mkdir -p "$REVIEWPR_VERDICT_DIR"
echo "# Spec Context" > "${REVIEWPR_VERDICT_DIR}/spec-context.md"
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${REVIEWPR_VERDICT_DIR}/verdict.md\",\"content\":\"# PR Verdict\n## Decision: REQUEST_CHANGES\"}}" \
  "allow" "verdict.md with spec-context.md present → allow (review-pr pattern)"
rm -rf "$(dirname "$REVIEWPR_VERDICT_DIR")"
rm -rf "$(dirname "$VERDICT_DIR")"

# Test: non-gate file → silent
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/random.txt\",\"content\":\"hello\"}}" \
  "allow" "Non-gate file → allow"

# Test: Edit context (no content field) — file has failing ambiguity → deny via file read
echo '{"goal":0.5,"constraints":0.5,"ac":0.5}' > "${ARTIFACT_DIR}/ambiguity-scores.json"
test_hook "validate-gate" "$SCRIPT_DIR/validate-gate.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/ambiguity-scores.json\",\"old_string\":\"0.9\",\"new_string\":\"0.5\"}}" \
  "deny" "Edit context (no content): reads file with failing ambiguity → deny"
rm -f "${ARTIFACT_DIR}/ambiguity-scores.json"

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

# Test: consecutiveDebugFailures > maxDebugCycles → deny
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"execution\\\",\\\"retryTracking\\\":{\\\"consecutiveDebugFailures\\\":4,\\\"maxDebugCycles\\\":3}}\"}}" \
  "deny" "consecutiveDebugFailures > maxDebugCycles → deny"

# Test: consecutiveDebugFailures == maxDebugCycles → allow (boundary: exactly at limit is ok)
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"execution\\\",\\\"retryTracking\\\":{\\\"consecutiveDebugFailures\\\":3,\\\"maxDebugCycles\\\":3}}\"}}" \
  "allow" "consecutiveDebugFailures == maxDebugCycles boundary → allow"

# Test: Terminal rewind — tribunal→oracle via returnToPhase
echo '{"phase":"tribunal"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.1.json"
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"oracle\\\",\\\"transition\\\":{\\\"status\\\":\\\"terminal\\\",\\\"reason\\\":\\\"rejected\\\",\\\"returnToPhase\\\":\\\"oracle\\\"}}\"}}" \
  "allow" "Terminal rewind tribunal→oracle via returnToPhase → allow"
rm -f "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.1.json"

# Test: Terminal rewind — tribunal→pantheon via returnToPhase (REJECTED_ARCHITECTURE)
echo '{"phase":"tribunal"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.1.json"
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"pantheon\\\",\\\"transition\\\":{\\\"status\\\":\\\"terminal\\\",\\\"reason\\\":\\\"rejected\\\",\\\"returnToPhase\\\":\\\"pantheon\\\"}}\"}}" \
  "allow" "Terminal rewind tribunal→pantheon via returnToPhase (REJECTED_ARCHITECTURE) → allow"
rm -f "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.1.json"

# Test: completed → oracle (invalid - completed is terminal) → deny
echo '{"phase":"completed"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.1.json"
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"oracle\\\"}\"}}" \
  "deny" "completed→oracle (completed is terminal) → deny"
rm -f "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.1.json"

# Test: same phase (oracle→oracle state update) → allow
echo '{"phase":"oracle"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.1.json"
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"oracle\\\"}\"}}" \
  "allow" "oracle→oracle (same phase state update) → allow"
rm -f "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.1.json"

# Test: execution phase with themisVerdict=APPROVE → allow
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh"   "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"execution\\\",\\\"gates\\\":{\\\"themisVerdict\\\":\\\"APPROVE\\\"}}\"}}"  "allow" "execution phase with APPROVE themisVerdict → allow"

# Test: execution phase with themisVerdict=REVISE → deny
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh"   "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"execution\\\",\\\"gates\\\":{\\\"themisVerdict\\\":\\\"REVISE\\\"}}\"}}"  "deny" "execution phase with REVISE themisVerdict → deny"

# Test: Edit context (no content field) — file has invalid phase → deny via file read
echo '{"phase":"not_a_phase"}' > "${ARTIFACT_DIR}/odyssey-state.json"
test_hook "validate-state" "$SCRIPT_DIR/validate-state.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"old_string\":\"oracle\",\"new_string\":\"not_a_phase\"}}" \
  "deny" "Edit context (no content): reads file with invalid phase → deny"
rm -f "${ARTIFACT_DIR}/odyssey-state.json"

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

# Test: hera-like agent (write permission: Edit disallowed, Write allowed) → allow
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/agents/hera.md\",\"content\":\"---\nname: hera\ndescription: Verifier agent\nmodel: sonnet\ndisallowedTools:\n  - Edit\n---\n# Hera\"}}" \
  "allow" "Write-level agent (hera) with correct disallowedTools=[Edit] → allow"

# Test: write-level agent incorrectly including Write in disallowedTools → allow with warning
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/agents/hera.md\",\"content\":\"---\nname: hera\ndescription: Verifier agent\nmodel: sonnet\ndisallowedTools:\n  - Write\n  - Edit\n---\n# Hera\"}}" \
  "allow" "Write-level agent (hera) with Write in disallowedTools → allow (warning)"

# Test: maxTurns within valid range → allow
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/agents/good.md\",\"content\":\"---\nname: good\ndescription: Good agent\nmodel: sonnet\ndisallowedTools: []\nmaxTurns: 20\n---\n# Good\"}}" \
  "allow" "maxTurns: 20 (valid range 1-50) → allow"

# Test: maxTurns too high → deny
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/agents/toomany.md\",\"content\":\"---\nname: toomany\ndescription: Too many turns\nmodel: haiku\ndisallowedTools: []\nmaxTurns: 100\n---\n# TooMany\"}}" \
  "deny" "maxTurns: 100 (exceeds maximum 50) → deny"

# Test: maxTurns 0 (below minimum 1) → deny
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/agents/zero.md\",\"content\":\"---\nname: zero\ndescription: Zero turns\nmodel: haiku\ndisallowedTools: []\nmaxTurns: 0\n---\n# Zero\"}}" \
  "deny" "maxTurns: 0 (below minimum 1) → deny"

# Test: invalid disallowedTools item → deny
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/agents/badtools.md\",\"content\":\"---\nname: badtools\ndescription: Bad tools\nmodel: haiku\ndisallowedTools:\n  - Unknown\n---\n# BadTools\"}}" \
  "deny" "Invalid disallowedTools item 'Unknown' → deny"

# Test: missing disallowedTools key entirely → deny
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/agents/nodisallow.md\",\"content\":\"---\nname: nodisallow\ndescription: Missing disallowedTools\nmodel: sonnet\n---\n# NoDis\"}}" \
  "deny" "Missing disallowedTools key → deny"

# Test: Edit context (no content field) — file exists with invalid model → deny via file read
mkdir -p "${TEST_DIR}/agents"
cat > "${TEST_DIR}/agents/editme.md" << 'EDITEOF'
---
name: editme
description: Edited agent test
model: badmodel
disallowedTools: []
---
# EditMe
EDITEOF
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/agents/editme.md\",\"old_string\":\"model: opus\",\"new_string\":\"model: badmodel\"}}" \
  "deny" "Edit context (no content field): reads file, invalid model → deny"
rm -f "${TEST_DIR}/agents/editme.md"

# Test: isReadOnly: false but disallowedTools has Write+Edit → warning (allow)
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/agents/readonly-mismatch.md\",\"content\":\"---\nname: readonlymismatch\ndescription: isReadOnly false but has Write+Edit\nmodel: haiku\ndisallowedTools:\n  - Write\n  - Edit\nisReadOnly: false\n---\n# Mismatch\"}}" \
  "allow" "isReadOnly: false with Write+Edit in disallowedTools → warning (allow)"

# Test: isReadOnly: true but missing Edit from disallowedTools → warning (allow)
test_hook "validate-agents" "$SCRIPT_DIR/validate-agents.sh" \
  "{\"tool_input\":{\"file_path\":\"${TEST_DIR}/agents/readonly-missing-edit.md\",\"content\":\"---\nname: readonlymissingedit\ndescription: isReadOnly true but missing Edit\nmodel: haiku\ndisallowedTools:\n  - Write\nisReadOnly: true\n---\n# MissingEdit\"}}" \
  "allow" "isReadOnly: true but disallowedTools missing Edit → warning (allow)"

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

# Test: oracle→pantheon phase transition → compaction instruction
echo '{"phase":"oracle"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.001.json"
test_hook "compact-ctx" "$SCRIPT_DIR/compact-context.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"pantheon\\\"}\"}}" \
  "allow" "oracle→pantheon transition → compaction instruction"

# Test: execution→tribunal phase transition → compaction instruction
echo '{"phase":"execution"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.002.json"
test_hook "compact-ctx" "$SCRIPT_DIR/compact-context.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"tribunal\\\"}\"}}" \
  "allow" "execution→tribunal transition → compaction instruction"

# Test: pantheon→planning transition → compaction instruction
echo '{"phase":"pantheon"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.002b.json"
test_hook "compact-ctx" "$SCRIPT_DIR/compact-context.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"planning\\\"}\"}}" \
  "allow" "pantheon→planning transition → compaction instruction"

# Test: planning→execution → no compaction needed (plan.md already compact), just timing reminder
echo '{"phase":"planning"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.002c.json"
test_hook "compact-ctx" "$SCRIPT_DIR/compact-context.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"execution\\\"}\"}}" \
  "allow" "planning→execution transition → timing reminder only (no compaction)"

# Test: tribunal→execution retry → compaction instruction with retry count
echo '{"phase":"tribunal"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.002d.json"
test_hook "compact-ctx" "$SCRIPT_DIR/compact-context.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"execution\\\",\\\"retryTracking\\\":{\\\"evaluationPass\\\":2}}\"}}" \
  "allow" "tribunal→execution retry → compaction instruction with retry count"

# Test: tribunal→completed (terminal) → timing only, no crash
echo '{"phase":"tribunal"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.003.json"
test_hook "compact-ctx" "$SCRIPT_DIR/compact-context.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"completed\\\"}\"}}" \
  "allow" "tribunal→completed transition → allow (timing reminder)"

# Test: genesis→pantheon transition → compaction instruction
echo '{"phase":"genesis"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.003b.json"
test_hook "compact-ctx" "$SCRIPT_DIR/compact-context.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"pantheon\\\"}\"}}" \
  "allow" "genesis→pantheon transition → compaction instruction"

# Test: tribunal→oracle rewind → compaction instruction
echo '{"phase":"tribunal"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.003c.json"
test_hook "compact-ctx" "$SCRIPT_DIR/compact-context.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"oracle\\\"}\"}}" \
  "allow" "tribunal→oracle rewind → compaction instruction"

# Test: tribunal→pantheon rewind → compaction instruction
echo '{"phase":"tribunal"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.003d.json"
test_hook "compact-ctx" "$SCRIPT_DIR/compact-context.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"content\":\"{\\\"phase\\\":\\\"pantheon\\\"}\"}}" \
  "allow" "tribunal→pantheon rewind → compaction instruction"

# Test: non-state file → silent
test_hook "compact-ctx" "$SCRIPT_DIR/compact-context.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/spec.md\",\"content\":\"# Spec\"}}" \
  "allow" "Non-state file → allow"

# Test: Edit context (no content field) → reads file directly, fires on transition
echo '{"phase":"genesis"}' > "${ARTIFACT_DIR}/odyssey-state.json"
echo '{"phase":"oracle"}' > "${ARTIFACT_DIR}/.checkpoints/odyssey-state.json.004.json"
test_hook "compact-ctx" "$SCRIPT_DIR/compact-context.sh" \
  "{\"tool_input\":{\"file_path\":\"${ARTIFACT_DIR}/odyssey-state.json\",\"old_string\":\"oracle\",\"new_string\":\"genesis\"}}" \
  "allow" "Edit context (no content) → reads file directly, fires transition"

# ============================================================
echo "--- checkpoint.sh ---"
# ============================================================

CKPT_DIR="${TEST_DIR}/.olympus/ckpt-test-20260406-abc"
mkdir -p "$CKPT_DIR"
CKPT_STATE="${CKPT_DIR}/odyssey-state.json"

# Test 1: first write → checkpoint created
echo '{"phase":"genesis"}' > "$CKPT_STATE"
echo "{\"tool_input\":{\"file_path\":\"$CKPT_STATE\",\"content\":\"{\\\"phase\\\":\\\"genesis\\\"}\"}}" | bash "$SCRIPT_DIR/checkpoint.sh" > /dev/null 2>&1
TOTAL=$((TOTAL + 1))
CKPT_COUNT=$(ls "${CKPT_DIR}/.checkpoints/"*.json 2>/dev/null | wc -l | tr -d ' ')
if [[ "$CKPT_COUNT" -eq 1 ]]; then
  echo "  PASS  checkpoint: first state write creates checkpoint"
  PASS=$((PASS + 1))
else
  echo "  FAIL  checkpoint: expected 1 checkpoint after first write, got ${CKPT_COUNT}"
  FAIL=$((FAIL + 1))
fi

# Test 2: duplicate write → no new checkpoint
echo "{\"tool_input\":{\"file_path\":\"$CKPT_STATE\",\"content\":\"{\\\"phase\\\":\\\"genesis\\\"}\"}}" | bash "$SCRIPT_DIR/checkpoint.sh" > /dev/null 2>&1
TOTAL=$((TOTAL + 1))
CKPT_COUNT=$(ls "${CKPT_DIR}/.checkpoints/"*.json 2>/dev/null | wc -l | tr -d ' ')
if [[ "$CKPT_COUNT" -eq 1 ]]; then
  echo "  PASS  checkpoint: duplicate write skips checkpoint (same content)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  checkpoint: expected 1 checkpoint (no duplicate), got ${CKPT_COUNT}"
  FAIL=$((FAIL + 1))
fi

# Test 3: new content → second checkpoint
echo '{"phase":"pantheon"}' > "$CKPT_STATE"
echo "{\"tool_input\":{\"file_path\":\"$CKPT_STATE\",\"content\":\"{\\\"phase\\\":\\\"pantheon\\\"}\"}}" | bash "$SCRIPT_DIR/checkpoint.sh" > /dev/null 2>&1
TOTAL=$((TOTAL + 1))
CKPT_COUNT=$(ls "${CKPT_DIR}/.checkpoints/"*.json 2>/dev/null | wc -l | tr -d ' ')
if [[ "$CKPT_COUNT" -eq 2 ]]; then
  echo "  PASS  checkpoint: state change creates new checkpoint"
  PASS=$((PASS + 1))
else
  echo "  FAIL  checkpoint: expected 2 checkpoints after state change, got ${CKPT_COUNT}"
  FAIL=$((FAIL + 1))
fi

# Test 4: non-state file → no checkpoint created
NON_STATE="${CKPT_DIR}/spec.md"
echo "# Spec" > "$NON_STATE"
echo "{\"tool_input\":{\"file_path\":\"$NON_STATE\",\"content\":\"# New Spec\"}}" | bash "$SCRIPT_DIR/checkpoint.sh" > /dev/null 2>&1
TOTAL=$((TOTAL + 1))
SPEC_CKPT_COUNT=$(find "${CKPT_DIR}/.checkpoints" -name "spec.md*.json" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SPEC_CKPT_COUNT" -eq 0 ]]; then
  echo "  PASS  checkpoint: non-state file skipped"
  PASS=$((PASS + 1))
else
  echo "  FAIL  checkpoint: expected no checkpoint for spec.md, got ${SPEC_CKPT_COUNT}"
  FAIL=$((FAIL + 1))
fi
rm -rf "$CKPT_DIR"

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
