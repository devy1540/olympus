# Ambiguity Scoring

## Overview

Ambiguity scoring quantifies how vague or unclear a requirement specification is. It is used as a gate check during the Oracle skill's requirement refinement process.

## Scale (Clarity Scores — higher = clearer)

Apollo reports **clarity scores** (0.0 = completely vague, 1.0 = crystal clear) for each dimension.
The gate then computes the ambiguity score as `1 - weighted_clarity`. This keeps the gate threshold intuitive (low ambiguity = pass).

- **1.00** -- Crystal clear: No interpretation variance possible
- **0.75** -- Mostly clear: Minor clarification may help
- **0.50** -- Partially clear: Significant ambiguity remains
- **0.25** -- Mostly vague: Only general direction discernible
- **0.00** -- Completely vague: No discernible objective

## Dimensions & Weights

| Dimension   | Weight | Question                                      |
|-------------|--------|-----------------------------------------------|
| Goal        | 40%    | Is the objective measurable and specific?      |
| Constraints | 30%    | Are boundaries and limitations explicit?       |
| AC          | 30%    | Are acceptance criteria testable?              |

## Gate Threshold

A requirement passes the ambiguity gate when the final ambiguity score is **<= 0.2**.

## Scoring Rubric

### Goal (40%)

| Clarity Score | Description                                                          |
|---------------|----------------------------------------------------------------------|
| 1.00          | Objective is fully measurable with clear success metric              |
| 0.75          | Objective is clear but success metric could be more precise          |
| 0.50          | Objective is understandable but open to multiple interpretations     |
| 0.25          | Objective is vague, only general direction is discernible            |
| 0.00          | No discernible objective or completely ambiguous intent              |

### Constraints (30%)

| Clarity Score | Description                                                          |
|---------------|----------------------------------------------------------------------|
| 1.00          | All boundaries, limitations, and non-goals are explicitly stated    |
| 0.75          | Most constraints are stated; minor implicit assumptions remain      |
| 0.50          | Some constraints are stated but significant gaps exist              |
| 0.25          | Few constraints mentioned; mostly implicit                          |
| 0.00          | No constraints specified; scope is unbounded                        |

### Acceptance Criteria (30%)

| Clarity Score | Description                                                          |
|---------------|----------------------------------------------------------------------|
| 1.00          | All AC are testable with clear pass/fail conditions                 |
| 0.75          | AC are mostly testable; minor subjectivity in one or two criteria  |
| 0.50          | AC exist but several are subjective or hard to verify               |
| 0.25          | AC are vague or incomplete; most cannot be objectively tested       |
| 0.00          | No acceptance criteria defined                                      |

## Aggregation Formula

Apollo reports clarity scores; the gate computes ambiguity:

```
weighted_clarity = goal * 0.4 + constraints * 0.3 + ac * 0.3
ambiguity_score  = 1 - weighted_clarity
```

Gate passes when `ambiguity_score <= 0.2`, i.e., `weighted_clarity >= 0.8`.

## Example

Given (clarity scores):
- Goal: 0.75 — "mostly clear, success metric could be more precise"
- Constraints: 1.00 — "all boundaries explicitly stated"
- AC: 0.75 — "mostly testable"

```
weighted_clarity = 0.75 * 0.4 + 1.00 * 0.3 + 0.75 * 0.3
                 = 0.300 + 0.300 + 0.225
                 = 0.825
ambiguity_score  = 1 - 0.825 = 0.175
```

Result: **0.175** -- passes the gate (<= 0.2).
