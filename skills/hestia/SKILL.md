---
name: hestia
description: "The Hearth — project onboarding and guided first run"
---

<Purpose>
Scan the project, understand its shape, and guide the user to the right Olympus skill.
While /olympus:setup verifies the plugin, /olympus:hestia prepares your project for the gods.
</Purpose>

<Execution_Policy>
- This skill does NOT spawn agents — it is a lightweight orchestrator skill.
- No gates, no artifacts, no team teardown.
- Entire flow should complete in under 30 seconds.
- Purpose: reduce "I installed it, now what?" friction.
</Execution_Policy>

<Steps>

## Step 1: Scan the Hearth

Quick codebase reconnaissance (orchestrator does this directly — no agent needed):

```
1. Project detection:
   - package.json → Node.js/TypeScript
   - pom.xml / build.gradle → JVM
   - pyproject.toml / requirements.txt → Python
   - go.mod → Go
   - Cargo.toml → Rust
   - None → ask the user

2. Scale assessment:
   - Count source files (Glob **/*.{ts,js,py,java,kt,go,rs})
   - Count test files (Glob **/*.{test,spec}.* or **/test_*)
   - Check for CI config (.github/workflows/, Jenkinsfile, etc.)

3. Existing Olympus state:
   - Check .olympus/ directory exists
   - If exists: list prior runs (oracle-*, pantheon-*, odyssey-*)
   - If exists: check for latest spec.md

4. Build system:
   - Detect build command (npm run build, ./gradlew build, make, etc.)
   - Detect test command (npm test, pytest, ./gradlew test, etc.)
   - Detect lint command (eslint, prettier, ruff, etc.)
```

---

## Step 2: Assess the Fire

Determine project readiness:

```
1. Specification Readiness:
   - Does a spec or PRD exist? Score: HIGH / MEDIUM / LOW

2. Codebase Readiness:
   - Working build? Tests? Structured directories? Score: HIGH / MEDIUM / LOW

3. Complexity Assessment:
   - Simple: < 50 files | Medium: 50-500 | Complex: 500+
```

---

## Step 3: Recommend the Path

```
Decision tree:

IF vague requirements:       → /olympus:oracle
ELIF clear reqs, need analysis: → /olympus:pantheon
ELIF technical decision:      → /olympus:agora
ELIF evaluate implementation: → /olympus:tribunal
ELIF full pipeline:           → /olympus:odyssey
ELSE:                         → AskUserQuestion with all options

AskUserQuestion:
  "Based on your project, I recommend {skill}. What would you like to do?"
  ["{recommended}", "Show all skills", "I have a specific task"]
```

---

## Step 4: Ignite the Hearth

```
Display project profile:

## Project Profile
| Attribute | Value |
|-----------|-------|
| Language | {detected} |
| Framework | {detected} |
| Build | `{command}` |
| Test | `{command}` |
| Scale | {level} ({count} files) |
| Prior Olympus runs | {count or "none"} |

## Recommended Path
**{skill name}** — {reason}

Display: "Run `{recommended skill}` to begin."
Do NOT auto-execute the skill.
```

</Steps>
