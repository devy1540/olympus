# Consensus Levels

## Overview

Consensus levels define the degree of agreement required among participants (agents or perspectives) before proceeding with a decision. Different modes of operation require different consensus thresholds.

## Level Definitions

### Strong Consensus (100%)

- **Threshold:** 3/3 participants agree, or all participants unanimous
- **Meaning:** Complete alignment with no dissent
- **Action:** Proceed without reservation
- **Usage:** Required in Hell mode (`--hell`) for all decisions

### Working Consensus (≥66%)

- **Threshold:** 2/3 participants agree (gate value: 0.66 — 2÷3=0.6667 must pass; 0.67 would incorrectly reject it)
- **Meaning:** Clear majority with documented minority position
- **Action:** Proceed with noted dissent documented in the artifact
- **Usage:** Default threshold in Normal mode for proceeding

### Partial Consensus (60%+)

- **Threshold:** Slightly above simple majority but below working consensus
- **Meaning:** Weak majority -- agreement is fragile
- **Action:** Requires one of:
  - An additional discussion round among participants
  - Escalation to the user for a deciding vote via `AskUserQuestion`
- **Usage:** Triggers a feedback loop before proceeding

### No Consensus (<60%)

- **Threshold:** Below 60% agreement
- **Meaning:** Fundamental disagreement among participants
- **Action:** Requires one of:
  - Escalation to the user with all positions presented via `AskUserQuestion`
  - Triggering a structured feedback loop (re-analysis with additional context)
- **Usage:** Cannot proceed without resolution

## Mode-Specific Thresholds

| Mode   | Flag     | Minimum Threshold | Behavior on Failure                        |
|--------|----------|-------------------|--------------------------------------------|
| Normal | (none)   | Working (>=66%, i.e. 2/3)   | Proceed with dissent documented            |
| Hell   | `--hell` | Strong (100%)     | Loop until unanimous or user intervenes    |

## Consensus Recording

When consensus is reached, the record must include:

```json
{
  "level": "strong | working | partial | none",
  "percentage": 0.6667,
  "for": ["perspective-A", "perspective-B"],
  "against": ["perspective-C"],
  "abstain": [],
  "dissent_summary": "Perspective-C argues that...",
  "resolution": "Proceeding with working consensus per normal mode rules"
}
```

## Dissent Documentation

When proceeding with less than strong consensus, the dissenting position must be documented with:

1. **Who dissented:** The perspective or agent name
2. **What they argued:** A summary of the dissenting position
3. **Why it was overruled:** The rationale for proceeding despite dissent
4. **Risk acknowledgment:** Any risks introduced by overruling the dissent
