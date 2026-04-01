---
name: agora
description: "The Forum — committee debate for technical decision-making"
---

# /olympus:agora — The Forum

Structured committee debate for reaching technical decisions through consensus-driven discourse.

## Agents (subagent_type bindings)
- **Zeus**: Planner role (tie-breaker) → `subagent_type: "olympus:zeus"`
- **Ares**: Engineering critic → `subagent_type: "olympus:ares"`
- **Eris**: Devil's Advocate (challenges all positions) → `subagent_type: "olympus:eris"`
- **UX Critic**: UX critic → `subagent_type: "general-purpose"` (UX prompt injection)

## Gate
- Normal: Working consensus (≥67%)
- Hell mode (--hell): Unanimous

---

## Execution Flow

```
Phase 1 → Phase 2 → Phase 3 (max 3 rounds) → Phase 4 → Phase 5 → Phase 6
                          ↑                                  ↓
                          └────── Disagreement ──────────────┘
```

### Phase 1: Question Framing

```
Structure the user's decision:

1. Extract the decision from user input
2. Convert to 2-4 concrete options
3. Confirm via AskUserQuestion:
   question: "The debate will be structured as follows. Any modifications?"
   options:
     - "Proceed": continue with current framing
     - "Modify options": edit options
     - "Add context": provide additional context
     - "Cancel": abort

Generate debate frame document:
{
  "question": "Which authentication method should we use?",
  "options": [
    { "id": "A", "title": "JWT", "description": "..." },
    { "id": "B", "title": "Session", "description": "..." },
    { "id": "C", "title": "OAuth2", "description": "..." }
  ],
  "context": "..."
}
```

### Phase 2: Committee Assembly

```
Based on the Prism committee pattern:

1. UX Critic:
   - general-purpose agent with UX perspective prompt
   - "Evaluate each option from user experience, accessibility, and usability perspectives"

2. Engineering Critic:
   - Ares (olympus:ares)
   - "Evaluate from technical feasibility, maintainability, and scalability perspectives"

3. Planner (tie-breaker):
   - Zeus (olympus:zeus)
   - "Evaluate from strategic perspective. Make the final call when UX/Engineering disagree"
```

### Phase 3: Debate Rounds (max 3)

```
Each round:

1. Each committee member presents their position independently (Tasks in parallel):
   - Preferred option + rationale
   - Pros/cons of other options
   - Must comply with clarity-enforcement

2. Orchestrator identifies disagreements:
   - Compare each member's preference
   - Clearly articulate points of disagreement

3. Cross-questioning (when disagreements exist):
   - Request each member to rebut other members' arguments
   - Opportunity to present new evidence or perspectives

4. Measure consensus level (per consensus-levels.md):
   - Strong (3/3): unanimous → exit immediately
   - Working (2/3): majority agrees → record dissent and exit
   - Partial: additional round needed
   - No: additional round or escalation

5. Proceed to Phase 4 when consensus reached or 3 rounds complete
```

### Phase 4: Eris Challenge

```
1. Spawn Eris as a Task:
   - Prompt: artifact directory path
   - Instruction: "Use Read to load committee positions and consensus state directly"
   - Mission: challenge all positions (both accepted and rejected)

2. Eris challenges:
   - Weaknesses of the consensus option
   - Overlooked strengths of rejected options
   - Logical fallacy detection per fallacy-catalog

3. Committee response (if needed):
   - Eris's challenges may change the consensus
   - Re-measure consensus if changed
```

### Phase 5: Consensus → Recommendation

```
Normal mode:
  - Working or above → proceed
  - Partial → Zeus makes tie-breaker decision
  - No → escalate to user

Hell mode (--hell):
  - Strong required (unanimous)
  - Additional rounds if not met (no limit)

Generate recommendation:
  ## Decision: {selected option}

  ### Rationale
  - {key reason 1}
  - {key reason 2}

  ### Committee Positions
  | Member | Position | Key Argument |
  |---|---|---|
  | UX Critic | {option} | {argument} |
  | Engineering (Ares) | {option} | {argument} |
  | Planner (Zeus) | {option} | {argument} |

  ### Dissent
  - {minority opinion + rationale}

  ### DA Challenges (Eris)
  - {resolved challenges}
  - {unresolved challenges + risks}

  ### Consensus Level: {Strong/Working/Partial}

  ### Implementation Notes
  - {notes for implementing the chosen option}
```

### Phase 6: Team Teardown

Shut down all committee members per the team-teardown.md protocol.
