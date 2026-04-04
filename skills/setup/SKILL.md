---
name: setup
description: "Olympus setup — verify installation, check dependencies, show available skills"
---

# /olympus:setup — Installation Verification & Setup

Verifies that Olympus is correctly installed and all dependencies are available.

---

## Execution Flow

```
Phase 1 (Environment) → Phase 2 (Hooks) → Phase 3 (Agents) → Phase 4 (Report)
```

### Phase 1: Environment Check

Check required dependencies:

```
1. bash version:
   - Run: bash --version
   - Require: 4.0+ (for associative arrays, used in test scripts)
   - macOS default bash is 3.2 — warn if so, suggest: brew install bash

2. jq:
   - Run: which jq && jq --version
   - Required: all hooks depend on jq for JSON parsing
   - If missing: suggest: brew install jq (macOS) / apt install jq (Linux)

3. Plugin root:
   - Verify CLAUDE_PLUGIN_ROOT resolves correctly
   - Check: ${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json exists
   - Check: ${CLAUDE_PLUGIN_ROOT}/agents/ directory exists
   - Check: ${CLAUDE_PLUGIN_ROOT}/skills/ directory exists
   - If CLAUDE_PLUGIN_ROOT is not set (running from dev directory):
     Use fallback: current working directory

4. git (optional):
   - Run: which git
   - Used for plugin updates via marketplace
```

### Phase 1.5: MCP Server Binary Setup

Check and install the MCP server binary:

```
1. Check binary existence:
   - Path: ${CLAUDE_PLUGIN_ROOT}/bin/olympus-mcp
   - If exists: run --version, report version
   - If missing: proceed to download

2. If missing — auto-download:
   - Detect platform: uname -s → darwin/linux
   - Detect arch: uname -m → arm64/amd64
   - Get version from plugin.json
   - Download from GitHub Release:
     URL: https://github.com/devy1540/olympus/releases/download/v{version}/olympus-mcp-{platform}-{arch}
   - Save to: ${CLAUDE_PLUGIN_ROOT}/bin/olympus-mcp
   - chmod +x
   - Verify: run --version

3. If download fails:
   - Report: "MCP 서버 바이너리 다운로드 실패. MCP 기능은 비활성 상태이지만 스킬/에이전트/훅은 정상 작동합니다."
   - Continue to Phase 2 (non-blocking)

4. Report:
   | MCP Server | OK/MISSING | {version or "다운로드 실패"} |
```

### Phase 2: Hook Validation

Verify all hook scripts are functional:

```
1. For each script in hooks.json:
   - Check file exists
   - Check executable permission (chmod +x)
   - Run: bash -n {script} (syntax check)

2. Test jq pipeline:
   - Run: echo '{"test": true}' | jq -r '.test'
   - Verify output is "true"

3. Verify gate-thresholds.json is parseable:
   - Run: jq '.' docs/shared/gate-thresholds.json
   - Verify all 4 gates present (ambiguity, convergence, consensus, semantic)

4. If any hook fails:
   - Report which hook and why
   - Suggest fix (chmod +x, install jq, etc.)
```

### Phase 3: Agent & Skill Verification

Verify all components are registered:

```
1. Agents (14 expected):
   - List all files in agents/ directory
   - For each: verify YAML frontmatter has required fields (name, description, model, disallowedTools)
   - Report count: {found}/14

2. Skills (9 expected including setup):
   - List all directories in skills/ with SKILL.md
   - Report count: {found}/9

3. Shared documents:
   - Verify existence of core schemas:
     - docs/shared/agent-schema.json
     - docs/shared/gate-thresholds.json
     - docs/shared/pipeline-states.json
     - docs/shared/artifact-contracts.json
     - docs/shared/hook-responses.json
   - Report count: {found}/5
```

### Phase 4: Setup Report

Display the results and available skills:

```markdown
# Olympus Setup Report

## Environment
| Dependency | Status | Version |
|-----------|--------|---------|
| bash      | OK/WARN | {version} |
| jq        | OK/MISSING | {version} |
| git       | OK/MISSING | {version} |
| MCP Server | OK/MISSING | {version or "N/A"} |

## Components
| Component | Status | Count |
|-----------|--------|-------|
| Agents    | OK | 14/14 |
| Skills    | OK | 9/9 |
| Hooks     | OK | 7/7 |
| Schemas   | OK | 5/5 |

## Available Skills

| Skill | Description | Usage |
|-------|-------------|-------|
| `/olympus:oracle` | Requirements refinement | Turn vague ideas into specs |
| `/olympus:genesis` | Spec evolution | Evolve specs generation by generation |
| `/olympus:pantheon` | Multi-perspective analysis | Analyze from orthogonal viewpoints |
| `/olympus:tribunal` | 3-stage evaluation | Mechanical → Semantic → Consensus |
| `/olympus:odyssey` | Full pipeline | Oracle → Genesis → Pantheon → Plan → Execute → Tribunal |
| `/olympus:agora` | Committee debate | Structured technical decision-making |
| `/olympus:audit` | Self-inspection | Validate plugin consistency |
| `/olympus:evolve` | Self-evolution | Improve Olympus through benchmarking |
| `/olympus:setup` | This command | Verify installation and show help |

## Quick Start

1. Start with requirements: `/olympus:oracle`
2. Or run the full pipeline: `/olympus:odyssey`
3. For technical decisions: `/olympus:agora`

## Troubleshooting

If skills or agents are not recognized after installation:
1. Run: `/reload-plugins` in Claude Code
2. If still not working, restart Claude Code
3. Verify plugin is enabled: check `~/.claude/settings.json` for `"olympus@olympus-marketplace": true`
4. Re-install: `/plugin marketplace add devy1540/olympus` then `/plugin install olympus@olympus-marketplace`
```

---

## Error Recovery

If Phase 1 finds missing dependencies:
- Stop after Phase 1
- Show only the dependency issues and fix instructions
- Do not proceed to Phase 2-4

If Phase 2 finds broken hooks:
- Continue to Phase 3-4 but mark hooks as WARN
- Skills will work but without runtime validation
