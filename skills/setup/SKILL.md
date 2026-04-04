---
name: setup
description: "Olympus setup — verify installation, check dependencies, show available skills"
---

<Purpose>
Verify that Olympus is correctly installed and all dependencies are available.
Display environment status, component counts, and available skills.
</Purpose>

<Execution_Policy>
- This skill does NOT spawn agents — it is a lightweight diagnostic skill.
- No gates, no artifacts, no team teardown.
- Runs all checks directly via Bash and file reads.
</Execution_Policy>

<Steps>

## Step 1: Environment Check

```
1. bash version:
   - Run: bash --version
   - Require: 4.0+ (for associative arrays)
   - macOS default is 3.2 — warn if so, suggest: brew install bash

2. jq:
   - Run: which jq && jq --version
   - Required: all hooks depend on jq
   - If missing: suggest: brew install jq (macOS) / apt install jq (Linux)

3. Plugin root:
   - Verify CLAUDE_PLUGIN_ROOT or fallback to cwd
   - Check: hooks/hooks.json, agents/, skills/ exist

4. git (optional):
   - Run: which git
```

---

## Step 2: MCP Server Binary Setup

```
1. Check: ${CLAUDE_PLUGIN_ROOT}/bin/olympus-mcp exists
   - If exists: run --version, report
   - If missing: auto-download from GitHub Release

2. Download:
   - Detect platform: uname -s → darwin/linux
   - Detect arch: uname -m → arm64/amd64
   - Get version from plugin.json
   - URL: https://github.com/devy1540/olympus/releases/download/v{version}/olympus-mcp-{platform}-{arch}
   - Save to: ${CLAUDE_PLUGIN_ROOT}/bin/olympus-mcp
   - chmod +x, verify --version

3. If download fails:
   - Report: "MCP 기능 비활성, 스킬/에이전트/훅은 정상 작동"
   - Continue (non-blocking)
```

---

## Step 3: Hook Validation

```
1. For each script in hooks.json:
   - Check exists + executable
   - Run: bash -n (syntax check)

2. Test jq pipeline:
   echo '{"test": true}' | jq -r '.test'

3. Verify gate-thresholds.json parseable:
   jq '.' docs/shared/gate-thresholds.json
```

---

## Step 4: Agent & Skill Verification

```
1. Agents (15 expected):
   - List agents/*.md, verify YAML frontmatter
   - Report: {found}/15

2. Skills (11 expected including setup):
   - List skills/*/SKILL.md
   - Report: {found}/11

3. Shared documents (5 core schemas):
   - agent-schema.json, gate-thresholds.json, pipeline-states.json,
     artifact-contracts.json, hook-responses.json
   - Report: {found}/5
```

---

## Step 5: Setup Report

```
# Olympus Setup Report

## Environment
| Dependency | Status | Version |
|-----------|--------|---------|
| bash | OK/WARN | {ver} |
| jq | OK/MISSING | {ver} |
| git | OK/MISSING | {ver} |
| MCP Server | OK/MISSING | {ver} |

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
