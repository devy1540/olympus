#!/usr/bin/env bash
# test-integration.sh — End-to-end pipeline simulation
# Simulates Oracle → Tribunal artifact flow and verifies all hooks fire correctly
#
# This is NOT a real pipeline execution — it simulates the Write calls
# that would occur during skill execution and verifies hook responses.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export CLAUDE_PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0
TOTAL=0

# Helper to simulate a Write tool_input and run hook
# Writes content to a temp file, builds JSON with proper escaping via jq --slurpfile
run_hook() {
  local hook="$1"
  local file_path="$2"
  local content="$3"
  local tmpfile
  tmpfile=$(mktemp)
  # Write content as JSON string to temp file
  printf '%s' "$content" | jq -Rs '.' > "$tmpfile"
  # Build the full JSON input with properly escaped content
  jq -n --arg fp "$file_path" --argjson ct "$(cat "$tmpfile")" \
    '{ tool_input: { file_path: $fp, content: $ct } }' | \
    bash "$hook" 2>/dev/null || true
  rm -f "$tmpfile"
}

check_result() {
  local test_name="$1"
  local output="$2"
  local expected_behavior="$3"

  TOTAL=$((TOTAL + 1))
  local actual=""
  if [[ -z "$output" ]]; then
    actual="silent"
  else
    actual=$(echo "$output" | jq -r '.behavior // "text"' 2>/dev/null || echo "text")
  fi

  if [[ "$actual" == "$expected_behavior" ]]; then
    echo "  PASS  $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $test_name (expected=$expected_behavior, got=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

# ============================================================
echo ""
echo "=== Integration Test: Oracle → Tribunal Pipeline ==="
echo ""

# Setup
TEST_DIR=$(mktemp -d)
ORACLE_DIR="${TEST_DIR}/.olympus/oracle-20260401-inttest1"
TRIBUNAL_DIR="${TEST_DIR}/.olympus/tribunal-20260401-inttest2"
ODYSSEY_DIR="${TEST_DIR}/.olympus/odyssey-20260401-inttest3"
mkdir -p "$ORACLE_DIR/.checkpoints"
mkdir -p "$TRIBUNAL_DIR/.checkpoints"
mkdir -p "$ODYSSEY_DIR/.checkpoints"
export OLYMPUS_STATE_DIR="${TEST_DIR}/.olympus"

# ============================================================
echo "--- Phase 1: Oracle Pipeline (artifact creation order) ---"
# ============================================================

# Step 1: Hermes writes codebase-context.md (phase 1, no predecessors)
echo "  [oracle] Hermes → codebase-context.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${ORACLE_DIR}/codebase-context.md" "# Codebase Context\n## Structure\nsrc/\n  auth.ts\n  api/")
check_result "Oracle: codebase-context.md (phase 1, no predecessors)" "$RESULT" "silent"

# Step 2: Apollo writes interview-log.md (phase 2, after codebase-context)
# First check: codebase-context.md should exist as predecessor
echo "# Codebase Context" > "${ORACLE_DIR}/codebase-context.md"
echo "  [oracle] Apollo → interview-log.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${ORACLE_DIR}/interview-log.md" "## Round 1\nQ: What is the auth flow?\nA: OAuth2 with refresh tokens")
check_result "Oracle: interview-log.md (phase 2, codebase-context exists)" "$RESULT" "silent"

# Step 3: Apollo writes ambiguity-scores.json (phase 2)
echo "## Round 1" > "${ORACLE_DIR}/interview-log.md"
echo "  [oracle] Apollo → ambiguity-scores.json (passing score)"
RESULT=$(run_hook "$SCRIPT_DIR/validate-gate.sh" \
  "${ORACLE_DIR}/ambiguity-scores.json" '{"goal":0.9,"constraints":0.85,"ac":0.9,"rounds":1}')
check_result "Oracle: ambiguity gate PASS (score=0.12)" "$RESULT" "silent"

# Step 3b: What if ambiguity is too high?
echo "  [oracle] Apollo → ambiguity-scores.json (failing score)"
RESULT=$(run_hook "$SCRIPT_DIR/validate-gate.sh" \
  "${ORACLE_DIR}/ambiguity-scores.json" '{"goal":0.3,"constraints":0.4,"ac":0.3,"rounds":1}')
check_result "Oracle: ambiguity gate FAIL (score=0.66)" "$RESULT" "deny"

# Step 4: Metis writes gap-analysis.md (phase 4)
echo '{"goal":0.9,"constraints":0.85,"ac":0.9}' > "${ORACLE_DIR}/ambiguity-scores.json"
echo "  [oracle] Metis → gap-analysis.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${ORACLE_DIR}/gap-analysis.md" "# Gap Analysis\n## Missing Questions\n- Token refresh TTL")
check_result "Oracle: gap-analysis.md (phase 4, predecessors exist)" "$RESULT" "silent"

# Step 5: Orchestrator writes spec.md (phase 5)
echo "# Gap Analysis" > "${ORACLE_DIR}/gap-analysis.md"
echo "  [oracle] Orchestrator → spec.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${ORACLE_DIR}/spec.md" "# Specification: Auth Service\n## GOAL\nImplement OAuth2\n## ACCEPTANCE_CRITERIA\n1. GIVEN valid token WHEN /api/me THEN 200")
check_result "Oracle: spec.md (phase 5, all predecessors exist)" "$RESULT" "silent"

# ============================================================
echo ""
echo "--- Phase 2: Tribunal Pipeline (evaluation chain) ---"
# ============================================================

# Create spec.md in tribunal dir (in real pipeline, orchestrator writes this)
echo "# Specification: Auth Service" > "${TRIBUNAL_DIR}/spec.md"

# Step 1: Hephaestus writes mechanical-result.json (all PASS)
echo "  [tribunal] Hephaestus → mechanical-result.json (all PASS)"
MECH_PASS='{"results":{"build":{"status":"PASS"},"lint":{"status":"PASS"},"typecheck":{"status":"PASS"},"test":{"status":"PASS","passed":12,"failed":0}},"overall":"PASS"}'
RESULT=$(run_hook "$SCRIPT_DIR/validate-gate.sh" \
  "${TRIBUNAL_DIR}/mechanical-result.json" "$MECH_PASS")
check_result "Tribunal: mechanical gate PASS" "$RESULT" "silent"

# Step 1b: What if build fails?
echo "  [tribunal] Hephaestus → mechanical-result.json (build FAIL)"
MECH_FAIL='{"results":{"build":{"status":"FAIL","stage":"build"}},"overall":"FAIL"}'
RESULT=$(run_hook "$SCRIPT_DIR/validate-gate.sh" \
  "${TRIBUNAL_DIR}/mechanical-result.json" "$MECH_FAIL")
check_result "Tribunal: mechanical gate FAIL → deny" "$RESULT" "deny"

# Step 2: Athena writes semantic-matrix.md (requires mechanical PASS)
echo "$MECH_PASS" > "${TRIBUNAL_DIR}/mechanical-result.json"
echo "  [tribunal] Athena → semantic-matrix.md (with file:line refs)"
SEMANTIC_GOOD="# Semantic Matrix
| AC | Status | Evidence |
|---|---|---|
| OAuth2 flow | MET | src/auth.ts:42 |
| Token refresh | MET | src/auth.ts:89 |"
RESULT=$(run_hook "$SCRIPT_DIR/validate-gate.sh" \
  "${TRIBUNAL_DIR}/semantic-matrix.md" "$SEMANTIC_GOOD")
check_result "Tribunal: semantic-matrix.md with refs (warns about non-existent files)" "$RESULT" "allow"

# Step 2b: Semantic matrix without mechanical-result → warning
rm -f "${TRIBUNAL_DIR}/mechanical-result.json"
echo "  [tribunal] Athena → semantic-matrix.md (no mechanical-result)"
RESULT=$(run_hook "$SCRIPT_DIR/validate-gate.sh" \
  "${TRIBUNAL_DIR}/semantic-matrix.md" "$SEMANTIC_GOOD")
check_result "Tribunal: semantic-matrix without mechanical-result → warning" "$RESULT" "allow"

# Step 2c: Semantic matrix without file:line references → warning
echo "$MECH_PASS" > "${TRIBUNAL_DIR}/mechanical-result.json"
echo "  [tribunal] Athena → semantic-matrix.md (no file:line)"
SEMANTIC_BAD="All acceptance criteria have been met and the work is complete"
RESULT=$(run_hook "$SCRIPT_DIR/validate-gate.sh" \
  "${TRIBUNAL_DIR}/semantic-matrix.md" "$SEMANTIC_BAD")
check_result "Tribunal: semantic-matrix without file:line refs → warning" "$RESULT" "allow"

# Step 3: Verdict with spec.md present
echo "  [tribunal] Orchestrator → verdict.md"
RESULT=$(run_hook "$SCRIPT_DIR/validate-gate.sh" \
  "${TRIBUNAL_DIR}/verdict.md" "# Tribunal Verdict\n## Final: APPROVED")
check_result "Tribunal: verdict.md with spec.md present" "$RESULT" "silent"

# ============================================================
echo ""
echo "--- Phase 3: Odyssey State Machine ---"
# ============================================================

# Valid state transitions
echo "  [odyssey] oracle → pantheon (skip genesis)"
echo '{"phase":"oracle"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.001.json"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"pantheon","gates":{"ambiguityScore":0.15}}')
check_result "Odyssey: oracle→pantheon (valid, ambiguity passed)" "$RESULT" "silent"

# Compaction trigger on transition
echo "  [odyssey] oracle→pantheon compaction trigger"
RESULT=$(run_hook "$SCRIPT_DIR/compact-context.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"pantheon"}')
check_result "Odyssey: oracle→pantheon triggers compaction" "$RESULT" "allow"

# Invalid transition: oracle → execution (skipping phases)
echo '{"phase":"oracle"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.002.json"
echo "  [odyssey] oracle → execution (INVALID skip)"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"execution"}')
check_result "Odyssey: oracle→execution (invalid skip) → deny" "$RESULT" "deny"

# Terminal transition with valid reason
echo "  [odyssey] completed with Terminal{reason:completed}"
echo '{"phase":"tribunal"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.003.json"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"completed","transition":{"status":"terminal","reason":"completed"},"gates":{"mechanicalPass":true}}')
check_result "Odyssey: tribunal→completed with Terminal → silent" "$RESULT" "silent"

# Continue transition with retry tracking
echo "  [odyssey] execution retry with Continue"
echo '{"phase":"tribunal"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.004.json"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"execution","transition":{"status":"continue","reason":"implementation_retry","retryCount":2,"maxRetries":3}}')
check_result "Odyssey: tribunal→execution retry (within limit)" "$RESULT" "silent"

# Gate precondition: pantheon without ambiguity passed
echo '{"phase":"oracle"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.005.json"
echo "  [odyssey] oracle→pantheon without ambiguity gate"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"pantheon","gates":{"ambiguityScore":0.35}}')
check_result "Odyssey: pantheon with ambiguity 0.35 > 0.2 → deny" "$RESULT" "deny"

# ============================================================
echo ""
echo "--- Phase 4: Agent Schema Validation ---"
# ============================================================

# Test actual agent files from the project
echo "  [audit] Validate real agent: hermes.md"
HERMES_CONTENT=$(cat "${CLAUDE_PLUGIN_ROOT}/agents/hermes.md")
RESULT=$(jq -n --arg fp "${CLAUDE_PLUGIN_ROOT}/agents/hermes.md" --arg ct "$HERMES_CONTENT" \
  '{ tool_input: { file_path: $fp, content: $ct } }' | \
  bash "$SCRIPT_DIR/validate-agents.sh" 2>/dev/null || true)
check_result "Audit: hermes.md passes schema validation" "$RESULT" "silent"

echo "  [audit] Validate real agent: zeus.md"
ZEUS_CONTENT=$(cat "${CLAUDE_PLUGIN_ROOT}/agents/zeus.md")
RESULT=$(jq -n --arg fp "${CLAUDE_PLUGIN_ROOT}/agents/zeus.md" --arg ct "$ZEUS_CONTENT" \
  '{ tool_input: { file_path: $fp, content: $ct } }' | \
  bash "$SCRIPT_DIR/validate-agents.sh" 2>/dev/null || true)
check_result "Audit: zeus.md passes schema validation" "$RESULT" "silent"

echo "  [audit] Validate real agent: apollo.md"
APOLLO_CONTENT=$(cat "${CLAUDE_PLUGIN_ROOT}/agents/apollo.md")
RESULT=$(jq -n --arg fp "${CLAUDE_PLUGIN_ROOT}/agents/apollo.md" --arg ct "$APOLLO_CONTENT" \
  '{ tool_input: { file_path: $fp, content: $ct } }' | \
  bash "$SCRIPT_DIR/validate-agents.sh" 2>/dev/null || true)
check_result "Audit: apollo.md passes schema validation" "$RESULT" "silent"

# Validate ALL 14 agents in a batch
echo "  [audit] Batch validate all 14 agents"
AGENT_FAILURES=""
for agent_file in "${CLAUDE_PLUGIN_ROOT}"/agents/*.md; do
  agent_name=$(basename "$agent_file")
  agent_content=$(cat "$agent_file")
  result=$(jq -n --arg fp "$agent_file" --arg ct "$agent_content" \
    '{ tool_input: { file_path: $fp, content: $ct } }' | \
    bash "$SCRIPT_DIR/validate-agents.sh" 2>/dev/null || true)
  if [[ -n "$result" ]]; then
    behavior=$(echo "$result" | jq -r '.behavior // "text"' 2>/dev/null || echo "text")
    if [[ "$behavior" == "deny" ]]; then
      AGENT_FAILURES="${AGENT_FAILURES}  ${agent_name}: $(echo "$result" | jq -r '.message' 2>/dev/null)\n"
    fi
  fi
done

TOTAL=$((TOTAL + 1))
if [[ -z "$AGENT_FAILURES" ]]; then
  echo "  PASS  Audit: All 14 agents pass schema validation"
  PASS=$((PASS + 1))
else
  echo "  FAIL  Audit: Some agents failed schema validation:"
  echo -e "$AGENT_FAILURES"
  FAIL=$((FAIL + 1))
fi

# ============================================================
# Cleanup
rm -rf "$TEST_DIR"

echo ""
echo "=== Integration Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
