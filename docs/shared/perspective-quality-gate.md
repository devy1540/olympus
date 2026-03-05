# Perspective Quality Gate

## Overview

The Perspective Quality Gate ensures that every perspective generated in the Pantheon skill meets a minimum quality bar before inclusion in the analysis. Perspectives that fail any criterion are rejected and must be revised or discarded.

## Criteria

All **4 criteria** must be met for a perspective to pass the gate.

### 1. Orthogonality

Each perspective must cover a **distinct dimension** of the problem space. Overlap with any other accepted perspective must not exceed **20%**.

**How to measure overlap:**
- List the key concerns, files, and recommendations of each perspective
- Compute the ratio of shared items to total items
- If shared items / total items > 0.20 for any pair, the perspectives are not orthogonal

**Pass condition:** Overlap with every other perspective <= 20%.

### 2. Evidence-based

Every claim within a perspective must be backed by at least one piece of evidence.

**Acceptable evidence types:**
- `file:line` reference to source code
- Test result (pass/fail with test name)
- Measurable metric (performance number, coverage percentage, etc.)
- External citation (documentation URL, RFC, specification)

**Pass condition:** Zero unsupported claims. Every assertion references at least one evidence source.

### 3. Domain-specific

The perspective must be **relevant to the problem domain** under analysis. Generic observations that could apply to any codebase or any problem are insufficient.

**Indicators of domain-specificity:**
- References domain concepts, entities, or business rules
- Addresses domain-specific constraints or requirements
- Uses domain terminology accurately

**Pass condition:** The perspective addresses concerns specific to the problem domain, not generic software observations.

### 4. Actionable

The perspective must produce **concrete recommendations** that can be directly acted upon. Abstract observations without clear next steps are insufficient.

**Actionable means:**
- Specific files or components to change
- Concrete steps to implement
- Measurable outcomes expected from the action

**Not actionable:**
- "Consider improving performance"
- "Think about edge cases"
- "This area needs attention"

**Pass condition:** Every recommendation is concrete and implementable.

## Gate Enforcement

| Result   | Action                                                        |
|----------|---------------------------------------------------------------|
| All pass | Perspective is included in the analysis                       |
| Any fail | Perspective is rejected with specific failure reasons noted   |

Rejected perspectives may be revised and re-submitted through the feedback loop. The revision must address all noted failure reasons.
