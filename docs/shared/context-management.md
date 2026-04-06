# Context Management Protocol

## Source

Direct port of Claude Code's auto-compaction logic:
- `src/services/compact/autoCompact.ts` (lines 71-239)
- `calculateTokenWarningState()` threshold system
- `shouldAutoCompact()` trigger logic

## Overview

Long-running pipelines (Odyssey, Evolve) accumulate context across multiple phases and agent interactions. Without management, context exceeds model limits and degrades output quality. This protocol defines when and how to compact context, ported from Claude Code's production compaction strategy.

---

## 1. Token Budget Thresholds

Ported from `autoCompact.ts` constants:

```
┌──────────────────────────────────────────────────────────────────┐
│                     Model Context Window                          │
│                                                                    │
│  ├─── Safe zone ──────────────────┤ WARNING │ ERROR │ BLOCKING │  │
│  0                            window-20k  window-13k  window-3k   │
│                                    │         │          │          │
│                                    │         │          │          │
│                               warn here  compact    hard stop     │
│                                          here        here         │
└──────────────────────────────────────────────────────────────────┘

Claude Code production values (autoCompact.ts):
  AUTOCOMPACT_BUFFER_TOKENS    = 13,000  (compact trigger)
  WARNING_THRESHOLD_BUFFER     = 20,000  (warning indicator)
  MANUAL_COMPACT_BUFFER_TOKENS =  3,000  (blocking limit)
```

### Olympus Adaptation

Since olympus orchestrates via skills (not a persistent REPL loop), token management is per-phase:

| Threshold | Formula | Action |
|-----------|---------|--------|
| **Warning** | Phase uses > 60% of model context | Log warning, consider splitting |
| **Compact** | Phase uses > 80% of model context | Summarize prior phase outputs before continuing |
| **Blocking** | Phase uses > 95% of model context | Must compact before proceeding |

## 2. Compaction Strategies

Ported from Claude Code's 5-stage compaction pipeline (`query.ts` lines 400-500):

### Strategy 1: Artifact Summarization (mirrors "snip compact")

When transitioning between pipeline phases, summarize prior artifacts instead of carrying full content.

```
BEFORE Phase 4 (planning):
  Context includes: full spec.md + full analysis.md + full codebase-context.md

AFTER compaction:
  Context includes: spec.md summary (GOAL + AC only) + analysis.md key findings only
  Full artifacts remain on disk for Read access
```

**When to apply:** Between every major phase transition in Odyssey.

### Strategy 2: Selective Loading (mirrors "content replacement")

Agents load only the sections they need from large artifacts via targeted Read + Grep.

```
Instead of: Read entire spec.md (may be 5000+ tokens)
Do:         Grep spec.md for ACCEPTANCE_CRITERIA section, Read that range only
```

**When to apply:** Already enforced by Artifact Reference Protocol (worker-preamble.md).

### Strategy 3: Phase Summary Injection (mirrors "auto-compact")

When a phase produces a long conversation history (e.g., Apollo interview with 10 rounds), the orchestrator generates a brief summary before handing off to the next phase.

```
Phase 2 (Apollo interview, 10 rounds) →
  Interview Summary:
    - 3 key decisions made
    - Final ambiguity score: 0.15
    - Remaining gaps: [list]

  (Full interview-log.md preserved on disk)
```

**When to apply:** After any phase with > 5 interaction rounds.

### Strategy 4: Stale Context Pruning (mirrors "context collapse")

In feedback loops (Pantheon Phase 3-4 retry, Odyssey evaluation retry), prune stale context from prior failed iterations.

```
BEFORE retry:
  Context includes: iteration 1 findings + iteration 1 DA challenges + iteration 2 findings

AFTER pruning:
  Context includes: prior-iterations.md summary + iteration 2 findings only
```

**When to apply:** On any feedback loop re-entry.

---

## 3. Per-Skill Compaction Points

### Odyssey
| Transition | Compaction Action |
|-----------|-------------------|
| Oracle → Genesis | Summarize interview-log.md to key decisions only |
| Genesis → Pantheon | Carry only final gen-{n}/spec.md, drop intermediate generations |
| Pantheon → Planning | Summarize analysis.md to recommendations only |
| Planning → Execution | plan.md is already compact; no action needed |
| Execution → Tribunal | Summarize implementation changes to file list + key modifications |
| Tribunal → retry | Prune prior verdict, carry only failure reasons |
| Tribunal → Oracle (REJECTED_SPEC) | Drop all implementation/execution history; carry only rejection reason, unmet ACs, spec defects |
| Tribunal → Pantheon (REJECTED_ARCHITECTURE) | Drop all implementation/execution history; carry only rejection reason, architectural issues, analysis gaps |

### Evolve
| Transition | Compaction Action |
|-----------|-------------------|
| Dogfood → Evaluate | Summarize dogfood-result.md to metrics only |
| Diagnose → Refine | diagnosis.md is already structured; no action needed |
| Iteration N → N+1 | Prune prior iteration details, keep only scores + key changes |

### Genesis
| Transition | Compaction Action |
|-----------|-------------------|
| gen-{n} → gen-{n+1} | Drop gen-{n-2} and older from active context (on-disk only) |
| Stagnation → Persona | Summarize last 3 generations' mutations to a diff |

### Review-PR
| Transition | Compaction Action |
|-----------|-------------------|
| Hermes → Helios | pr-context.md is already compact; carry as-is |
| Helios → Reviewers | review-perspectives.md is small; carry as-is |
| Reviewers → Eris | Summarize review-findings.md to top-N findings per severity (drop low-confidence) |
| Eris → Nemesis | Carry da-evaluation.md full; reviewers' raw findings already in review-findings.md |

---

## 4. Orchestrator Responsibility

The orchestrator is responsible for:

1. **Tracking context budget** — estimate token usage per phase
2. **Triggering compaction** — at phase transitions per the table above
3. **Preserving on-disk** — compaction is lossy for context but lossless on disk (all artifacts remain)
4. **Injecting summaries** — when compacting, inject a summary rather than carrying full artifacts

This aligns with the Artifact Reference Protocol: agents Read from disk, orchestrator manages what's in the active context.
