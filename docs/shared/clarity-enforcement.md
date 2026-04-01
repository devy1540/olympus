# Clarity Enforcement

## Overview

Clarity enforcement ensures that all analysis outputs produced by Olympus agents are precise, evidence-backed, and free of vague language. Every agent must self-check its outputs against these rules before submission.

## Banned Phrases

The following phrases are **prohibited** in all agent outputs. Their presence triggers an automatic warning or rejection.

| Banned Phrase         | Why It Is Banned                                      | Alternative                                    |
|-----------------------|-------------------------------------------------------|------------------------------------------------|
| "it depends"          | Defers judgment without specifying conditions          | State the specific conditions and outcomes     |
| "generally"           | Implies exceptions without naming them                 | State the rule and list known exceptions       |
| "might"               | Expresses uncertainty without quantifying it           | State probability or conditions for occurrence |
| "could potentially"   | Double hedge -- maximally vague                        | State what conditions would cause it           |
| "in some cases"       | Unnamed cases are not actionable                       | Name the specific cases                        |
| "arguably"            | Avoids taking a position                               | State the argument and evaluate it             |
| "it seems"            | Subjective impression without evidence                 | Provide evidence or state uncertainty bounds   |

## Required Evidence

Every claim in an agent's output must be supported by **at least one** of the following evidence types:

| Evidence Type       | Format                          | Example                                         |
|---------------------|---------------------------------|-------------------------------------------------|
| File:line reference | `file:line`                     | `src/auth/login.ts:42`                          |
| Test result         | Test name + pass/fail           | `test_login_invalid_password: PASS`             |
| Metric              | Named metric + value            | `p99 latency: 230ms`                            |
| External citation   | URL or document reference       | `RFC 7519 Section 4.1`                          |

## Severity Levels

Violations are classified into three severity levels:

### CRITICAL

**Trigger:** A claim is made with **no evidence** whatsoever.

**Action:** The output is **rejected**. The agent must revise and provide evidence before resubmission.

**Example violation:**
> "This function is a performance bottleneck."

**Corrected:**
> "This function is a performance bottleneck -- profiling shows it accounts for 34% of request latency (`src/api/handler.ts:87`, metric: avg execution time 120ms)."

### WARNING

**Trigger:** A **vague qualifier** from the banned phrases list is used.

**Action:** The output is **flagged**. The agent must replace the vague phrase with a precise statement.

**Example violation:**
> "This approach might cause memory issues in some cases."

**Corrected:**
> "This approach causes memory growth of ~50MB per 1000 connections when connection pooling is disabled (`src/db/pool.ts:23`)."

### INFO

**Trigger:** A statement **could be more specific** but is not technically vague or unsupported.

**Action:** The output is **noted** for potential improvement. No revision required.

**Example:**
> "The module has high coupling with 3 other modules."

**Improved:**
> "The module `src/billing/invoice.ts` imports from `src/user/profile.ts:12`, `src/payment/stripe.ts:5`, and `src/notification/email.ts:30`, creating coupling across 3 domain boundaries."

## Scope Fidelity Rule

When analyzing a spec, agents must distinguish between spec-stated and spec-external concerns:

- **[SPEC_STATED]**: Items explicitly defined in the spec. These must NEVER be reported as "unspecified" or "missing."
- **[SPEC_EXTERNAL]**: Items not in the spec but identified as relevant by the analyst. These MUST be tagged with `[SPEC_EXTERNAL]` and include a rationale for why they are relevant.

Reporting a spec-stated item as "unspecified" is a **CRITICAL violation** — equivalent to making a claim with no evidence (the spec IS the evidence, and it was not consulted).

Analyzing features that do not exist in the spec without the `[SPEC_EXTERNAL]` tag is a **CRITICAL violation** — it represents scope creep without disclosure.

## Enforcement Protocol

1. **Self-check**: Before submitting output, every agent runs its own content through the banned phrase list and evidence requirement check.
2. **Peer-check**: In team contexts, the reviewing agent (e.g., Eris as Devil's Advocate) applies clarity enforcement during evaluation.
3. **Gate-check**: The orchestrator verifies compliance before including output in the final artifact.

Outputs with any CRITICAL violations are not included in the final artifact until resolved.
