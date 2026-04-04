---
name: genesis
description: "Creation — evolutionary loop that refines specs/designs generation by generation"
---

<Purpose>
Evolve specs/designs generation by generation until ontology convergence.
Metis and Eris operate as persistent teammates who remember previous generations.
</Purpose>

<Execution_Policy>
- This skill uses FULL TEAMMATE mode. Metis and Eris are teammates.
- Each Step MUST call the specified MCP tool. Do NOT skip MCP calls.
- Metis and Eris MUST be teammates (not subagents) — they retain cross-generation memory.
- Do NOT perform Wonder (Metis's work) or Reflect (Eris's work) directly.
- Leader handles: generation management, ontology comparison, convergence check, seed crystallization.
- IMPORTANT: Do NOT skip ToolSearch at Step 0.
</Execution_Policy>

<Team_Structure>
  team_name: "genesis-${CLAUDE_SESSION_ID}"
  (When called from Odyssey, use the Odyssey team instead)

  Teammates:
  | Agent | Role | Why Teammate |
  |-------|------|-------------|
  | metis | Wonder (inquiry) | Remembers previous generations' questions — builds on insights |
  | eris | Reflect (audit) | Tracks mutation patterns — catches recurring fallacies |

  Direct communication:
  - metis ↔ eris: Wonder/Reflect cross-reference within generation
</Team_Structure>

<Steps>

## Step 0: Load MCP Tools (REQUIRED FIRST)

```
Call ToolSearch("+olympus pipeline") to load MCP tools.
```

---

## Step 1: Initialize + Team Creation

```
1. IF standalone:
     TeamCreate(team_name: "genesis-${CLAUDE_SESSION_ID}")
   ELSE:
     Use existing Odyssey team (${TEAM})

2. olympus_start_pipeline(skill: "genesis", pipeline_id: ...)
3. Create artifact directory: .olympus/genesis-{YYYYMMDD}-{short-uuid}/

4. Extract initial ontology from spec.md:
   - Core concepts/terms
   - Each: { name, type, description, relationships }
   Save as gen-1/ontology.json + gen-1/spec.md

5. Spawn teammates (if not already in team):

   IF "metis" not in team:
     Agent(name: "metis", team_name: ${TEAM},
           subagent_type: "olympus:metis",
           prompt: "You are Metis, ontologist of the gods, a teammate in ${TEAM}.
             You will be called repeatedly across generations.
             IMPORTANT: You retain memory — build on earlier insights, do NOT repeat questions.
             You may communicate with 'eris' for cross-reference.
             Artifact directory: ${ARTIFACT_DIR}/
             Wait for messages — do not act until prompted.")
     olympus_register_agent_spawn(pipeline_id, "metis")

   IF "eris" not in team:
     Agent(name: "eris", team_name: ${TEAM},
           subagent_type: "olympus:eris",
           prompt: "You are Eris, logical auditor of evolution, a teammate in ${TEAM}.
             You will be called repeatedly across generations.
             IMPORTANT: You retain memory — track mutation patterns, catch recurring fallacies.
             You may communicate with 'metis' for cross-reference.
             Artifact directory: ${ARTIFACT_DIR}/
             Wait for messages — do not act until prompted.")
     olympus_register_agent_spawn(pipeline_id, "eris")
```

---

## Step 2: Evolution Loop (max 30 generations)

```
FOR each generation n:

  a. Create generation directory:
     mkdir -p ${ARTIFACT_DIR}/gen-{n}/

  b. Wonder (Metis):
     SendMessage(to: "metis", summary: "Gen {n} wonder",
       "Generation {n}.
        Read ${ARTIFACT_DIR}/gen-{n}/spec.md and ontology.json.
        {If n > 1: 'Previous reflection: Read gen-{n-1}/reflect.md.'}
        Answer 4 fundamental questions:
          1. Essence: What is the essential nature of each concept?
          2. Root Cause: Are we addressing root causes or symptoms?
          3. Preconditions: What must be true for this to work?
          4. Hidden Assumptions: What unvalidated assumptions exist?
        Report results to leader.")
     WAIT → leader writes gen-{n}/wonder.md
     olympus_record_execution(pipeline_id, "genesis", "metis", ...)

  c. Reflect (Eris):
     Leader compares gen-{n-1} vs gen-{n} ontologies, identifies mutations.

     SendMessage(to: "eris", summary: "Gen {n} reflect",
       "Generation {n}.
        Read ${ARTIFACT_DIR}/gen-{n}/wonder.md.
        Compare gen-{n-1}/ontology.json vs gen-{n}/ontology.json.
        {If n > 1: 'Previous wonder: Read gen-{n-1}/wonder.md to track question evolution.'}
        Validate logical soundness per fallacy-catalog.md.
        Report results to leader.")
     WAIT → leader writes gen-{n}/reflect.md
     olympus_record_execution(pipeline_id, "genesis", "eris", ...)

  d. Seed (Crystallization):
     Based on wonder.md + reflect.md:
       - Apply ontology mutations
       - Update spec with new understanding
     Save gen-{n+1}/ontology.json + gen-{n+1}/spec.md

  e. Convergence Check:
     similarity = name_sim * 0.5 + type_sim * 0.3 + exact_sim * 0.2
     olympus_gate_check(pipeline_id, "convergence", similarity)

     IF similarity >= 0.95:
       → BREAK: evolution converged → Step 3

     IF stagnation detected:
       - Spinning (same hash 3×): → Contrarian persona
       - Oscillation (A↔B 2-cycle): → Simplifier persona
       - Diminishing (delta < 0.01 for 3 rounds): → Researcher persona

       With --interactive: AskUserQuestion for persona selection
       SendMessage(to: "metis", "Re-run wonder with {persona} perspective")

     Hard cap: 30 generations → forced stop with warning

  Save convergence.json after each generation.
```

---

## Step 3: Lineage Management

```
Generate lineage.json:
{
  "id": "{id}",
  "total_generations": n,
  "convergence_score": 0.97,
  "generations": [
    { "gen": 1, "mutations": [], "similarity_to_prev": null },
    { "gen": 2, "mutations": ["added: X", "refined: Y"], "similarity_to_prev": 0.45 },
    ...
  ],
  "final_spec": "gen-{n}/spec.md",
  "final_ontology": "gen-{n}/ontology.json"
}

Rewind support: select generation from lineage → load that gen's spec.md
```

---

## Step 4: Teardown

```
IF standalone:
  SendMessage(to: "metis", message: { type: "shutdown_request", reason: "Evolution converged" })
  WAIT for shutdown_response
  SendMessage(to: "eris", message: { type: "shutdown_request", reason: "Evolution converged" })
  WAIT for shutdown_response
  TeamDelete(team_name: "genesis-${CLAUDE_SESSION_ID}")
ELSE:
  Teammates persist for Odyssey's next phase (Pantheon)
  ← metis and eris retain evolution insights for downstream analysis
```

</Steps>

<Tool_Usage>
  MCP Tools:
  - olympus_start_pipeline: Step 1 (MUST)
  - olympus_register_agent_spawn: after team creation (MUST)
  - olympus_gate_check: each convergence check (MUST)
  - olympus_record_execution: each generation (SHOULD)

  Team Tools:
  - TeamCreate: Step 1 (standalone only)
  - Agent (name + team_name): spawn metis, eris
  - SendMessage: wonder/reflect per generation
  - TeamDelete: Step 4 (standalone only)
</Tool_Usage>

<Artifact_Contracts>
  | File | Step | Writer | Readers |
  |------|------|--------|---------|
  | gen-{n}/ontology.json | 2d | Leader | Convergence check |
  | gen-{n}/spec.md | 2d | Leader | Next generation |
  | gen-{n}/wonder.md | 2b | Leader (from metis) | eris |
  | gen-{n}/reflect.md | 2c | Leader (from eris) | Next seed |
  | lineage.json | 3 | Leader | Rewind support |
  | convergence.json | 2e | Leader | Evolution halt decision |
</Artifact_Contracts>
