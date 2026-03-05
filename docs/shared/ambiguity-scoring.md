# Ambiguity Scoring

## Overview

Ambiguity scoring quantifies how vague or unclear a requirement specification is. It is used as a gate check during the Oracle skill's requirement refinement process.

## Scale

- **0.0** -- Crystal clear: No interpretation variance possible
- **1.0** -- Completely vague: Infinite valid interpretations

## Dimensions & Weights

| Dimension   | Weight | Question                                      |
|-------------|--------|-----------------------------------------------|
| Goal        | 40%    | Is the objective measurable and specific?      |
| Constraints | 30%    | Are boundaries and limitations explicit?       |
| AC          | 30%    | Are acceptance criteria testable?              |

## Gate Threshold

A requirement passes the ambiguity gate when the aggregated score is **<= 0.2**.

## Scoring Rubric

### Goal (40%)

| Score | Description                                                                 |
|-------|-----------------------------------------------------------------------------|
| 0.00  | Objective is fully measurable with clear success metric                     |
| 0.25  | Objective is clear but success metric could be more precise                 |
| 0.50  | Objective is understandable but open to multiple interpretations            |
| 0.75  | Objective is vague, only general direction is discernible                   |
| 1.00  | No discernible objective or completely ambiguous intent                     |

### Constraints (30%)

| Score | Description                                                                 |
|-------|-----------------------------------------------------------------------------|
| 0.00  | All boundaries, limitations, and non-goals are explicitly stated            |
| 0.25  | Most constraints are stated; minor implicit assumptions remain              |
| 0.50  | Some constraints are stated but significant gaps exist                      |
| 0.75  | Few constraints mentioned; mostly implicit                                  |
| 1.00  | No constraints specified; scope is unbounded                                |

### Acceptance Criteria (30%)

| Score | Description                                                                 |
|-------|-----------------------------------------------------------------------------|
| 0.00  | All AC are testable with clear pass/fail conditions                         |
| 0.25  | AC are mostly testable; minor subjectivity in one or two criteria           |
| 0.50  | AC exist but several are subjective or hard to verify                       |
| 0.75  | AC are vague or incomplete; most cannot be objectively tested               |
| 1.00  | No acceptance criteria defined                                              |

## Aggregation Formula

```
score = goal * 0.4 + constraints * 0.3 + ac * 0.3
```

## Example

Given:
- Goal score: 0.25
- Constraints score: 0.0
- AC score: 0.25

```
score = 0.25 * 0.4 + 0.0 * 0.3 + 0.25 * 0.3
     = 0.10 + 0.00 + 0.075
     = 0.175
```

Result: **0.175** -- passes the gate (<= 0.2).
