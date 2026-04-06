#!/usr/bin/env bash
# test-e2e.sh — Olympus MCP Server End-to-End Test Suite
# Strategy: one MCP session to create state → CLI queries to verify
# Run: bash mcp-server/test-e2e.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BIN="${PROJECT_ROOT}/bin/olympus-mcp"
export OLYMPUS_DATA_DIR="/tmp/olympus-mcp-e2e-$$"
export OLYMPUS_PLUGIN_ROOT="$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0
TOTAL=0

cleanup() { rm -rf "$OLYMPUS_DATA_DIR"; }
trap cleanup EXIT

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    echo -e "  ${GREEN}PASS${NC}  $name"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}  $name (expected='$expected', got='$actual')"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$haystack" | grep -q "$needle"; then
    echo -e "  ${GREEN}PASS${NC}  $name"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}  $name (expected to contain '$needle', got='${haystack:0:100}')"
    FAIL=$((FAIL + 1))
  fi
}

jq_field() {
  echo "$1" | python3 -c "
import sys,json
v = json.loads(sys.stdin.read()).get('$2', '')
if isinstance(v, bool): print('true' if v else 'false')
elif isinstance(v, list): print(json.dumps(v))
else: print(v)
" 2>/dev/null
}

if [[ ! -x "$BIN" ]]; then
  echo -e "${RED}Binary not found: $BIN${NC}"
  exit 1
fi

echo "=== Olympus MCP E2E Test Suite ==="
echo ""

# ============================================================
echo "--- Phase 1: Setup state via MCP session ---"
# ============================================================

# Create interview log for ambiguity test
mkdir -p "$OLYMPUS_DATA_DIR"
cat > "${OLYMPUS_DATA_DIR}/interview.md" << 'EOF'
# Interview Log
## Round 1: Scope
**Q**: What is the goal?
**A**: Add push notifications.
## Round 2: Constraints
**Q**: Volume?
**A**: TBD, probably around 10k/day.
## Round 3: AC
**Q**: How to test?
**A**: GIVEN user action WHEN triggered THEN push within 5s.
EOF

# Session 1: Create pipeline (must complete before other operations)
cat << 'S1' | "$BIN" serve >/dev/null 2>&1
{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_start_pipeline","arguments":{"skill":"odyssey","pipeline_id":"e2e-001"}}}
S1

# Session 2: Register spawns + record executions (no status query — separate to avoid WAL race)
MCP_OUTPUT=$(cat << 'S2' | "$BIN" serve 2>/dev/null
{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"olympus_register_agent_spawn","arguments":{"pipeline_id":"e2e-001","agent_name":"hermes"}}}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"olympus_register_agent_spawn","arguments":{"pipeline_id":"e2e-001","agent_name":"apollo"}}}
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"olympus_register_agent_spawn","arguments":{"pipeline_id":"e2e-001","agent_name":"metis"}}}
{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"olympus_record_execution","arguments":{"pipeline_id":"e2e-001","phase":"oracle","agent_name":"hermes","duration_ms":3500,"token_count":8000}}}
{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"olympus_record_execution","arguments":{"pipeline_id":"e2e-001","phase":"oracle","agent_name":"apollo","duration_ms":12000,"token_count":25000}}}
S2
)

# Session 2.5: Pipeline status (separate session to ensure WAL flush after spawns)
MCP_STATUS=$(cat << 'S25' | "$BIN" serve 2>/dev/null
{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"olympus_pipeline_status","arguments":{"pipeline_id":"e2e-001"}}}
S25
)

# Session 3: Gate checks (sequential sessions to avoid concurrent DB writes)
GATE_OUTPUT=""
for gate_req in \
  '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"olympus_gate_check","arguments":{"pipeline_id":"e2e-001","gate_type":"ambiguity","score":0.12}}}' \
  '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"olympus_gate_check","arguments":{"pipeline_id":"e2e-001","gate_type":"ambiguity","score":0.25}}}' \
  '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"olympus_gate_check","arguments":{"pipeline_id":"e2e-001","gate_type":"convergence","score":0.96}}}' \
  '{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"olympus_gate_check","arguments":{"pipeline_id":"e2e-001","gate_type":"convergence","score":0.90}}}' \
  '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"olympus_gate_check","arguments":{"pipeline_id":"e2e-001","gate_type":"consensus","score":0.75}}}' \
  '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"olympus_gate_check","arguments":{"pipeline_id":"e2e-001","gate_type":"consensus","score":0.50}}}' \
  '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"olympus_gate_check","arguments":{"pipeline_id":"e2e-001","gate_type":"semantic","score":0.85}}}' \
  '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"olympus_gate_check","arguments":{"pipeline_id":"e2e-001","gate_type":"semantic","score":0.60}}}' \
  '{"jsonrpc":"2.0","id":16,"method":"tools/call","params":{"name":"olympus_gate_check","arguments":{"pipeline_id":"e2e-001","gate_type":"evolve_dimension_minimum","score":0.75}}}' \
  '{"jsonrpc":"2.0","id":17,"method":"tools/call","params":{"name":"olympus_gate_check","arguments":{"pipeline_id":"e2e-001","gate_type":"evolve_dimension_minimum","score":0.45}}}'; do
  INIT_LINE='{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
  RESP=$(printf '%s\n%s\n' "$INIT_LINE" "$gate_req" | "$BIN" serve 2>/dev/null)
  GATE_OUTPUT="${GATE_OUTPUT}${RESP}"$'\n'
done

# Parse MCP responses
get_mcp_result() {
  local id=$1
  echo "$MCP_OUTPUT" | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        m = json.loads(line.strip())
        if m.get('id') == $id:
            c = m.get('result', {}).get('content', [])
            for x in c:
                if x.get('type') == 'text':
                    print(x['text'])
                    break
            break
    except: pass
" 2>/dev/null
}

echo ""
echo "--- Phase 2: Verify MCP tool responses ---"

# 1. Pipeline creation (verified via CLI since it was session 1)
CLI_P=$("$BIN" query pipeline-status e2e-001 2>/dev/null || true)
assert_eq "start_pipeline: id" "e2e-001" "$(jq_field "$CLI_P" "id")"
assert_eq "start_pipeline: skill" "odyssey" "$(jq_field "$CLI_P" "skill")"

# 2-4. Spawn registration
R2=$(get_mcp_result 2)
R3=$(get_mcp_result 3)
R4=$(get_mcp_result 4)
assert_eq "register hermes" "true" "$(jq_field "$R2" "registered")"
assert_eq "register apollo" "true" "$(jq_field "$R3" "registered")"
assert_eq "register metis" "true" "$(jq_field "$R4" "registered")"

# 5-10. Gate checks (from GATE_OUTPUT, separate sessions)
get_gate_result() {
  local id=$1
  echo "$GATE_OUTPUT" | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        m = json.loads(line.strip())
        if m.get('id') == $id:
            c = m.get('result', {}).get('content', [])
            for x in c:
                if x.get('type') == 'text':
                    print(x['text'])
                    break
            break
    except: pass
" 2>/dev/null
}

R5=$(get_gate_result 5)
R6=$(get_gate_result 6)
R7=$(get_gate_result 7)
R8=$(get_gate_result 8)
R9=$(get_gate_result 9)
R10=$(get_gate_result 10)
assert_eq "ambiguity 0.12 ≤ 0.2 → pass" "true" "$(jq_field "$R5" "passed")"
assert_eq "ambiguity 0.25 > 0.2 → fail" "false" "$(jq_field "$R6" "passed")"
assert_eq "convergence 0.96 ≥ 0.95 → pass" "true" "$(jq_field "$R7" "passed")"
assert_eq "convergence 0.90 < 0.95 → fail" "false" "$(jq_field "$R8" "passed")"
assert_eq "consensus 0.75 ≥ 0.66 → pass" "true" "$(jq_field "$R9" "passed")"
assert_eq "consensus 0.50 < 0.66 → fail" "false" "$(jq_field "$R10" "passed")"
R14=$(get_gate_result 14)
R15=$(get_gate_result 15)
R16=$(get_gate_result 16)
R17=$(get_gate_result 17)
assert_eq "semantic 0.85 ≥ 0.8 → pass" "true" "$(jq_field "$R14" "passed")"
assert_eq "semantic 0.60 < 0.8 → fail" "false" "$(jq_field "$R15" "passed")"
assert_eq "evolve_dim 0.75 ≥ 0.6 → pass" "true" "$(jq_field "$R16" "passed")"
assert_eq "evolve_dim 0.45 < 0.6 → fail" "false" "$(jq_field "$R17" "passed")"

# 11-12. Execution history
R11=$(get_mcp_result 11)
R12=$(get_mcp_result 12)
assert_eq "record hermes execution" "true" "$(jq_field "$R11" "recorded")"
assert_eq "record apollo execution" "true" "$(jq_field "$R12" "recorded")"

# 13. Pipeline status
# R13 from separate Session 2.5 (after WAL flush)
R13=$(echo "$MCP_STATUS" | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        m = json.loads(line.strip())
        if m.get('id') == 13:
            c = m.get('result', {}).get('content', [])
            for x in c:
                if x.get('type') == 'text':
                    print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_eq "status: skill" "odyssey" "$(jq_field "$R13" "skill")"
assert_eq "status: status" "active" "$(jq_field "$R13" "status")"
assert_contains "status: hermes spawned" "hermes" "$R13"
assert_contains "status: apollo spawned" "apollo" "$R13"
assert_contains "status: metis spawned" "metis" "$R13"

# ============================================================
echo ""
echo "--- Phase 3: CLI query verification ---"
# ============================================================

# Pipeline status
CLI_STATUS=$("$BIN" query pipeline-status e2e-001 2>/dev/null)
assert_eq "CLI: pipeline skill" "odyssey" "$(jq_field "$CLI_STATUS" "skill")"
assert_eq "CLI: pipeline status" "active" "$(jq_field "$CLI_STATUS" "status")"
assert_contains "CLI: hermes in spawned" "hermes" "$CLI_STATUS"

# Spawned agents (positive)
HERMES=$("$BIN" query is-spawned e2e-001 hermes 2>/dev/null || true)
assert_eq "CLI: hermes spawned=true" "true" "$(jq_field "$HERMES" "spawned")"

APOLLO=$("$BIN" query is-spawned e2e-001 apollo 2>/dev/null || true)
assert_eq "CLI: apollo spawned=true" "true" "$(jq_field "$APOLLO" "spawned")"

# Spawned agents (negative)
ERIS_EXIT=0
"$BIN" query is-spawned e2e-001 eris >/dev/null 2>&1 || ERIS_EXIT=$?
assert_eq "CLI: eris not spawned → exit 1" "1" "$ERIS_EXIT"

ZEUS_EXIT=0
"$BIN" query is-spawned e2e-001 zeus >/dev/null 2>&1 || ZEUS_EXIT=$?
assert_eq "CLI: zeus not spawned → exit 1" "1" "$ZEUS_EXIT"

# Gate status — Session 3 already scored, just query
GATE=$("$BIN" query gate-status e2e-001 ambiguity 2>/dev/null || true)
assert_contains "CLI: ambiguity gate has score" "score" "$GATE"

SEM_EXIT=0
"$BIN" query gate-status e2e-001 semantic >/dev/null 2>&1 || SEM_EXIT=$?
assert_eq "CLI: semantic gate failed (0.60 < 0.8) → exit 1" "1" "$SEM_EXIT"

# ============================================================
echo ""
echo "--- Phase 4: Error handling ---"
# ============================================================

# Duplicate pipeline
DUP_OUTPUT=$(cat << 'REQ' | "$BIN" serve 2>/dev/null
{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_start_pipeline","arguments":{"skill":"odyssey","pipeline_id":"e2e-001"}}}
REQ
)
DUP_R=$(echo "$DUP_OUTPUT" | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        m = json.loads(line.strip())
        if m.get('id') == 1:
            c = m.get('result', {}).get('content', [])
            for x in c:
                if x.get('type') == 'text':
                    print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_contains "duplicate pipeline → error" "실패" "$DUP_R"

# Nonexistent pipeline
CLI_ERR=$("$BIN" query pipeline-status nonexistent-999 2>/dev/null || true)
assert_contains "CLI: nonexistent pipeline → error" "error" "$CLI_ERR"

# ============================================================
echo ""
echo "--- Phase 5: Mechanical ambiguity scoring ---"
# ============================================================

AMB_OUTPUT=$(cat << REQUESTS | "$BIN" serve 2>/dev/null
{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_calculate_ambiguity","arguments":{"pipeline_id":"e2e-001","interview_log_path":"${OLYMPUS_DATA_DIR}/interview.md"}}}
REQUESTS
)
AMB_R=$(echo "$AMB_OUTPUT" | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        m = json.loads(line.strip())
        if m.get('id') == 1:
            c = m.get('result', {}).get('content', [])
            for x in c:
                if x.get('type') == 'text':
                    print(x['text']); break
            break
    except: pass
" 2>/dev/null)

assert_contains "ambiguity: has mechanical_score" "mechanical_score" "$AMB_R"
assert_contains "ambiguity: has dimensions" "dimensions" "$AMB_R"
assert_contains "ambiguity: has indicators" "indicators" "$AMB_R"

# TBD and "probably" should increase ambiguity
AMB_SCORE=$(echo "$AMB_R" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('mechanical_score', 0))" 2>/dev/null)
TOTAL=$((TOTAL + 1))
IS_POSITIVE=$(echo "$AMB_SCORE" | awk '{ print ($1 > 0) ? "true" : "false" }')
if [[ "$IS_POSITIVE" == "true" ]]; then
  echo -e "  ${GREEN}PASS${NC}  mechanical score > 0 (detected TBD/probably): ${AMB_SCORE}"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${NC}  mechanical score should be > 0: ${AMB_SCORE}"
  FAIL=$((FAIL + 1))
fi

# Nonexistent file
AMB_ERR_OUTPUT=$(cat << 'REQ' | "$BIN" serve 2>/dev/null
{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_calculate_ambiguity","arguments":{"pipeline_id":"e2e-001","interview_log_path":"/nonexistent.md"}}}
REQ
)
AMB_ERR_R=$(echo "$AMB_ERR_OUTPUT" | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        m = json.loads(line.strip())
        if m.get('id') == 1:
            c = m.get('result', {}).get('content', [])
            for x in c:
                if x.get('type') == 'text':
                    print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_contains "nonexistent interview log → error" "실패" "$AMB_ERR_R"

# ============================================================
echo ""
echo "--- Phase 6: DB integrity ---"
# ============================================================

DB_FILE="${OLYMPUS_DATA_DIR}/olympus.db"
TOTAL=$((TOTAL + 1))
if [[ -f "$DB_FILE" ]]; then
  DB_SIZE=$(wc -c < "$DB_FILE")
  if [[ "$DB_SIZE" -gt 1000 ]]; then
    echo -e "  ${GREEN}PASS${NC}  DB persisted (${DB_SIZE} bytes)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}  DB too small (${DB_SIZE} bytes)"
    FAIL=$((FAIL + 1))
  fi
else
  echo -e "  ${RED}FAIL${NC}  DB file not found"
  FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "--- Phase 7: Real SKILL.md flow simulation ---"
# ============================================================
# Simulate the EXACT sequence a SKILL.md orchestrator would call:
#   start_pipeline → next_phase → register_spawn × N → gate_check → next_phase → ...

# Simulate EXACT SKILL.md sequence with separate sessions (matches real CC behavior)
INIT='{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'

# Flow Step 1: start_pipeline
F_START=$(printf '%s\n%s\n' "$INIT" '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_start_pipeline","arguments":{"skill":"oracle","pipeline_id":"flow-001"}}}' | "$BIN" serve 2>/dev/null)
F100=$(echo "$F_START" | python3 -c "
import sys,json
for l in sys.stdin:
    try:
        m=json.loads(l.strip())
        if m.get('id')==1:
            for x in m.get('result',{}).get('content',[]):
                if x.get('type')=='text': print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_eq "flow: start_pipeline first_phase" "oracle" "$(jq_field "$F100" "first_phase")"

# Flow Step 2: register required spawns FIRST (next_phase now blocks if spawns missing)
F_OPS=$(cat << 'OPS' | "$BIN" serve 2>/dev/null
{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"olympus_register_agent_spawn","arguments":{"pipeline_id":"flow-001","agent_name":"hermes"}}}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"olympus_register_agent_spawn","arguments":{"pipeline_id":"flow-001","agent_name":"apollo"}}}
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"olympus_register_agent_spawn","arguments":{"pipeline_id":"flow-001","agent_name":"metis"}}}
OPS
)
F102=$(echo "$F_OPS" | python3 -c "
import sys,json
for l in sys.stdin:
    try:
        m=json.loads(l.strip())
        if m.get('id')==2:
            for x in m.get('result',{}).get('content',[]):
                if x.get('type')=='text': print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_eq "flow: spawn hermes" "true" "$(jq_field "$F102" "registered")"

# Flow Step 3: next_phase (should work AFTER spawns registered)
F_NEXT=$(printf '%s\n%s\n' "$INIT" '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_next_phase","arguments":{"pipeline_id":"flow-001"}}}' | "$BIN" serve 2>/dev/null)
F101=$(echo "$F_NEXT" | python3 -c "
import sys,json
for l in sys.stdin:
    try:
        m=json.loads(l.strip())
        if m.get('id')==1:
            for x in m.get('result',{}).get('content',[]):
                if x.get('type')=='text': print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_contains "flow: next_phase returns valid phase" "next_phase" "$F101"
TOTAL=$((TOTAL + 1))
if echo "$F101" | grep -q "차단"; then
  echo -e "  ${RED}FAIL${NC}  flow: next_phase should not block after spawns (got: ${F101:0:80})"
  FAIL=$((FAIL + 1))
else
  echo -e "  ${GREEN}PASS${NC}  flow: next_phase succeeds after spawns"
  PASS=$((PASS + 1))
fi

# Flow Step 4: gate check
F_GATE=$(printf '%s\n%s\n' "$INIT" '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_gate_check","arguments":{"pipeline_id":"flow-001","gate_type":"ambiguity","score":0.15}}}' | "$BIN" serve 2>/dev/null)
F106=$(echo "$F_GATE" | python3 -c "
import sys,json
for l in sys.stdin:
    try:
        m=json.loads(l.strip())
        if m.get('id')==1:
            for x in m.get('result',{}).get('content',[]):
                if x.get('type')=='text': print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_eq "flow: ambiguity gate pass" "true" "$(jq_field "$F106" "passed")"

# Flow Step 5: new teammate tools
F_ACTION=$(printf '%s\n%s\n' "$INIT" '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_next_action","arguments":{"pipeline_id":"flow-001"}}}' | "$BIN" serve 2>/dev/null)
F107=$(echo "$F_ACTION" | python3 -c "
import sys,json
for l in sys.stdin:
    try:
        m=json.loads(l.strip())
        if m.get('id')==1:
            for x in m.get('result',{}).get('content',[]):
                if x.get('type')=='text': print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_contains "flow: next_action (leader)" "action" "$F107"

F_AGENT=$(printf '%s\n%s\n' "$INIT" '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_next_action","arguments":{"pipeline_id":"flow-001","agent":"hermes"}}}' | "$BIN" serve 2>/dev/null)
F108=$(echo "$F_AGENT" | python3 -c "
import sys,json
for l in sys.stdin:
    try:
        m=json.loads(l.strip())
        if m.get('id')==1:
            for x in m.get('result',{}).get('content',[]):
                if x.get('type')=='text': print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_contains "flow: next_action (agent=hermes)" "hermes" "$F108"

F_COLLAB=$(printf '%s\n%s\n' "$INIT" '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_log_collaboration","arguments":{"pipeline_id":"flow-001","from":"prometheus","to":"hermes","summary":"코드 구조 확인"}}}' | "$BIN" serve 2>/dev/null)
F109=$(echo "$F_COLLAB" | python3 -c "
import sys,json
for l in sys.stdin:
    try:
        m=json.loads(l.strip())
        if m.get('id')==1:
            for x in m.get('result',{}).get('content',[]):
                if x.get('type')=='text': print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_eq "flow: log_collaboration" "true" "$(jq_field "$F109" "logged")"

# Flow Step 5b: validate_plan
F_VPLAN=$(printf '%s\n%s\n' "$INIT" '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_validate_plan","arguments":{"pipeline_id":"flow-001","skill":"oracle","phase":"execution","agent":"prometheus","estimated_calls":15}}}' | "$BIN" serve 2>/dev/null)
F111=$(echo "$F_VPLAN" | python3 -c "
import sys,json
for l in sys.stdin:
    try:
        m=json.loads(l.strip())
        if m.get('id')==1:
            for x in m.get('result',{}).get('content',[]):
                if x.get('type')=='text': print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_contains "flow: validate_plan" "realistic" "$F111"

# Flow Step 6: unregistered agent spawn (should fail)
F_UNREG=$(printf '%s\n%s\n' "$INIT" '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_register_agent_spawn","arguments":{"pipeline_id":"flow-001","agent_name":"nonexistent-agent"}}}' | "$BIN" serve 2>/dev/null)
F112=$(echo "$F_UNREG" | python3 -c "
import sys,json
for l in sys.stdin:
    try:
        m=json.loads(l.strip())
        if m.get('id')==1:
            for x in m.get('result',{}).get('content',[]):
                if x.get('type')=='text': print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_contains "flow: unregistered agent rejected" "미등록" "$F112"

# Flow Step 6b: dynamic suffix agent spawn (base name registered → should succeed)
F_DYN=$(printf '%s\n%s\n' "$INIT" '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_register_agent_spawn","arguments":{"pipeline_id":"flow-001","agent_name":"ares-r1"}}}' | "$BIN" serve 2>/dev/null)
F113=$(echo "$F_DYN" | python3 -c "
import sys,json
for l in sys.stdin:
    try:
        m=json.loads(l.strip())
        if m.get('id')==1:
            for x in m.get('result',{}).get('content',[]):
                if x.get('type')=='text': print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_eq "flow: dynamic suffix ares-r1 accepted" "true" "$(jq_field "$F113" "registered")"

# Flow Step 6c: unregistered base name (ux-critic → base "ux" not registered → rejected)
F_UX=$(printf '%s\n%s\n' "$INIT" '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_register_agent_spawn","arguments":{"pipeline_id":"flow-001","agent_name":"ux-critic"}}}' | "$BIN" serve 2>/dev/null)
F114=$(echo "$F_UX" | python3 -c "
import sys,json
for l in sys.stdin:
    try:
        m=json.loads(l.strip())
        if m.get('id')==1:
            for x in m.get('result',{}).get('content',[]):
                if x.get('type')=='text': print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_contains "flow: ux-critic base unregistered" "미등록" "$F114"

# Flow Step 7: final status
F_STATUS=$(printf '%s\n%s\n' "$INIT" '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"olympus_pipeline_status","arguments":{"pipeline_id":"flow-001"}}}' | "$BIN" serve 2>/dev/null)
F110=$(echo "$F_STATUS" | python3 -c "
import sys,json
for l in sys.stdin:
    try:
        m=json.loads(l.strip())
        if m.get('id')==1:
            for x in m.get('result',{}).get('content',[]):
                if x.get('type')=='text': print(x['text']); break
            break
    except: pass
" 2>/dev/null)
assert_eq "flow: final status skill" "oracle" "$(jq_field "$F110" "skill")"

# ============================================================
echo ""
echo "=== E2E Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
