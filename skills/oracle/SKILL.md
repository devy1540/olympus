---
name: oracle
description: "The Oracle of Delphi — requirements refinement pipeline"
---

# /olympus:oracle — The Oracle of Delphi

A pipeline that systematically refines requirements into a structured spec.md.

## Agents (subagent_type bindings)
- **Hermes**: Codebase exploration (Phase 1) → `subagent_type: "olympus:hermes"`
- **Apollo**: Interview loop (Phase 2) → `subagent_type: "olympus:apollo"`
- **Metis**: Gap analysis (Phase 4) → `subagent_type: "olympus:metis"`

**⚠ MANDATORY**: Each agent listed above MUST be spawned via the Agent tool with the specified subagent_type. The orchestrator MUST NOT perform Hermes's exploration, Apollo's interview, or Metis's gap analysis directly. See orchestrator-protocol.md §0.

## Gate
- Ambiguity score ≤ 0.2

## Artifact Contracts
| File | Phase | Writer | Readers |
|---|---|---|---|
| `.olympus/{id}/codebase-context.md` | 1 | Hermes | Apollo, Metis |
| `.olympus/{id}/interview-log.md` | 2 | Apollo | Metis |
| `.olympus/{id}/ambiguity-scores.json` | 2 | Apollo | Gate check |
| `.olympus/{id}/gap-analysis.md` | 4 | Metis | Zeus, Helios |
| `.olympus/{id}/spec.md` | 5 | Orchestrator | All downstream skills |

---

## Execution Flow

```
Phase 0 → Phase 1 → Phase 2 → Phase 3 (Gate) → Phase 4 → Phase 5
```

### Phase 0: Input Classification

Classify user input and determine interview depth.

```
Input Classification:
- file: file path → read contents
- URL: web URL → fetch via WebFetch
- text: raw text → use directly
- conversation: conversation context → extract from prior conversation

Complexity Assessment:
- Trivial: clear and simple → skip Phase 1-2, jump to Phase 5
- Clear: mostly clear, minor clarification needed → light interview (3 rounds max)
- Vague: significant ambiguity → full interview (10 rounds max)
- Contradictory: contains contradictions → deep interview (resolve contradictions first)
```

### Phase 1: Hermes Codebase Exploration

```
1. Spawn Hermes as a Task:
   - Prompt: "Gather codebase context related to the user requirement '{input}'"
   - Inject worker-preamble
   - Artifact directory: .olympus/{id}/
2. Hermes saves exploration results to .olympus/{id}/codebase-context.md
```

### Phase 2: Apollo Interview Loop

```
1. Spawn Apollo as a Task:
   - Prompt: artifact directory path + user input + complexity level
   - Instruction: "Use Read to load .olympus/{id}/codebase-context.md directly" (do NOT inject full content)
2. Apollo asks one question at a time via AskUserQuestion
3. After each answer:
   a. Update ambiguity scores (per ambiguity-scoring.md)
   b. Update interview-log.md
   c. Update ambiguity-scores.json
4. Stagnation detection:
   - Spinning: same topic asked 3 times → move to next dimension
   - Oscillation: A↔B repetition → ask user to decide
   - Diminishing: delta < 0.02 → terminate current dimension
5. Termination: ambiguity ≤ 0.2 or max rounds reached
```

### Phase 3: Ambiguity Gate

```
ambiguity = read ambiguity-scores.json

if ambiguity <= 0.2:
    → Phase 4
else if rounds >= 10:
    → Present remaining gaps to the user
    → AskUserQuestion: "The following gaps remain. Proceed anyway?"
    → On override → Phase 4
else:
    → Return to Phase 2
```

### Phase 4: Metis Gap Analysis

```
1. Spawn Metis as a Task:
   - Prompt: artifact directory path
   - Instruction: "Use Read to load .olympus/{id}/interview-log.md and .olympus/{id}/codebase-context.md directly" (do NOT inject full content)
2. Metis performs analysis:
   - Missing Questions
   - Undefined Guardrails
   - Scope Risks
   - Unvalidated Assumptions
   - Acceptance Criteria
   - Edge Cases
3. Results saved to gap-analysis.md
```

### Phase 5: Seed Generation

Synthesize interview-log.md + gap-analysis.md into spec.md:

```markdown
# Specification: {title}

## GOAL
{objective — clear and measurable}

## CONSTRAINTS
{list of constraints}

## ACCEPTANCE_CRITERIA
1. GIVEN {precondition} WHEN {action} THEN {result}
2. ...

## SCOPE
### In Scope
- {included items}
### Out of Scope
- {excluded items}

## ASSUMPTIONS
- {validated assumption} — validation method: {method}

## EDGE_CASES
1. {case} — expected behavior: {behavior}

## OPEN_QUESTIONS
- {unresolved question} (if any)

## ONTOLOGY
| Term | Definition |
|---|---|
| {term} | {definition} |

## AMBIGUITY_SCORE
{final score}
```

### Team Teardown

Shut down Hermes, Apollo, and Metis per the team-teardown.md protocol.
