**English** | [한국어](docs/ko/README.md)

<p align="center">
  <br/>
  <strong>&#x1D6C0; ─────────── &#x1D6C0;</strong>
  <br/><br/>
  <strong>O L Y M P U S</strong>
  <br/>
  <sub>올 림 푸 스</sub>
  <br/><br/>
  <strong>&#x1D6C0; ─────────── &#x1D6C0;</strong>
  <br/>
</p>

<p align="center">
  <em>"The gods merely pose questions. Fate lies in what I ask — the answers are yours to find."</em>
  <br/>
  <sub>15 gods argue, challenge, and verify — so your software doesn't ship on assumptions.</sub>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> ·
  <a href="#philosophy">Philosophy</a> ·
  <a href="#the-pipeline">Pipeline</a> ·
  <a href="#skills">Skills</a> ·
  <a href="#the-fourteen-gods">Agents</a> ·
  <a href="docs/EXAMPLES.md">Examples</a>
</p>

---

> *The gods don't agree. That's the point.*

Olympus is a **harness engineering plugin** for Claude Code. 15 agents — each a Greek deity with a distinct role and strict permissions — refine requirements, analyze from multiple perspectives, implement, and evaluate your software through structured adversarial collaboration.

Most AI coding fails because nobody questioned the requirements. Olympus forces the question before allowing the answer.

---

## Philosophy

> *"Know thyself"* — Inscription at the Temple of Apollo at Delphi

Software fails at three points: **unclear requirements**, **unchallenged assumptions**, and **unverified outcomes**. Olympus addresses all three through separation of concerns at the agent level:

```
  The one who plans (Zeus)     cannot review their own plan (Themis does).
  The one who builds (Prometheus) cannot evaluate their own work (Athena does).
  The one who analyzes (Ares)  must survive the devil's advocate (Eris does).
```

This is not bureaucracy — it's **structural honesty**. Every claim requires `file:line` evidence. Every analysis survives adversarial challenge. Every gate has a mathematical threshold, not a vibes check.

```
  Ambiguity Gate     ≤ 0.2    "Are we clear enough to build?"
  Convergence Gate   ≥ 0.95   "Has the spec stabilized?"
  Consensus Gate     ≥ 67%    "Do the reviewers agree?"
  Quality Gate       ≥ 0.8    "Is the output good enough?"
```

Four numbers. Four moments where the system refuses to proceed until the math says yes.

---

## Quick Start

```bash
# In your terminal
claude plugin marketplace add devy1540/olympus
claude plugin install olympus@olympus-marketplace
```

```
# Inside Claude Code
/plugin marketplace add devy1540/olympus
/plugin install olympus@olympus-marketplace

# Verify installation
/olympus:setup

# Project onboarding — scan your project and get a recommendation
/olympus:hestia

# Refine your requirements
/olympus:oracle

# Full pipeline: requirements → analysis → implementation → evaluation
/olympus:odyssey
```

<details>
<summary><strong>What just happened?</strong></summary>

```
/olympus:oracle    →  Socratic interview exposed hidden assumptions
                      Ambiguity scored and gated (≤ 0.2)
                      Gap analysis against your codebase
                      → spec.md

/olympus:odyssey   →  Oracle (refine) → Genesis (evolve) → Pantheon (analyze)
                      → Plan + Implement → Tribunal (evaluate)
                      → verdict.md
```

The gods deliberated. Your spec survived the gauntlet.

</details>

---

## The Pipeline

Olympus operates as a pipeline of specialized skills, each orchestrating multiple agents:

```
    Oracle → Genesis → Pantheon → Plan → Execute → Tribunal
     (ask)   (evolve)  (analyze)  (design) (build)  (judge)
       ↑                                               ↓
       └──────────── Rejected? Retry or rewind ─────────┘
```

Each stage has a **gate**. No stage proceeds without passing.

| Stage | Gate | Threshold | What Happens |
|:------|:-----|:---------:|:-------------|
| **Oracle** | Ambiguity Score | ≤ 0.2 | Socratic interview until requirements are 80%+ clear |
| **Genesis** | Ontology Convergence | ≥ 0.95 | Spec evolves generation by generation until stable |
| **Pantheon** | Consensus | ≥ 67% | Multi-perspective analysis survives devil's advocate |
| **Tribunal** | Mechanical + Semantic | Pass all | Build, test, type-check, then AC verification |

---

## Skills

### `/olympus:oracle` — The Oracle of Delphi

Turn vague ideas into validated specifications.

```
Hermes (explore) → Apollo (interview) → Ambiguity Gate → Metis (gap analysis) → spec.md
```

### `/olympus:genesis` — Creation

Evolve specifications through generational iteration.

```
Seed → Metis (wonder) → Eris (reflect) → Next Seed → Convergence? (≥ 0.95)
  ↑                                                        ↓ NO
  └────────────────────────────────────────────────────────┘
```

- Stagnation detection: spinning, oscillation, diminishing returns
- Up to 30 generations with full lineage tracking

### `/olympus:pantheon` — Council of the Gods

Analyze problems from multiple orthogonal perspectives.

```
Helios (perspectives) → Ares + Poseidon + Zeus (parallel analysis) → Eris (challenge) → Consensus
```

- 3–6 orthogonal perspectives, each passing a quality gate
- 22-item fallacy catalog for logical verification
- Devil's advocate challenges every conclusion

### `/olympus:tribunal` — Trial of the Gods

Three-stage evaluation: mechanical, semantic, consensual.

```
Stage 1: Hephaestus (build/test/lint)    → FAIL → BLOCKED
Stage 2: Athena (AC verification)         → FAIL → INCOMPLETE
Stage 3: Ares + Eris + Hera (consensus)  → APPROVED / REJECTED
```

### `/olympus:agora` — The Forum

Structured committee debate for technical decisions.

```
Framing → Committee (3 roles) → Debate (≤ 3 rounds) → Eris (challenge) → Decision
```

### `/olympus:odyssey` — The Grand Journey

Full pipeline orchestration from requirements to verdict.

```
Oracle → Genesis → Pantheon → Zeus + Themis → Prometheus → Tribunal
 spec     evolve    analysis    plan + review   implement    verdict
```

- Up to 3 retries on Tribunal rejection, then rewind to Genesis
- Full state persistence via `odyssey-state.json`

### `/olympus:review-pr` — Trial of Nemesis

Multi-perspective PR review with adversarial challenge and confidence-calibrated verdict.

```
Hermes (recon) → Helios (perspectives) → Ares + Poseidon + dynamic (parallel review)
  → Eris (challenge) → Nemesis (synthesis) → verdict + GitHub review comments
```

**Interactive mode** — review a specific PR, branch, or commit range:

```
/olympus:review-pr 123              # PR number
/olympus:review-pr feature/auth     # Branch name
/olympus:review-pr                  # Current branch vs main
```

**Auto mode** — poll for unreviewed PRs and review them automatically:

```
/olympus:review-pr --auto --repo myorg/myrepo --base main
```

Combine with `/loop` or `/schedule` for continuous review:

```
/loop 5m /olympus:review-pr --auto --repo myorg/myrepo --base main
/schedule create --cron "*/15 * * * *" --prompt "/olympus:review-pr --auto --repo myorg/myrepo"
```

- Posts a "Review Started" comment on the PR, updates it with the verdict on completion
- Optional `--spec` flag for domain-aware review (checks against acceptance criteria)
- Inline GitHub review comments with severity and confidence scores

### `/olympus:audit` — Self-Inspection

Validate the plugin's own internal consistency.

```
Hephaestus (structural) → Athena (semantic) → audit-report.md
```

### `/olympus:evolve` — Self-Evolution

Improve Olympus itself through benchmarking and behavioral evaluation.

```
Benchmark → Dogfood → Evaluate (5 dims) → Diagnose → Refine → Audit → Loop
```

- 5 evaluation dimensions: Specificity, Evidence Density, Role Adherence, Efficiency, Actionability
- Converges at overall score ≥ 0.8, max 5 iterations

---

## The Fourteen Gods

| Agent | Role | Model | Permissions |
|:------|:-----|:-----:|:------------|
| **Zeus** | Planner — strategy and task decomposition | opus | full |
| **Athena** | Semantic Evaluator — AC compliance verification | opus | read-only |
| **Apollo** | Interviewer — Socratic questioning | opus | read-only |
| **Hermes** | Explorer — codebase reconnaissance | haiku | read-only |
| **Ares** | Code Reviewer — defects and anti-patterns | opus | read-only |
| **Hera** | Verifier — test execution and quality gate | sonnet | write |
| **Poseidon** | Security Reviewer — OWASP Top 10 | opus | read-only |
| **Prometheus** | Executor — code implementation | sonnet | full |
| **Artemis** | Debugger — root cause analysis | sonnet | full |
| **Metis** | Analyst — gap analysis and assumption verification | opus | read-only |
| **Themis** | Critic — independent plan/output review | opus | read-only |
| **Hephaestus** | Mechanical Evaluator — build, lint, test, typecheck | sonnet | full |
| **Eris** | Devil's Advocate — fallacy detection and challenges | opus | read-only |
| **Helios** | Perspective Generator — orthogonal viewpoints | opus | read-only |

### The Delegation Pattern

10 of 15 agents are **read-only**. They cannot write files. Instead:

```
Read-only Agent → SendMessage(result) → Orchestrator → Write(file)
```

This isn't a limitation — it's a **security boundary**. Only agents with proven need get write access.

---

<details>
<summary><strong>Shared Protocols</strong></summary>

| Protocol | Purpose |
|:---------|:--------|
| `ambiguity-scoring.md` | Quantitative requirement clarity (0.0–1.0, gate ≤ 0.2) |
| `artifact-contracts.md` | Who writes what, who reads what, at which phase |
| `clarity-enforcement.md` | Banned phrases + evidence requirements |
| `consensus-levels.md` | Strong / Working / Partial / No consensus definitions |
| `fallacy-catalog.md` | 22 logical fallacies for adversarial verification |
| `source-scope-mapping.md` | MCP data source discovery and analysis source pool |
| `perspective-quality-gate.md` | 4 criteria: Orthogonality, Evidence, Domain, Actionable |
| `team-teardown.md` | Graceful agent shutdown protocol |
| `worker-preamble.md` | Standard worker agent lifecycle |

</details>

<details>
<summary><strong>Artifact Structure</strong></summary>

All artifacts are stored under `.olympus/{id}/` with ID format `{skill}-{YYYYMMDD}-{short-uuid}`.

```
.olympus/
  oracle-20260305-a3f8b2c1/
    codebase-context.md       # Hermes exploration results
    interview-log.md          # Apollo Q&A session
    ambiguity-scores.json     # Quantified clarity scores
    gap-analysis.md           # Metis gap analysis
    spec.md                   # Final specification

  pantheon-20260305-7d2e9f04/
    perspectives.md           # Helios viewpoints
    analyst-findings.md       # Multi-perspective analysis
    da-evaluation.md          # Eris challenges
    analysis.md               # Consolidated output

  tribunal-20260305-b1c4d5e6/
    mechanical-result.json    # Build/test/lint results
    semantic-matrix.md        # AC verification matrix
    verdict.md                # Final verdict
```

</details>

---

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

```bash
# Run tests before submitting
bash hooks/test-hooks.sh
bash hooks/test-integration.sh
```

## License

[MIT](LICENSE) &copy; hjyoon

---

<p align="center">
  <em>"The unexamined code is not worth shipping."</em>
  <br/><br/>
  <strong>The gods don't agree. That's the point.</strong>
</p>
