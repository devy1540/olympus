---
name: setup
description: "Olympus setup — verify installation, check dependencies, show available skills"
---

<Purpose>
Verify that Olympus is correctly installed, ensure MCP server is operational,
and register MCP in user-level config for maximum reliability.
</Purpose>

<Execution_Policy>
- This skill does NOT spawn agents — it is a lightweight diagnostic skill.
- No gates, no artifacts, no team teardown.
- Runs all checks directly via Bash and file reads.
- MCP registration in ~/.claude/mcp.json is the PRIMARY mechanism (Ouroboros pattern).
- plugin.json mcpServers is a SECONDARY fallback.
</Execution_Policy>

<Steps>

## Step 1: Environment Check

```
1. bash version:
   Run: bash --version
   Require: 4.0+ (for associative arrays)
   macOS default is 3.2 — warn, suggest: brew install bash

2. jq:
   Run: which jq && jq --version
   Required: all hooks depend on jq
   If missing: suggest brew install jq (macOS) / apt install jq (Linux)

3. Plugin root:
   Set: PLUGIN_ROOT="${CLAUDE_SKILL_DIR}/../.."
   Check: ${PLUGIN_ROOT}/hooks/hooks.json, ${PLUGIN_ROOT}/agents/, ${PLUGIN_ROOT}/skills/ exist

4. git (optional):
   Run: which git
```

---

## Step 2: MCP Server Binary Setup

```
PLUGIN_ROOT="${CLAUDE_SKILL_DIR}/../.."

1. Check: ${PLUGIN_ROOT}/bin/olympus-mcp exists
   IF exists: run --version, report
   IF missing: auto-download from GitHub Release

2. Download (if missing):
   Detect platform: uname -s → darwin/linux
   Detect arch: uname -m → arm64/amd64
   Get version: jq -r '.version' ${PLUGIN_ROOT}/.claude-plugin/plugin.json
   URL: https://github.com/devy1540/olympus/releases/download/v{version}/olympus-mcp-{platform}-{arch}
   Save to: ${PLUGIN_ROOT}/bin/olympus-mcp
   chmod +x, verify --version

3. If download fails AND Go is available:
   Fallback: cd ${PLUGIN_ROOT}/mcp-server && go build -o ${PLUGIN_ROOT}/bin/olympus-mcp ./cmd/olympus-mcp/

4. If all fail:
   Report: "MCP 기능 비활성, 스킬/에이전트/훅은 정상 작동"
   Continue (non-blocking)
```

---

## Step 3: MCP Server Registration (Ouroboros Pattern)

Register MCP server in `~/.claude/mcp.json` for user-level reliability.
This ensures the MCP server works even if plugin.json mcpServers fails.

```
1. Check if ~/.claude/mcp.json exists:
   Run: ls -la ~/.claude/mcp.json 2>/dev/null

2. Read existing config (if exists):
   Run: cat ~/.claude/mcp.json

3. Merge olympus-pipeline entry:

   IF olympus-pipeline NOT in mcp.json:
     Add entry:
     {
       "mcpServers": {
         "olympus-pipeline": {
           "command": "${CLAUDE_PLUGIN_ROOT}/scripts/ensure-mcp.sh",
           "args": ["serve"],
           "env": {
             "OLYMPUS_DATA_DIR": "~/.olympus-mcp",
             "OLYMPUS_PLUGIN_ROOT": "{actual resolved plugin root path}"
           }
         }
       }
     }

     IMPORTANT: Resolve ${CLAUDE_PLUGIN_ROOT} to actual path before writing.
     Other servers in mcp.json MUST be preserved (merge, not overwrite).

   IF olympus-pipeline already exists:
     Report: "MCP 서버 이미 등록됨"
     Verify the command path is valid

4. Verify MCP is accessible:
   Call ToolSearch("+olympus pipeline")
   IF tools found: "MCP 서버 연결 확인 ✓"
   IF not found: "MCP 등록 완료. 세션 재시작 후 활성화됩니다."
```

---

## Step 4: Hook Validation

```
PLUGIN_ROOT="${CLAUDE_SKILL_DIR}/../.."

1. For each script in ${PLUGIN_ROOT}/hooks/hooks.json:
   Check exists + executable
   Run: bash -n (syntax check)

2. Test jq pipeline:
   echo '{"test": true}' | jq -r '.test'

3. Verify gate-thresholds.json parseable:
   jq '.' ${CLAUDE_SKILL_DIR}/../../docs/shared/gate-thresholds.json
```

IMPORTANT: All file paths in this skill MUST use `${CLAUDE_SKILL_DIR}/../..` as the plugin root.
The cwd is the USER'S PROJECT directory, NOT the plugin directory.
- Plugin root: `${CLAUDE_SKILL_DIR}/../..` (resolves to the olympus plugin directory)
- DO NOT use relative paths like `docs/shared/` or `agents/` — they will fail.

---

## Step 5: Agent & Skill Verification

```
PLUGIN_ROOT="${CLAUDE_SKILL_DIR}/../.."

1. Agents (15 expected):
   List ${PLUGIN_ROOT}/agents/*.md, verify YAML frontmatter
   Report: {found}/15

2. Skills (11 expected including setup):
   List ${PLUGIN_ROOT}/skills/*/SKILL.md
   Report: {found}/11

3. Shared documents (5 core schemas):
   Check existence of:
     ${PLUGIN_ROOT}/docs/shared/agent-schema.json
     ${PLUGIN_ROOT}/docs/shared/gate-thresholds.json
     ${PLUGIN_ROOT}/docs/shared/pipeline-states.json
     ${PLUGIN_ROOT}/docs/shared/artifact-contracts.json
     ${PLUGIN_ROOT}/docs/shared/hook-responses.json
   Report: {found}/5
```

---

## Step 6: Setup Report

```
# Olympus Setup Report

## Environment
| Dependency | Status | Version |
|-----------|--------|---------|
| bash | OK/WARN | {ver} |
| jq | OK/MISSING | {ver} |
| git | OK/MISSING | {ver} |
| MCP Binary | OK/MISSING | {ver} |
| MCP Registration | OK/MISSING | ~/.claude/mcp.json |

## Components
| Component | Status | Count |
|-----------|--------|-------|
| Agents | OK | 15/15 |
| Skills | OK | 11/11 |
| Hooks | OK | 7/7 |
| Schemas | OK | 5/5 |

## Available Skills
| Skill | Description |
|-------|-------------|
| /olympus:oracle | Requirements refinement |
| /olympus:genesis | Spec evolution |
| /olympus:pantheon | Multi-perspective analysis |
| /olympus:tribunal | 3-stage evaluation |
| /olympus:odyssey | Full pipeline |
| /olympus:agora | Committee debate |
| /olympus:audit | Self-inspection |
| /olympus:evolve | Self-evolution |
| /olympus:hestia | Project onboarding |
| /olympus:review-pr | PR review pipeline |
| /olympus:setup | This command |

## Quick Start
1. Start with requirements: /olympus:oracle
2. Or run the full pipeline: /olympus:odyssey
3. For technical decisions: /olympus:agora
```

</Steps>

<Troubleshooting>
  MCP server failed:
  1. Run: ${CLAUDE_PLUGIN_ROOT}/scripts/ensure-mcp.sh --version
  2. If fails: delete bin/olympus-mcp and re-run /olympus:setup
  3. Verify ~/.claude/mcp.json has olympus-pipeline entry
  4. Restart Claude Code session

  MCP tools not found after setup:
  1. Close current session
  2. Start new session with: claude
  3. Run: /mcp → check olympus-pipeline status

  Plugin not recognized:
  1. Run: /reload-plugins
  2. Verify: ~/.claude/settings.json has "olympus@olympus-marketplace": true
  3. Re-install: claude plugin marketplace add devy1540/olympus
</Troubleshooting>
