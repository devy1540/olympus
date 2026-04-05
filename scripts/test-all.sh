#!/usr/bin/env bash
# test-all.sh — Run ALL Olympus test suites in one command
# Usage: bash scripts/test-all.sh
# Exit code: 0 if all pass, 1 if any fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

SUITE_PASS=0
SUITE_FAIL=0
TOTAL_TESTS=0
TOTAL_PASS=0

run_suite() {
  local name="$1" cmd="$2"
  echo -e "${BOLD}[$name]${NC}"

  OUTPUT=$(eval "$cmd" 2>&1)
  RESULT=$(echo "$OUTPUT" | grep -oE '[0-9]+/[0-9]+' | tail -1)

  if [[ -z "$RESULT" ]]; then
    echo -e "  ${RED}ERROR${NC}: No test results found"
    SUITE_FAIL=$((SUITE_FAIL + 1))
    return
  fi

  PASS=$(echo "$RESULT" | cut -d/ -f1)
  TOTAL=$(echo "$RESULT" | cut -d/ -f2)
  TOTAL_TESTS=$((TOTAL_TESTS + TOTAL))
  TOTAL_PASS=$((TOTAL_PASS + PASS))

  if [[ "$PASS" -eq "$TOTAL" ]]; then
    echo -e "  ${GREEN}${RESULT}${NC} passed"
    SUITE_PASS=$((SUITE_PASS + 1))
  else
    FAILED=$((TOTAL - PASS))
    echo -e "  ${RED}${RESULT}${NC} — ${FAILED} failed"
    echo "$OUTPUT" | grep "FAIL" | head -5 | sed 's/^/    /'
    SUITE_FAIL=$((SUITE_FAIL + 1))
  fi
}

run_check() {
  local name="$1" cmd="$2"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if (eval "$cmd") >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} $name"
    TOTAL_PASS=$((TOTAL_PASS + 1))
    SUITE_PASS=$((SUITE_PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $name"
    SUITE_FAIL=$((SUITE_FAIL + 1))
  fi
}

echo -e "${BOLD}=========================================${NC}"
echo -e "${BOLD}  OLYMPUS FULL TEST SUITE${NC}"
echo -e "${BOLD}=========================================${NC}"
echo ""

# --- Test Suites ---
run_suite "Hook Unit" "bash hooks/test-hooks.sh"
echo ""
run_suite "Integration" "bash hooks/test-integration.sh"
echo ""
run_suite "MCP E2E" "bash mcp-server/test-e2e.sh"
echo ""
run_suite "Deploy" "bash mcp-server/test-deploy.sh"

# --- Go Unit Tests ---
echo ""
echo -e "${BOLD}[Go Unit Tests]${NC}"

GO_OUTPUT=$(cd mcp-server && go test ./... -count=1 2>&1)
GO_PASS=$(echo "$GO_OUTPUT" | grep -c "^ok" || true)
GO_FAIL=$(echo "$GO_OUTPUT" | grep -c "^FAIL" || true)
GO_TOTAL=$((GO_PASS + GO_FAIL))
GO_TEST_COUNT=$(echo "$GO_OUTPUT" | grep -oE '\(cached\)|[0-9]+\.[0-9]+s$' | wc -l | tr -d ' ')

TOTAL_TESTS=$((TOTAL_TESTS + GO_TOTAL))
if [[ "$GO_FAIL" -eq 0 && "$GO_PASS" -gt 0 ]]; then
  echo -e "  ${GREEN}${GO_PASS}/${GO_TOTAL}${NC} packages passed"
  TOTAL_PASS=$((TOTAL_PASS + GO_PASS))
  SUITE_PASS=$((SUITE_PASS + 1))
else
  echo -e "  ${RED}${GO_PASS}/${GO_TOTAL}${NC} — ${GO_FAIL} package(s) failed"
  echo "$GO_OUTPUT" | grep "FAIL" | head -5 | sed 's/^/    /'
  SUITE_FAIL=$((SUITE_FAIL + 1))
fi

# --- Quality Checks ---
echo ""
echo -e "${BOLD}[Quality Checks]${NC}"

run_check "Go build" "cd mcp-server && go build ./..."
run_check "Go vet" "cd mcp-server && go vet ./..."

for f in docs/shared/*.json hooks/hooks.json .claude-plugin/plugin.json; do
  run_check "JSON: $(basename $f)" "python3 -c \"import json;json.load(open('$f'))\""
done

for f in hooks/*.sh; do
  run_check "Syntax: $(basename $f)" "bash -n $f"
done

# --- Consistency Checks ---
echo ""
echo -e "${BOLD}[Consistency]${NC}"

AGENT_COUNT=$(ls agents/*.md 2>/dev/null | wc -l | tr -d ' ')
run_check "Agents: ${AGENT_COUNT}/15" "[ $AGENT_COUNT -eq 15 ]"

SKILL_COUNT=$(ls -d skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
run_check "Skills: ${SKILL_COUNT}/11" "[ $SKILL_COUNT -eq 11 ]"

SCHEMA_COUNT=$(ls docs/shared/*.json 2>/dev/null | wc -l | tr -d ' ')
run_check "Schemas: ${SCHEMA_COUNT}/5" "[ $SCHEMA_COUNT -ge 5 ]"

# --- Harness Pattern Checks ---
echo ""
echo -e "${BOLD}[Harness Patterns]${NC}"

# All grep pipelines must be safe under set -euo pipefail
SPAWN_SKILLS=$(grep -rl "Agent(name:" skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || echo 0)

BANNED_WAIT=$({ grep -r "Wait for messages — do not act until prompted" skills/*/SKILL.md 2>/dev/null || true; } | { grep -v "NEVER" || true; } | wc -l | tr -d ' ')
run_check "No banned 'Wait for messages' (${BANNED_WAIT})" "[ $BANNED_WAIT -eq 0 ]"

PROACTIVE_RULE=$(grep -rl "PROACTIVE SPAWN RULE" skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || echo 0)
run_check "PROACTIVE SPAWN RULE: ${PROACTIVE_RULE}/${SPAWN_SKILLS}" "[ $PROACTIVE_RULE -ge $SPAWN_SKILLS ]"

IMMEDIATE=$(grep -rl "IMMEDIATE TASK" skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || echo 0)
run_check "IMMEDIATE TASK pattern: ${IMMEDIATE}/${SPAWN_SKILLS}" "[ $IMMEDIATE -ge $SPAWN_SKILLS ]"

MANDATORY=$(grep -rl "MANDATORY" skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || echo 0)
run_check "MANDATORY consultation: ${MANDATORY}/${SPAWN_SKILLS}" "[ $MANDATORY -ge $SPAWN_SKILLS ]"

SEQUENTIAL=$(grep -rl "SEQUENTIAL SPAWN" skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || echo 0)
run_check "SEQUENTIAL SPAWN rule: ${SEQUENTIAL}/${SPAWN_SKILLS}" "[ $SEQUENTIAL -ge $SPAWN_SKILLS ]"

RESULT_CAPTURE=$(grep -rl "RESULT CAPTURE RULE" skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || echo 0)
run_check "RESULT CAPTURE RULE: ${RESULT_CAPTURE}/${SPAWN_SKILLS}" "[ $RESULT_CAPTURE -ge $SPAWN_SKILLS ]"

RESPONSE_RULE=$(grep -rl "RESPONSE RULE" skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || echo 0)
run_check "RESPONSE RULE: ${RESPONSE_RULE}/${SPAWN_SKILLS}" "[ $RESPONSE_RULE -ge $SPAWN_SKILLS ]"

RO_SENDMSG=0
for a in hermes apollo metis ares poseidon athena themis eris helios nemesis; do
  if grep -q 'SendMessage.*LEADER_NAME\|SendMessage.*team-lead\|SendMessage.*leader' "agents/${a}.md" 2>/dev/null; then
    RO_SENDMSG=$((RO_SENDMSG + 1))
  fi
done
run_check "Read-only agents SendMessage: ${RO_SENDMSG}/10" "[ $RO_SENDMSG -eq 10 ]"

VMINDSET=$(grep -rl "Verification_Mindset" agents/*.md 2>/dev/null | wc -l | tr -d ' ' || echo 0)
run_check "Verification_Mindset: ${VMINDSET}/15" "[ $VMINDSET -eq 15 ]"

XREF_ARES=$(grep -c "poseidon\|CROSS-REFERENCE" agents/ares.md 2>/dev/null || echo 0)
XREF_POSEIDON=$(grep -c "ares\|CROSS-REFERENCE" agents/poseidon.md 2>/dev/null || echo 0)
run_check "ares↔poseidon cross-ref" "[ $XREF_ARES -ge 2 ] && [ $XREF_POSEIDON -ge 2 ]"

GATE_AMB=$(python3 -c "import json;t=json.load(open('docs/shared/gate-thresholds.json'));print(t['ambiguity']['threshold'])" 2>/dev/null || echo "?")
GATE_CON=$(python3 -c "import json;t=json.load(open('docs/shared/gate-thresholds.json'));print(t['consensus']['threshold'])" 2>/dev/null || echo "?")
run_check "Gate thresholds: amb=${GATE_AMB} con=${GATE_CON}" "[ '$GATE_AMB' = '0.2' ] && [ '$GATE_CON' = '0.66' ]"

# --- Summary ---
echo ""
echo -e "${BOLD}=========================================${NC}"
echo -e "  Tests:  ${TOTAL_PASS}/${TOTAL_TESTS}"
if [[ "$SUITE_FAIL" -eq 0 ]]; then
  echo -e "  Status: ${GREEN}${BOLD}ALL PASSED${NC}"
else
  echo -e "  Status: ${RED}${BOLD}${SUITE_FAIL} SUITE(S) FAILED${NC}"
fi
echo -e "${BOLD}=========================================${NC}"

exit $SUITE_FAIL
