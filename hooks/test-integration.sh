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
    actual="allow"
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
check_result "Oracle: codebase-context.md (phase 1, no predecessors)" "$RESULT" "allow"

# Step 2: Apollo writes interview-log.md (phase 2, after codebase-context)
# First check: codebase-context.md should exist as predecessor
echo "# Codebase Context" > "${ORACLE_DIR}/codebase-context.md"
echo "  [oracle] Apollo → interview-log.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${ORACLE_DIR}/interview-log.md" "## Round 1\nQ: What is the auth flow?\nA: OAuth2 with refresh tokens")
check_result "Oracle: interview-log.md (phase 2, codebase-context exists)" "$RESULT" "allow"

# Step 3: Apollo writes ambiguity-scores.json (phase 2)
echo "## Round 1" > "${ORACLE_DIR}/interview-log.md"
echo "  [oracle] Apollo → ambiguity-scores.json (passing score)"
RESULT=$(run_hook "$SCRIPT_DIR/validate-gate.sh" \
  "${ORACLE_DIR}/ambiguity-scores.json" '{"goal":0.9,"constraints":0.85,"ac":0.9,"rounds":1}')
check_result "Oracle: ambiguity gate PASS (score=0.12)" "$RESULT" "allow"

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
check_result "Oracle: gap-analysis.md (phase 4, predecessors exist)" "$RESULT" "allow"

# Step 5: Orchestrator writes spec.md (phase 5)
echo "# Gap Analysis" > "${ORACLE_DIR}/gap-analysis.md"
echo "  [oracle] Orchestrator → spec.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${ORACLE_DIR}/spec.md" "# Specification: Auth Service\n## GOAL\nImplement OAuth2\n## ACCEPTANCE_CRITERIA\n1. GIVEN valid token WHEN /api/me THEN 200")
check_result "Oracle: spec.md (phase 5, all predecessors exist)" "$RESULT" "allow"

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
check_result "Tribunal: mechanical gate PASS" "$RESULT" "allow"

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
check_result "Tribunal: verdict.md with spec.md present" "$RESULT" "allow"

# Step 3b: verdict.md with semantic-matrix.md present but no consensus-record.json → Stage 3 warning
echo "  [tribunal] Orchestrator → verdict.md (no consensus-record when semantic-matrix exists)"
echo "# Semantic Matrix" > "${TRIBUNAL_DIR}/semantic-matrix.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${TRIBUNAL_DIR}/verdict.md" "# Tribunal Verdict\n## Final: APPROVED")
check_result "Tribunal: verdict.md with semantic-matrix but no consensus-record → Stage3 warning" "$RESULT" "allow"
rm -f "${TRIBUNAL_DIR}/semantic-matrix.md"

# ============================================================
echo ""
echo "--- Phase 3: Odyssey State Machine ---"
# ============================================================

# Valid state transitions
echo "  [odyssey] oracle → pantheon (skip genesis)"
echo '{"phase":"oracle"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.001.json"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"pantheon","gates":{"ambiguityScore":0.15}}')
check_result "Odyssey: oracle→pantheon (valid, ambiguity passed)" "$RESULT" "allow"

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
check_result "Odyssey: tribunal→completed with Terminal → silent" "$RESULT" "allow"

# Continue transition with retry tracking
echo "  [odyssey] execution retry with Continue"
echo '{"phase":"tribunal"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.004.json"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"execution","transition":{"status":"continue","reason":"implementation_retry","retryCount":2,"maxRetries":3}}')
check_result "Odyssey: tribunal→execution retry (within limit)" "$RESULT" "allow"

# Gate precondition: pantheon without ambiguity passed
echo '{"phase":"oracle"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.005.json"
echo "  [odyssey] oracle→pantheon without ambiguity gate"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"pantheon","gates":{"ambiguityScore":0.35}}')
check_result "Odyssey: pantheon with ambiguity 0.35 > 0.2 → deny" "$RESULT" "deny"

# Gate precondition: planning phase with low consensus → deny
echo '{"phase":"pantheon"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.006.json"
echo "  [odyssey] pantheon→planning with insufficient consensus"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"planning","gates":{"consensusLevel":0.5}}')
check_result "Odyssey: planning with consensusLevel 0.5 < 0.66 → deny" "$RESULT" "deny"

# Gate precondition: planning phase with sufficient consensus (2/3) → allow
echo '{"phase":"pantheon"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.007.json"
echo "  [odyssey] pantheon→planning with 2/3 consensus"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"planning","gates":{"consensusLevel":0.6667}}')
check_result "Odyssey: planning with consensusLevel 0.6667 (2/3) → allow" "$RESULT" "allow"

# Gate precondition: execution phase with themisVerdict=APPROVE → allow
echo '{"phase":"planning"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.008.json"
echo "  [odyssey] planning→execution with APPROVE themisVerdict"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"execution","gates":{"themisVerdict":"APPROVE"}}')
check_result "Odyssey: execution with APPROVE themisVerdict → allow" "$RESULT" "allow"

# Gate precondition: execution phase with themisVerdict=REVISE → deny
echo '{"phase":"planning"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.009.json"
echo "  [odyssey] planning→execution with REVISE themisVerdict"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"execution","gates":{"themisVerdict":"REVISE"}}')
check_result "Odyssey: execution with REVISE themisVerdict → deny" "$RESULT" "deny"

# Rewind transition: tribunal→oracle via returnToPhase (REJECTED_SPEC)
echo '{"phase":"tribunal"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.010.json"
echo "  [odyssey] tribunal→oracle rewind (REJECTED_SPEC via returnToPhase)"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"oracle","transition":{"status":"terminal","reason":"rejected","returnToPhase":"oracle"}}')
check_result "Odyssey: tribunal→oracle rewind (returnToPhase) → allow" "$RESULT" "allow"

# Gate precondition: completed phase with mechanicalPass=false → deny
echo '{"phase":"tribunal"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.011.json"
echo "  [odyssey] tribunal→completed without mechanical pass"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"completed","gates":{"mechanicalPass":false}}')
check_result "Odyssey: completed with mechanicalPass=false → deny" "$RESULT" "deny"

# Gate precondition: completed phase without gates key → allow (null-safe: no gates = no precondition violation)
echo '{"phase":"tribunal"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.011b.json"
echo "  [odyssey] completed without gates key → allow"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"completed"}')
check_result "Odyssey: completed without gates key → allow (no gate precondition)" "$RESULT" "allow"
rm -f "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.011b.json"

# Retry tracking: evaluationPass > maxPasses → deny (validate-state enforces retry limit)
echo '{"phase":"execution"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.012.json"
echo "  [odyssey] tribunal→execution retry evaluationPass=4 > maxPasses=3 → deny"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"execution","retryTracking":{"evaluationPass":4,"maxPasses":3}}')
check_result "Odyssey: execution with evaluationPass=4 > maxPasses=3 → deny" "$RESULT" "deny"

# Retry tracking: evaluationPass == maxPasses → allow (boundary: exactly at limit is ok)
echo '{"phase":"execution"}' > "${ODYSSEY_DIR}/.checkpoints/odyssey-state.json.013.json"
echo "  [odyssey] tribunal→execution retry evaluationPass=3 == maxPasses=3 → allow"
RESULT=$(run_hook "$SCRIPT_DIR/validate-state.sh" \
  "${ODYSSEY_DIR}/odyssey-state.json" '{"phase":"execution","retryTracking":{"evaluationPass":3,"maxPasses":3}}')
check_result "Odyssey: execution with evaluationPass=3 == maxPasses=3 → allow (boundary)" "$RESULT" "allow"

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
check_result "Audit: hermes.md passes schema validation" "$RESULT" "allow"

echo "  [audit] Validate real agent: zeus.md"
ZEUS_CONTENT=$(cat "${CLAUDE_PLUGIN_ROOT}/agents/zeus.md")
RESULT=$(jq -n --arg fp "${CLAUDE_PLUGIN_ROOT}/agents/zeus.md" --arg ct "$ZEUS_CONTENT" \
  '{ tool_input: { file_path: $fp, content: $ct } }' | \
  bash "$SCRIPT_DIR/validate-agents.sh" 2>/dev/null || true)
check_result "Audit: zeus.md passes schema validation" "$RESULT" "allow"

echo "  [audit] Validate real agent: apollo.md"
APOLLO_CONTENT=$(cat "${CLAUDE_PLUGIN_ROOT}/agents/apollo.md")
RESULT=$(jq -n --arg fp "${CLAUDE_PLUGIN_ROOT}/agents/apollo.md" --arg ct "$APOLLO_CONTENT" \
  '{ tool_input: { file_path: $fp, content: $ct } }' | \
  bash "$SCRIPT_DIR/validate-agents.sh" 2>/dev/null || true)
check_result "Audit: apollo.md passes schema validation" "$RESULT" "allow"

# Validate ALL 15 agents in a batch
echo "  [audit] Batch validate all 15 agents"
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
  echo "  PASS  Audit: All 15 agents pass schema validation"
  PASS=$((PASS + 1))
else
  echo "  FAIL  Audit: Some agents failed schema validation:"
  echo -e "$AGENT_FAILURES"
  FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "--- Phase 5: Review-PR Pipeline (artifact creation order) ---"
# ============================================================

REVIEWPR_DIR="${TEST_DIR}/.olympus/review-pr-20260401-inttest5"
mkdir -p "$REVIEWPR_DIR/.checkpoints"

# Step 1: pr-diff.patch (orchestrator, no source)
echo "  [review-pr] Orchestrator → pr-diff.patch"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${REVIEWPR_DIR}/pr-diff.patch" "diff --git a/src/auth.ts b/src/auth.ts")
check_result "Review-PR: pr-diff.patch (orchestrator writes)" "$RESULT" "allow"

# Step 2: pr-context.md (from hermes)
echo "  [review-pr] Hermes → pr-context.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${REVIEWPR_DIR}/pr-context.md" "# PR Context\n## Changed Files\n- src/auth.ts: modified")
check_result "Review-PR: pr-context.md (hermes source)" "$RESULT" "allow"

# Step 3: review-findings.md (from ares+poseidon)
echo "  [review-pr] Ares+Poseidon → review-findings.md"
echo "# PR Context" > "${REVIEWPR_DIR}/pr-context.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${REVIEWPR_DIR}/review-findings.md" "# Review Findings\n## Ares\nCRITICAL: Race condition src/auth.ts:42")
check_result "Review-PR: review-findings.md (ares+poseidon)" "$RESULT" "allow"

# Step 4: verdict.md (from nemesis)
echo "  [review-pr] Nemesis → verdict.md"
echo "# Findings" > "${REVIEWPR_DIR}/review-findings.md"
echo "# DA Eval" > "${REVIEWPR_DIR}/da-evaluation.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${REVIEWPR_DIR}/verdict.md" "# PR Review Verdict\n## Verdict: REQUEST_CHANGES")
check_result "Review-PR: verdict.md (nemesis synthesis)" "$RESULT" "allow"

# ============================================================
echo ""
echo "--- Phase 6: Evolve Pipeline (artifact creation order) ---"
# ============================================================

EVOLVE_DIR="${TEST_DIR}/.olympus/evolve-20260401-inttest6"
mkdir -p "$EVOLVE_DIR/.checkpoints"

# Step 1: benchmark.md (orchestrator)
echo "  [evolve] Orchestrator → benchmark.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${EVOLVE_DIR}/benchmark.md" "## Benchmark\n### Target Skill: oracle")
check_result "Evolve: benchmark.md (orchestrator writes)" "$RESULT" "allow"

# Step 2: dogfood-result.md (orchestrator)
echo "  [evolve] Orchestrator → dogfood-result.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${EVOLVE_DIR}/dogfood-result.md" "## Dogfood Result\n### Finding 1")
check_result "Evolve: dogfood-result.md (orchestrator writes)" "$RESULT" "allow"

# Step 3: eval-matrix.md (from athena)
echo "  [evolve] Athena → eval-matrix.md"
echo "## Benchmark" > "${EVOLVE_DIR}/benchmark.md"
echo "## Dogfood" > "${EVOLVE_DIR}/dogfood-result.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${EVOLVE_DIR}/eval-matrix.md" "## Evaluation Matrix\n| Dimension | Score |")
check_result "Evolve: eval-matrix.md (athena source)" "$RESULT" "allow"

# Step 4: diagnosis.md (from metis+eris)
echo "  [evolve] Metis+Eris → diagnosis.md"
echo "## Eval" > "${EVOLVE_DIR}/eval-matrix.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${EVOLVE_DIR}/diagnosis.md" "## Diagnosis\n### Improvement Proposals")
check_result "Evolve: diagnosis.md (metis+eris source)" "$RESULT" "allow"

# Step 5: evolve-state.json gate validation
echo "  [evolve] Gate check: evolve-state.json (overall ≥ 0.8 + all dims ≥ 0.6) → allow"
RESULT=$(run_hook "$SCRIPT_DIR/validate-gate.sh" \
  "${EVOLVE_DIR}/evolve-state.json" \
  '{"iteration":2,"overall":0.85,"scores":{"specificity":0.9,"evidence":0.8,"role":0.75,"efficiency":0.85,"actionability":0.8}}')
check_result "Evolve: evolve-state.json (all pass) → allow" "$RESULT" "allow"

echo "  [evolve] Gate check: evolve-state.json overall < 0.8 → deny"
RESULT=$(run_hook "$SCRIPT_DIR/validate-gate.sh" \
  "${EVOLVE_DIR}/evolve-state.json" \
  '{"iteration":1,"overall":0.72,"scores":{"specificity":0.7,"evidence":0.7}}')
check_result "Evolve: evolve-state.json overall 0.72 < 0.8 → deny" "$RESULT" "deny"

echo "  [evolve] Gate check: evolve-state.json dim below 0.6 → warning (allow)"
RESULT=$(run_hook "$SCRIPT_DIR/validate-gate.sh" \
  "${EVOLVE_DIR}/evolve-state.json" \
  '{"iteration":2,"overall":0.85,"scores":{"specificity":0.9,"evidence":0.5,"role":0.8}}')
check_result "Evolve: evolve-state.json evidence=0.5 < 0.6 → dim warning allow" "$RESULT" "allow"

# ============================================================
echo ""
echo "--- Phase 7: Genesis Pipeline (gen-{n} pattern) ---"
# ============================================================

GENESIS_DIR="${TEST_DIR}/.olympus/genesis-20260401-inttest7"
mkdir -p "$GENESIS_DIR/gen-1/.checkpoints"

# Step 1: gen-1/spec.md (orchestrator initial)
echo "  [genesis] Orchestrator → gen-1/spec.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${GENESIS_DIR}/gen-1/spec.md" "# Spec v1\n## GOAL\nBuild login feature")
check_result "Genesis: gen-1/spec.md (initial spec)" "$RESULT" "allow"

# Step 2: gen-1/wonder.md (from metis)
echo "  [genesis] Metis → gen-1/wonder.md"
echo "# Spec" > "${GENESIS_DIR}/gen-1/spec.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${GENESIS_DIR}/gen-1/wonder.md" "## Wonder\n### Essence\nLogin is identity verification")
check_result "Genesis: gen-1/wonder.md (metis wonder)" "$RESULT" "allow"

# Step 3: gen-1/reflect.md (from eris)
echo "  [genesis] Eris → gen-1/reflect.md"
echo "## Wonder" > "${GENESIS_DIR}/gen-1/wonder.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${GENESIS_DIR}/gen-1/reflect.md" "## Reflect\n### Challenge 1: Hasty Generalization")
check_result "Genesis: gen-1/reflect.md (eris reflect)" "$RESULT" "allow"

# Step 4: convergence.json (orchestrator) — passing
echo "  [genesis] Orchestrator → convergence.json"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${GENESIS_DIR}/convergence.json" '{"similarity":0.97,"converged":true}')
check_result "Genesis: convergence.json (convergence check)" "$RESULT" "allow"

# Step 4b: convergence gate FAIL (similarity below 0.95) → deny
echo "  [genesis] Convergence gate fail (0.8 similarity)"
RESULT=$(run_hook "$SCRIPT_DIR/validate-gate.sh" \
  "${GENESIS_DIR}/convergence.json" '{"similarity":0.8,"converged":false}')
check_result "Genesis: convergence 0.8 < 0.95 → deny" "$RESULT" "deny"

# ============================================================
echo ""
echo "--- Phase 8: Pantheon Pipeline (multi-perspective analysis) ---"
# ============================================================

PANTHEON_TEST_DIR="${TEST_DIR}/.olympus/pantheon-20260401-inttest8"
mkdir -p "$PANTHEON_TEST_DIR/.checkpoints"

# Step 1: perspectives.md (from helios)
echo "  [pantheon] Helios → perspectives.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${PANTHEON_TEST_DIR}/perspectives.md" "## Perspectives\n### P1: Code Quality\nAssigned: ares")
check_result "Pantheon: perspectives.md (helios source)" "$RESULT" "allow"

# Step 2: analyst-findings.md (from ares+poseidon)
echo "  [pantheon] Ares+Poseidon → analyst-findings.md"
echo "## Perspectives" > "${PANTHEON_TEST_DIR}/perspectives.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${PANTHEON_TEST_DIR}/analyst-findings.md" "## Analyst Findings\n### Ares\nCRITICAL: God class")
check_result "Pantheon: analyst-findings.md (ares+poseidon)" "$RESULT" "allow"

# Step 3: da-evaluation.md (from eris)
echo "  [pantheon] Eris → da-evaluation.md"
echo "## Findings" > "${PANTHEON_TEST_DIR}/analyst-findings.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${PANTHEON_TEST_DIR}/da-evaluation.md" "## DA Evaluation\n### Verdict: SUFFICIENT")
check_result "Pantheon: da-evaluation.md (eris challenge)" "$RESULT" "allow"

# Step 3b: analysis.md WITHOUT da-evaluation.md → DA mandatory warning (still allow)
echo "  [pantheon] Orchestrator → analysis.md (no DA yet)"
rm -f "${PANTHEON_TEST_DIR}/da-evaluation.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${PANTHEON_TEST_DIR}/analysis.md" "## Cross-Perspective Analysis\n### Recommendations")
check_result "Pantheon: analysis.md without da-evaluation.md → DA mandatory warning" "$RESULT" "allow"

# Step 4: analysis.md (orchestrator synthesis) with da-evaluation.md present
echo "  [pantheon] Orchestrator → analysis.md"
echo "## DA" > "${PANTHEON_TEST_DIR}/da-evaluation.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${PANTHEON_TEST_DIR}/analysis.md" "## Cross-Perspective Analysis\n### Recommendations")
check_result "Pantheon: analysis.md (final synthesis)" "$RESULT" "allow"

# ============================================================
echo ""
echo "--- Phase 9: Agora Pipeline (committee debate) ---"
# ============================================================

AGORA_DIR="${TEST_DIR}/.olympus/agora-20260401-inttest9"
mkdir -p "$AGORA_DIR/.checkpoints"

# Step 1: debate-frame.json (orchestrator)
echo "  [agora] Orchestrator → debate-frame.json"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${AGORA_DIR}/debate-frame.json" '{"question":"REST vs GraphQL","options":[{"id":"A","title":"REST"},{"id":"B","title":"GraphQL"}]}')
check_result "Agora: debate-frame.json (orchestrator)" "$RESULT" "allow"

# Step 2: committee-positions.md (from zeus+ares+eris)
echo "  [agora] Committee → committee-positions.md"
echo '{}' > "${AGORA_DIR}/debate-frame.json"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${AGORA_DIR}/committee-positions.md" "## Committee Positions\n### Zeus: REST\n### Ares: GraphQL")
check_result "Agora: committee-positions.md (committee)" "$RESULT" "allow"

# Step 3: da-challenges.md (from eris)
echo "  [agora] Eris → da-challenges.md"
echo "## Positions" > "${AGORA_DIR}/committee-positions.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${AGORA_DIR}/da-challenges.md" "## DA Challenges\n### Challenge 1: Hasty Generalization")
check_result "Agora: da-challenges.md (eris challenge)" "$RESULT" "allow"

# Step 4: decision.md WITHOUT da-challenges.md → DA mandatory warning
echo "  [agora] Orchestrator → decision.md (no DA challenges)"
AGORA_NO_DA_DIR="${TEST_DIR}/.olympus/agora-20260401-inttest9b"
mkdir -p "$AGORA_NO_DA_DIR"
echo '{}' > "${AGORA_NO_DA_DIR}/debate-frame.json"
echo "## Positions" > "${AGORA_NO_DA_DIR}/committee-positions.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${AGORA_NO_DA_DIR}/decision.md" "## Committee Decision\n### Verdict: GraphQL\n### Consensus: 2/3")
check_result "Agora: decision.md without da-challenges.md → DA mandatory warning (allow)" "$RESULT" "allow"

# Step 5: decision.md WITH da-challenges.md present → allow
echo "  [agora] Orchestrator → decision.md (with DA present)"
# Write da-challenges with substantive content (>100 bytes)
printf '## DA Challenges\n### Challenge 1: Hasty Generalization\nThe assumption that GraphQL will scale better lacks benchmark evidence. REST with HTTP/2 achieves similar parallelism.' > "${AGORA_NO_DA_DIR}/da-challenges.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${AGORA_NO_DA_DIR}/decision.md" "## Committee Decision\n### Verdict: GraphQL\n### Consensus: 2/3")
check_result "Agora: decision.md with da-challenges.md present → allow" "$RESULT" "allow"

# Step 4: decision.md (original test with da-challenges.md from step 3)
echo "  [agora] Orchestrator → decision.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${AGORA_DIR}/decision.md" "## Committee Decision\n### Verdict: GraphQL\n### Consensus: 2/3")
check_result "Agora: decision.md (final decision)" "$RESULT" "allow"

# ============================================================
echo ""
echo "--- Phase 10: Review-PR Pipeline (PR review) ---"
# ============================================================

REVIEW_PR_TEST_DIR="${TEST_DIR}/.olympus/review-pr-20260401-inttest10"
mkdir -p "$REVIEW_PR_TEST_DIR/.checkpoints"

# Step 1: pr-context.md (from hermes)
echo "  [review-pr] Hermes → pr-context.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${REVIEW_PR_TEST_DIR}/pr-context.md" "## PR Context\n### Files Changed\n- src/auth.ts")
check_result "Review-PR: pr-context.md (hermes)" "$RESULT" "allow"

# Step 2: review-findings.md (from ares+poseidon)
echo "  [review-pr] Ares+Poseidon → review-findings.md"
echo "## Context" > "${REVIEW_PR_TEST_DIR}/pr-context.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${REVIEW_PR_TEST_DIR}/review-findings.md" "## Review Findings\n### Ares\nCRITICAL: SQL injection")
check_result "Review-PR: review-findings.md (ares+poseidon)" "$RESULT" "allow"

# Step 3: da-evaluation.md (from eris)
echo "  [review-pr] Eris → da-evaluation.md"
echo "## Findings" > "${REVIEW_PR_TEST_DIR}/review-findings.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${REVIEW_PR_TEST_DIR}/da-evaluation.md" "## DA Evaluation\n### Challenge 1: False Positive confirmed — remove finding X")
check_result "Review-PR: da-evaluation.md (eris DA)" "$RESULT" "allow"

# Step 4: verdict.md WITH da-evaluation.md → allow
echo "  [review-pr] Nemesis → verdict.md (with DA present)"
echo "## DA with actual content exceeding 100 bytes to pass size check. This is the DA evaluation content from Eris." > "${REVIEW_PR_TEST_DIR}/da-evaluation.md"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${REVIEW_PR_TEST_DIR}/verdict.md" "## Verdict\n### Decision: REQUEST_CHANGES\n### Rationale: 2 CRITICAL findings confirmed by Eris")
check_result "Review-PR: verdict.md with da-evaluation.md → allow" "$RESULT" "allow"

# Step 5: verdict.md WITHOUT da-evaluation.md → DA warning (allow with context)
echo "  [review-pr] Nemesis → verdict.md (without DA — warn)"
REVIEW_PR_NODA_DIR="${TEST_DIR}/.olympus/review-pr-20260401-inttest11"
mkdir -p "$REVIEW_PR_NODA_DIR/.checkpoints"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${REVIEW_PR_NODA_DIR}/verdict.md" "## Verdict\n### Decision: APPROVE")
check_result "Review-PR: verdict.md without da-evaluation.md → DA warning" "$RESULT" "allow"

# ============================================================
echo ""
echo "--- Phase 11: Audit Pipeline (self-audit artifact chain) ---"
# ============================================================

AUDIT_DIR="${TEST_DIR}/.olympus/audit-20260401-inttest12"
mkdir -p "$AUDIT_DIR/.checkpoints"

# Step 1: audit-mechanical.json (hephaestus writes)
echo "  [audit] Hephaestus → audit-mechanical.json"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${AUDIT_DIR}/audit-mechanical.json" '{"status":"PASS","violations":[],"warnings":[]}')
check_result "Audit: audit-mechanical.json (hephaestus, phase 1) → allow" "$RESULT" "allow"

# Step 2: audit-semantic.json without audit-mechanical.json → predecessor warning
echo "  [audit] Athena → audit-semantic.json (missing predecessor)"
AUDIT_NOPRED_DIR="${TEST_DIR}/.olympus/audit-20260401-inttest13"
mkdir -p "$AUDIT_NOPRED_DIR/.checkpoints"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${AUDIT_NOPRED_DIR}/audit-semantic.json" '{"scores":{"specificity":0.9}}')
check_result "Audit: audit-semantic.json without audit-mechanical.json → predecessor warning" "$RESULT" "allow"

# Step 3: audit-semantic.json WITH audit-mechanical.json present → allow
echo "  [audit] Athena → audit-semantic.json (with predecessor)"
echo '{"status":"PASS"}' > "${AUDIT_DIR}/audit-mechanical.json"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${AUDIT_DIR}/audit-semantic.json" '{"scores":{"specificity":0.9}}')
check_result "Audit: audit-semantic.json with audit-mechanical.json → allow" "$RESULT" "allow"

# Step 4: audit-report.md with all predecessors → allow
echo "  [audit] Orchestrator → audit-report.md"
echo '{"scores":{}}' > "${AUDIT_DIR}/audit-semantic.json"
RESULT=$(run_hook "$SCRIPT_DIR/verify-artifacts.sh" \
  "${AUDIT_DIR}/audit-report.md" "## Audit Report\n### Status: PASS")
check_result "Audit: audit-report.md with all predecessors → allow" "$RESULT" "allow"

# Step 5: spawn gate — audit-mechanical.json without hephaestus registered → deny
echo "  [audit] Spawn gate: audit-mechanical.json before hephaestus spawn → deny"
AUDIT_SPAWN_DIR="${TEST_DIR}/.olympus/audit-20260401-inttest14"
mkdir -p "$AUDIT_SPAWN_DIR/.checkpoints"
RESULT=$(run_hook "$SCRIPT_DIR/enforce-spawn-gate.sh" \
  "${AUDIT_SPAWN_DIR}/audit-mechanical.json" '{"status":"PASS"}')
check_result "Audit: audit-mechanical.json spawn gate (hephaestus not spawned) → deny" "$RESULT" "deny"

# ============================================================
# Cleanup
rm -rf "$TEST_DIR"

echo ""
echo "=== Integration Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
