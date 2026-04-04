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
  if eval "$cmd" >/dev/null 2>&1; then
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
