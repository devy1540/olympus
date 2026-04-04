---
name: genesis
description: "Creation — evolutionary loop that refines specs/designs generation by generation"
---

# /olympus:genesis — Creation (Evolution Loop)

Core Ouroboros pattern. Evolves specs/designs generation by generation until convergence.

## Agents

**Teammate pattern** (persist across generations):
- **Metis**: Wonder (inquiry) — fundamental questions → `TeamCreate` name: `metis-wonder`
- **Eris**: Reflect (audit) — logical validation → `TeamCreate` name: `eris-reflect`
- **Orchestrator**: Seed (crystallization) + convergence check + gate enforcement

**⚠ Why teammates, not subagents:**
Genesis runs Metis and Eris repeatedly (up to 30 generations). Teammates:
- **Remember previous generations** in their own context — wonder.md Gen 3 builds on Gen 2 insights
- **Reduce orchestrator context pressure** — only SendMessage payloads accumulate, not full results
- **Cheaper per-generation cost** — no prompt re-send per cycle

See orchestrator-protocol.md §5 for hybrid spawn mode selection criteria.

## Gate
- Ontology convergence ≥ 0.95

## Artifact Contracts
| File | Phase | Writer | Readers |
|---|---|---|---|
| `.olympus/{id}/gen-{n}/ontology.json` | 3 | Orchestrator | Convergence check |
| `.olympus/{id}/gen-{n}/spec.md` | 3 | Orchestrator | Next generation |
| `.olympus/{id}/gen-{n}/wonder.md` | 1 | Metis | Reflect |
| `.olympus/{id}/gen-{n}/reflect.md` | 2 | Eris | Seed |
| `.olympus/{id}/lineage.json` | 5 | Orchestrator | Rewind |
| `.olympus/{id}/convergence.json` | 4 | Orchestrator | Evolution halt decision |

---

## Execution Flow

```
Phase 0 (Seed) → Phase 1 (Wonder) → Phase 2 (Reflect) → Phase 3 (Seed) → Phase 4 (Converge?)
                      ↑                                                        ↓ NO
                      └────────────────────────────────────────────────────────┘
                                                                               ↓ YES
                                                                         Phase 5 (Lineage)
```

### Phase 0: Initial Seed + Team Creation

```
Input: spec.md (from Oracle) or direct user input

1. Extract initial ontology:
   - Extract core concepts/terms from spec.md
   - Each concept: { name, type, description, relationships }
   - Save as Gen 1 ontology.json

2. Create Gen 1 directory:
   mkdir -p .olympus/{id}/gen-1/
   - Save ontology.json
   - Copy spec.md

3. Create evolution team (teammates persist across all generations):

   TeamCreate:
     name: "metis-wonder"
     subagent_type: "olympus:metis"
     prompt: "You are Metis, ontologist of the gods.
       You will be called repeatedly across generations to ask fundamental questions.
       Artifact directory: .olympus/{id}/
       IMPORTANT: You retain memory of previous generations within this session.
       Build on your earlier insights — do not repeat questions already explored.
       Each generation, Read the latest gen-{n}/spec.md and gen-{n}/ontology.json."

   TeamCreate:
     name: "eris-reflect"
     subagent_type: "olympus:eris"
     prompt: "You are Eris, logical auditor of evolution.
       You will be called repeatedly across generations to validate ontology mutations.
       Artifact directory: .olympus/{id}/
       IMPORTANT: You retain memory of previous generations within this session.
       Track mutation patterns across generations — catch recurring fallacies.
       Each generation, Read wonder.md and compare prev/current ontology.json."
```

### Phase 1: Wonder (Inquiry)

"What do we still not know?"

```
1. SendMessage to metis-wonder:
   summary: "Gen {n} wonder"
   message: "Generation {n}.
     Read .olympus/{id}/gen-{n}/spec.md and .olympus/{id}/gen-{n}/ontology.json.
     {If n > 1: "Previous reflection: Read .olympus/{id}/gen-{n-1}/reflect.md for Eris's feedback."}
     Answer the 4 fundamental questions. Save results to .olympus/{id}/gen-{n}/wonder.md."

2. Metis's 4 fundamental questions (Ouroboros ontologist):
   a. Essence: "What is the essential nature of each concept?"
      - Identify essential properties of each ontology concept
      - Distinguish from incidental properties

   b. Root Cause: "Are we addressing root causes or symptoms?"
      - Determine whether requirements address root causes or just symptoms
      - If symptoms, trace back to root causes

   c. Preconditions: "What must be true for this to work?"
      - Discover implicit preconditions
      - Expand the dependency graph

   d. Hidden Assumptions: "What unvalidated assumptions exist?"
      - Identify assumptions implicitly embedded in the spec
      - Assess validity of each assumption

3. Metis saves results to gen-{n}/wonder.md (Metis has Write access as teammate)
```

### Phase 2: Reflect (Audit)

```
1. Orchestrator compares previous and current generation ontologies
2. Identify ontology mutations:
   - Field changes: properties added/removed/modified
   - Type changes: concept classification changed
   - Description changes: definition refinement

3. SendMessage to eris-reflect:
   summary: "Gen {n} reflect"
   message: "Generation {n}.
     Read .olympus/{id}/gen-{n}/wonder.md for Metis's questions.
     Read .olympus/{id}/gen-{n-1}/ontology.json and .olympus/{id}/gen-{n}/ontology.json.
     {If n > 1: "Previous wonder: Read .olympus/{id}/gen-{n-1}/wonder.md to track question evolution."}
     Validate logical soundness of evolutionary decisions using fallacy-catalog.md.
     Save results to .olympus/{id}/gen-{n}/reflect.md."

4. Eris validates:
   - Confirm logical justification for each mutation
   - Detect circular reasoning, contradictions, etc.
   - Eris saves results to gen-{n}/reflect.md (Eris has Write access as teammate)
```

### Phase 3: Seed (Crystallization)

```
1. Based on wonder.md + reflect.md:
   - Update ontology (apply mutations)
   - Update spec (reflect new understanding)
2. Save Gen N+1 snapshot:
   mkdir -p .olympus/{id}/gen-{n+1}/
   - ontology.json
   - spec.md
```

### Phase 4: Convergence Check

```
Calculate ontology similarity:
  similarity = name_sim * 0.5 + type_sim * 0.3 + exact_sim * 0.2

  - name_sim: Jaccard similarity of concept name sets
  - type_sim: Cosine similarity of concept type distributions
  - exact_sim: Ratio of exactly matching concepts

Convergence decision:
  if similarity >= 0.95:
    → Stop evolution → Phase 5
  else:
    → Check for stagnation → return to Phase 1 (or trigger lateral thinking)

Stagnation detection:
  - Spinning: same ontology hash repeated 3 times
  - Oscillation: A→B→A→B 2-cycle detected
  - Diminishing: progress delta (1-similarity) < 0.01 for 3 consecutive rounds

On stagnation → auto-select lateral thinking persona:
  Stagnation type to persona mapping:
  - Spinning (same hash repeats) → Contrarian: "What if the opposite were true?"
  - Oscillation (A↔B swing) → Simplifier: "What is the simplest thing that would work?"
  - Diminishing (diminishing returns) → Researcher: "What information is missing?"

  With --interactive flag, manual selection via AskUserQuestion:
  - Hacker: "Which constraints are actually real?"
  - Simplifier: "What is the simplest thing that would work?"
  - Researcher: "What information is missing?"
  - Architect: "What if we redesigned from scratch?"
  - Contrarian: "What if the opposite were true?"

  Re-run Wonder with the selected persona's perspective

Hard cap: max 30 generations (forced stop + warning on exceed)

Save convergence.json:
{
  "generation": n,
  "similarity": 0.97,
  "converged": true,
  "stagnation": null,
  "history": [
    { "gen": 1, "similarity": 0.0 },
    { "gen": 2, "similarity": 0.45 },
    ...
  ]
}
```

### Phase 5: Lineage Management

```
Generate lineage.json:
{
  "id": "{id}",
  "total_generations": n,
  "convergence_score": 0.97,
  "generations": [
    {
      "gen": 1,
      "timestamp": "...",
      "mutations": [],
      "similarity_to_prev": null
    },
    {
      "gen": 2,
      "timestamp": "...",
      "mutations": ["added: PaymentMethod", "refined: User.role"],
      "similarity_to_prev": 0.45
    }
  ],
  "final_spec": "gen-{n}/spec.md",
  "final_ontology": "gen-{n}/ontology.json"
}

Rewind support:
- Can revert to any specific generation
- Select generation from lineage.json → load that gen-{n}/spec.md
```

### Team Teardown

Shut down the evolution team per the team-teardown.md protocol:

```
1. SendMessage(to: "metis-wonder", message: { type: "shutdown_request", reason: "Evolution converged" })
   → Await shutdown_response (approve: true)
2. SendMessage(to: "eris-reflect", message: { type: "shutdown_request", reason: "Evolution converged" })
   → Await shutdown_response (approve: true)
3. TeamDelete to clean up team resources
```
