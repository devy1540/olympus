#!/usr/bin/env bash
# verify-all.sh — Run all validation suites and report overall health
# Usage: bash scripts/verify-all.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

TOTAL=0
PASSED=0
FAILED=0

run_suite() {
  local name="$1"
  local cmd="$2"
  TOTAL=$((TOTAL + 1))
  printf "  %-30s " "$name"

  local output
  output=$(eval "$cmd" 2>&1)
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    local count=$(echo "$output" | grep -oE '[0-9]+/[0-9]+ passed' | head -1 || echo "PASS")
    echo -e "${GREEN}✓${NC} $count"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAILED"
    echo "$output" | tail -3 | sed 's/^/    /'
    FAILED=$((FAILED + 1))
  fi
}

echo ""
echo -e "${CYAN}=== Olympus Full Verification ===${NC}"
echo ""

# Shell tests
run_suite "Hook unit tests" "bash hooks/test-hooks.sh"
run_suite "Integration tests" "bash hooks/test-integration.sh"

# Go tests
if [[ -f "mcp-server/go.mod" ]]; then
  run_suite "Go tests (MCP server)" "cd mcp-server && go test ./..."
fi

# Agent consistency: validate each agent file through the schema hook
TOTAL=$((TOTAL + 1))
printf "  %-30s " "Agent schema (batch)"
AGENT_FAILURES=""
for agent_file in agents/*.md; do
  agent_content=$(cat "$agent_file")
  result=$(jq -n --arg fp "${ROOT_DIR}/${agent_file}" --arg ct "$agent_content" \
    '{ tool_input: { file_path: $fp, content: $ct } }' | \
    bash hooks/validate-agents.sh 2>/dev/null || true)
  if [[ -n "$result" ]]; then
    behavior=$(echo "$result" | jq -r '.behavior // "text"' 2>/dev/null || echo "text")
    if [[ "$behavior" == "deny" ]]; then
      AGENT_FAILURES="${AGENT_FAILURES} $(basename $agent_file)"
    fi
  fi
done
if [[ -z "$AGENT_FAILURES" ]]; then
  echo -e "${GREEN}✓${NC} all $(ls agents/*.md | wc -l | tr -d ' ') agents valid"
  PASSED=$((PASSED + 1))
else
  echo -e "${RED}✗${NC} failed:${AGENT_FAILURES}"
  FAILED=$((FAILED + 1))
fi

# Quick structural checks
TOTAL=$((TOTAL + 1))
printf "  %-30s " "Agent consistency"
ISSUES=0
AGENT_COUNT=$(ls agents/*.md | wc -l | tr -d ' ')
OUTPUT_COUNT=$(grep -l 'Output size' agents/*.md 2>/dev/null | wc -l | tr -d ' ')
if [[ "$OUTPUT_COUNT" -ne "$AGENT_COUNT" ]]; then
  ISSUES=$((ISSUES + 1))
fi
SPAWN_COUNT=$(grep -c 'required_spawn' docs/shared/artifact-contracts.json)
if [[ "$SPAWN_COUNT" -lt 20 ]]; then
  ISSUES=$((ISSUES + 1))
fi
if [[ $ISSUES -eq 0 ]]; then
  echo -e "${GREEN}✓${NC} ${AGENT_COUNT} agents, ${OUTPUT_COUNT} output guides, ${SPAWN_COUNT} spawn rules"
  PASSED=$((PASSED + 1))
else
  echo -e "${RED}✗${NC} issues found"
  FAILED=$((FAILED + 1))
fi

echo ""
if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}=== ALL ${TOTAL} SUITES PASSED ===${NC}"
else
  echo -e "${RED}=== ${FAILED}/${TOTAL} SUITES FAILED ===${NC}"
  exit 1
fi
echo ""
