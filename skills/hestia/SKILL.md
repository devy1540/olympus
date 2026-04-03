---
name: hestia
description: "The Hearth — project onboarding and guided first run"
---

# /olympus:hestia — The Hearth

Hestia tends the hearth fire. She scans your project, understands its shape, and guides you to the right Olympus skill for your first run.

While `/olympus:setup` verifies the **plugin** is installed, `/olympus:hestia` prepares **your project** for the gods.

---

## Execution Flow

```
Phase 1 (Scan) → Phase 2 (Assess) → Phase 3 (Recommend) → Phase 4 (Ignite)
```

### Phase 1: Scan the Hearth

Quick codebase reconnaissance (no agent spawn — orchestrator does this directly):

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

### Phase 2: Assess the Fire

Determine project readiness:

```
Readiness dimensions:

1. Specification Readiness:
   - Does a spec or PRD already exist? (README, docs/, spec.md, etc.)
   - Are there clear requirements in issue trackers?
   - Score: HIGH (spec exists) / MEDIUM (partial) / LOW (none)

2. Codebase Readiness:
   - Is there a working build?
   - Are there tests?
   - Is the codebase navigable (structured directories, not a monolith file)?
   - Score: HIGH / MEDIUM / LOW

3. Complexity Assessment:
   - File count, dependency count
   - Monorepo vs single project
   - Simple: < 50 files | Medium: 50-500 | Complex: 500+
```

### Phase 3: Recommend the Path

Based on assessment, recommend the right starting skill:

```
Decision tree:

IF user has a new feature request with vague requirements:
  → Recommend: /olympus:oracle
  → "Start with Oracle — the gods will interview you to clarify requirements."

ELIF user has clear requirements but wants multi-perspective analysis:
  → Recommend: /olympus:pantheon
  → "Your requirements are clear. Let the Council examine them from multiple angles."

ELIF user has a technical decision to make:
  → Recommend: /olympus:agora
  → "Frame the decision and let the Committee debate."

ELIF user has implementation to evaluate:
  → Recommend: /olympus:tribunal
  → "Submit your implementation for the Trial."

ELIF user wants the full pipeline:
  → Recommend: /olympus:odyssey
  → "Ready for the Grand Journey — from requirements to verdict."

ELSE:
  → Present all options via AskUserQuestion

Present recommendation via AskUserQuestion:
  question: "Based on your project, I recommend starting with {skill}. What would you like to do?"
  options:
    - "{recommended skill}": proceed with recommendation
    - "Show all skills": display full skill catalog
    - "I have a specific task": describe the task for custom routing
```

### Phase 4: Ignite the Hearth

Prepare the project and hand off:

```
1. If .olympus/ doesn't exist:
   - It will be created automatically on first skill run
   - No manual setup needed

2. Display project profile:

   ## Project Profile
   
   | Attribute | Value |
   |-----------|-------|
   | Language | {detected language} |
   | Framework | {detected framework} |
   | Build | `{build command}` |
   | Test | `{test command}` |
   | Scale | {simple/medium/complex} ({file count} files) |
   | Tests | {test count} test files |
   | Prior Olympus runs | {count or "none"} |
   
   ## Recommended Path
   
   **{skill name}** — {reason}
   
   > {one-line description of what will happen}

3. If user accepted recommendation:
   - Display: "Run `{recommended skill}` to begin."
   - Do NOT auto-execute the skill (let the user initiate)
```

---

## Design Notes

- Hestia is **not an agent** — she's a lightweight orchestrator skill that runs without spawning subagents
- No gates, no artifacts, no team teardown
- Entire flow should complete in under 30 seconds
- Purpose: reduce "I installed it, now what?" friction
