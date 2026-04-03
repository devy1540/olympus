# Contributing to Olympus

Olympus에 기여해주셔서 감사합니다.

## Getting Started

### Prerequisites

- [Claude Code](https://claude.ai/code) CLI installed
- Bash 4.0+ (macOS: `brew install bash`)
- `jq` for JSON processing (`brew install jq`)

### Local Setup

```bash
git clone https://github.com/devy1540/olympus.git
cd olympus

# Run validation tests
bash hooks/test-hooks.sh
bash hooks/test-integration.sh
```

## Project Structure

```
olympus/
  agents/           # 14 agent definitions (.md with YAML frontmatter)
  skills/           # 10 skill orchestrations (SKILL.md)
  hooks/            # 7 hook scripts + 3 test/utility + 1 library
  docs/shared/      # 5 schemas + 12 protocols
  .claude-plugin/   # Plugin registration
```

This is **not** a Node.js/npm project. It's a pure Claude Code plugin: Markdown agents + shell hooks + skill orchestration.

## How to Contribute

### Reporting Bugs

Open a [GitHub Issue](https://github.com/devy1540/olympus/issues) with:
- Steps to reproduce
- Expected vs actual behavior
- Which skill/agent was involved
- Relevant `.olympus/` artifacts (redact sensitive data)

### Suggesting Features

Open an issue with the `enhancement` label. Include:
- Use case description
- Which pipeline stage it affects
- Whether it requires a new agent, skill, or protocol change

### Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Run validation: `bash hooks/test-hooks.sh && bash hooks/test-integration.sh`
5. Commit with a descriptive message
6. Open a Pull Request

## Development Guidelines

### Agent Definitions (`agents/*.md`)

- Name: lowercase only, no hyphens (`^[a-z]+$`)
- Required frontmatter: `name`, `description`, `model`, `disallowedTools`
- Required sections: `Role`, `Success_Criteria`, `Constraints`, `Context_Protocol`, `Investigation_Protocol`, `Tool_Usage`, `Output_Format`, `Failure_Modes_To_Avoid`, `Final_Checklist`
- All threshold values must reference `gate-thresholds.json` — never hardcode
- `validate-agents.sh` enforces schema on every Write/Edit

### Skills (`skills/*/SKILL.md`)

- Required frontmatter: `name`, `description`
- Must define: agent bindings, gate thresholds, artifact contracts, execution flow
- Artifacts must be registered in `docs/shared/artifact-contracts.json`

### Hooks (`hooks/*.sh`)

- Must return structured JSON per `docs/shared/hook-responses.json` schema
- Use `emit_deny()` / `emit_allow_with_context()` helpers
- Gate thresholds must be read from `gate-thresholds.json` at runtime
- All scripts must pass `bash -n` syntax check

### Shared Documents (`docs/shared/`)

- `gate-thresholds.json` is the single source of truth for all threshold values
- `artifact-contracts.json` defines who writes/reads each artifact
- `pipeline-states.json` defines valid state transitions
- Changes to schemas require corresponding hook updates

### Key Principles

1. **Evidence-based**: Every claim needs `file:line` references or test results
2. **Single source of truth**: Thresholds in `gate-thresholds.json`, schemas in `agent-schema.json`
3. **Delegation pattern**: Read-only agents use SendMessage, orchestrator writes files
4. **No hardcoding**: All configurable values must be read from shared documents at runtime

## Validation

Before submitting a PR, ensure:

```bash
# All hook scripts pass syntax check
bash -n hooks/*.sh

# Unit tests pass
bash hooks/test-hooks.sh

# Integration tests pass
bash hooks/test-integration.sh

# Self-audit passes (inside Claude Code)
/olympus:audit
```

## Releasing

Releases are automated via `scripts/release.sh` and GitHub Actions.

```bash
# Bump version, run tests, create commit + tag
bash scripts/release.sh patch    # 1.0.0 → 1.0.1
bash scripts/release.sh minor    # 1.0.0 → 1.1.0
bash scripts/release.sh major    # 1.0.0 → 2.0.0

# Push to trigger GitHub Release
git push origin main --tags
```

The release script:
1. Validates clean working tree and runs all tests
2. Bumps version in `plugin.json` and `marketplace.json`
3. Generates a changelog in `docs/CHANGELOG-vX.Y.Z.md`
4. Creates a release commit and annotated tag

GitHub Actions then:
- **CI** (`.github/workflows/ci.yml`): Runs on every push/PR — syntax check, JSON validation, tests
- **Release** (`.github/workflows/release.yml`): Triggers on `v*` tags — validates, creates GitHub Release with auto-generated notes

## Code of Conduct

Be respectful and constructive. We follow the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
