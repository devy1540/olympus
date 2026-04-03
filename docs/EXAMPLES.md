**English** | [한국어](ko/EXAMPLES.md)

# Olympus Usage Examples

Practical scenarios showing when and how to use each skill.

---

## Choosing the Right Skill

```
"I have a vague idea"                    → /olympus:oracle
"I have a spec, make it better"          → /olympus:genesis
"Analyze this from multiple angles"      → /olympus:pantheon
"We need to decide between A and B"      → /olympus:agora
"Build everything from scratch"          → /olympus:odyssey
"Evaluate what was built"                → /olympus:tribunal
"First time using Olympus"               → /olympus:hestia
"Is the plugin working?"                 → /olympus:setup
```

---

## Example 1: Turning a Vague Idea into a Spec

**Scenario**: You want to add a notification system but haven't thought through the details.

```
You:  /olympus:oracle

      "I want to add push notifications to our app"
```

**What happens:**

1. **Hermes** scans your codebase — finds existing auth, API routes, database schema
2. **Apollo** starts a Socratic interview:
   ```
   Apollo: "What triggers a notification? User action, system event, or scheduled?"
   You:    "Both user actions and system events"
   Apollo: "Which delivery channels? Push only, or also email/SMS?"
   You:    "Push and email for now, SMS later"
   Apollo: "What's the expected volume? 100/day or 100k/day?"
   You:    "About 10k/day"
   ```
3. **Ambiguity Gate** checks: score 0.15 (≤ 0.2) — PASS
4. **Metis** runs gap analysis against your codebase
5. Output: `.olympus/{id}/spec.md` — a structured specification with GOAL, ACCEPTANCE_CRITERIA, and identified gaps

**When to use Oracle:**
- Starting a new feature with unclear scope
- Onboarding a new requirement from stakeholders
- Before writing any code on a complex feature

---

## Example 2: Evolving a Spec Through Generations

**Scenario**: You have a spec from Oracle, but it needs deeper refinement.

```
You:  /olympus:genesis

      (paste your spec.md or reference the Oracle artifact)
```

**What happens:**

Each generation cycle:
1. **Metis** (Wonder): "What fundamental questions remain? What assumptions are untested?"
2. **Eris** (Reflect): "This spec assumes synchronous processing — what if the queue backs up?"
3. **Orchestrator** (Seed): Crystallizes insights into a new version of the spec
4. **Convergence check**: Compares ontology (key concepts) between generations

```
Gen 1: convergence 0.45 — "Major gaps in error handling"
Gen 2: convergence 0.72 — "Queue backpressure strategy added"
Gen 3: convergence 0.91 — "Edge cases around retry logic"
Gen 4: convergence 0.96 — CONVERGED (≥ 0.95)
```

**When to use Genesis:**
- Spec feels incomplete but you can't pinpoint what's missing
- Complex domain with many interacting components
- You want the spec to "mature" before building

---

## Example 3: Multi-Perspective Analysis

**Scenario**: You need to evaluate a database migration strategy.

```
You:  /olympus:pantheon

      "We're migrating from MySQL to PostgreSQL. Evaluate the migration plan."
```

**What happens:**

1. **Hermes** explores your codebase — finds ORM usage, raw queries, stored procedures
2. **Helios** generates 4 orthogonal perspectives:
   - Performance (query patterns, indexing differences)
   - Data integrity (type mapping, constraint migration)
   - Security (permission model, encryption differences)
   - Operational risk (rollback strategy, downtime)
3. **Ares + Poseidon + Zeus** analyze in parallel from each perspective
4. **Eris** (Devil's Advocate): "You assume ORM abstracts all differences — but you have 23 raw SQL queries with MySQL-specific syntax at..."
5. Consensus: 75% (Working) — PASS

**When to use Pantheon:**
- Evaluating architectural decisions
- Risk assessment before a major change
- Need to see blind spots in your analysis

---

## Example 4: Technical Decision Making

**Scenario**: Your team can't agree on REST vs GraphQL for a new API.

```
You:  /olympus:agora

      "Should we use REST or GraphQL for our new public API?
       Context: 50+ endpoints, mobile + web clients, team of 8"
```

**What happens:**

1. **Framing**: Orchestrator structures the debate (stakeholders, constraints, criteria)
2. **Committee** (3 roles):
   - Zeus (Architect): "GraphQL reduces over-fetching for mobile"
   - Ares (Engineer): "REST is simpler to cache and rate-limit"
   - UX Critic: "Mobile clients need flexible queries — GraphQL wins here"
3. **Debate** (up to 3 rounds): Each role responds to others' arguments
4. **Eris** challenges: "You all assume the team has GraphQL expertise. What's the ramp-up cost?"
5. **Decision**: Structured verdict with majority position and dissenting views

**When to use Agora:**
- Team disagreements on technical direction
- "Build vs buy" decisions
- Choosing between competing approaches

---

## Example 5: Full Pipeline (End to End)

**Scenario**: Build a complete user authentication system from idea to verified code.

```
You:  /olympus:odyssey

      "Build an OAuth2 authentication system with refresh tokens"
```

**What happens (6 phases):**

```
Phase 1: Oracle
  Hermes scans → Apollo interviews → spec.md
  Gate: ambiguity ≤ 0.2 ✓

Phase 2: Genesis (if needed)
  Metis questions → Eris challenges → evolved spec
  Gate: convergence ≥ 0.95 ✓

Phase 3: Pantheon
  Multi-perspective analysis of the auth design
  Gate: consensus ≥ 67% ✓

Phase 4: Plan
  Zeus creates implementation plan → Themis reviews
  Gate: Themis APPROVE ✓

Phase 5: Execute
  Prometheus implements the code

Phase 6: Tribunal
  Hephaestus: build/test/lint → PASS
  Athena: AC verification → 8/8 met
  Consensus: Ares + Eris + Hera → APPROVED
```

If Tribunal rejects: retries up to 3 times, then rewinds to Genesis.

**When to use Odyssey:**
- Greenfield features requiring full rigor
- When you want requirements AND implementation AND evaluation
- High-stakes features where mistakes are costly

---

## Example 6: Evaluating Existing Code

**Scenario**: Someone submitted a PR and you want a thorough review.

```
You:  /olympus:tribunal

      "Evaluate the auth service implementation in src/auth/"
```

**What happens (3 stages):**

```
Stage 1 — Mechanical (Hephaestus)
  Build:     ✓ compiles
  Tests:     ✓ 47/47 passed
  Lint:      ✓ 0 warnings
  Typecheck: ✓ no errors
  → PASS (proceed to Stage 2)

Stage 2 — Semantic (Athena)
  AC 1: "GIVEN valid credentials WHEN /login THEN 200 + tokens"  → MET (auth.test.ts:15)
  AC 2: "GIVEN expired token WHEN /refresh THEN new token pair"  → MET (refresh.test.ts:8)
  AC 3: "GIVEN invalid token WHEN /api/* THEN 401"               → MET (middleware.test.ts:22)
  → 3/3 ACs MET

Stage 3 — Consensus
  Ares:  "Implementation is solid. Minor: consider rate limiting on /login"
  Eris:  "Refresh token rotation is missing — RFC 6749 §10.4"
  Hera:  "Tests pass but no integration test for token rotation"
  → APPROVED_WITH_CAVEATS
```

**When to use Tribunal:**
- After implementing a feature (self-review)
- Evaluating code quality before merge
- When you need evidence-based approval/rejection

---

## Example 7: Committee Debate on Architecture

**Scenario**: Deciding whether to adopt microservices for your monolith.

```
You:  /olympus:agora

      "Should we split our Django monolith into microservices?
       Current state: 200k LOC, 15 developers, 50ms p99 latency
       Pain points: deployment takes 45 min, teams step on each other"
```

**Debate flow:**

Round 1:
- Zeus: "Start with 3 bounded contexts: auth, billing, core-app"
- Ares: "Network calls between services will increase latency beyond 50ms"
- UX: "Deploy speed matters more than p99 — users feel slow releases"

Round 2:
- Zeus: "Use async messaging for non-critical paths to contain latency"
- Ares: "Distributed transactions across billing + core will be a nightmare"
- UX: "Can we do a modular monolith first? Same deploy benefit, less complexity"

Eris: "Everyone ignores the 15-developer team size. Microservices need platform engineering. Who runs the service mesh?"

Decision: **Modular monolith first**, with service extraction roadmap.

---

## Example 8: Project Onboarding

**Scenario**: First time using Olympus on an existing project.

```
You:  /olympus:hestia
```

**What happens:**

1. **Scan**: Detects Next.js + TypeScript + Prisma + PostgreSQL
2. **Assess**:
   - LOC: ~45k
   - Test coverage: 62%
   - Complexity: Medium
   - CI: GitHub Actions present
3. **Recommend**:
   ```
   Your project is a medium-complexity web app with decent test coverage.

   Recommended first skill: /olympus:oracle
     → You mentioned wanting to add real-time features.
       Oracle will help clarify requirements before coding.

   For existing code review: /olympus:tribunal
     → Evaluate your auth module against its acceptance criteria.

   For architecture decisions: /olympus:agora
     → Debate WebSocket vs SSE for real-time features.
   ```

---

## Combining Skills

Skills are composable. Common combinations:

| Goal | Combination |
|:-----|:------------|
| Feature from scratch | Oracle → Genesis → Odyssey |
| Evaluate + improve | Tribunal → (fix) → Tribunal |
| Decide then build | Agora → Oracle → Odyssey |
| Analyze then decide | Pantheon → Agora |
| Spec refinement | Oracle → Genesis → Genesis |

### Tip: Artifacts Chain

Each skill's output becomes the next skill's input:

```
Oracle   → spec.md
Genesis  → evolved spec.md (reads Oracle's spec.md)
Pantheon → analysis.md (reads spec.md)
Odyssey  → verdict.md (orchestrates all of the above)
```

All artifacts are stored in `.olympus/{skill}-{date}-{uuid}/` and auto-chained.

---

## Quick Reference

| Skill | Input | Output | Gate |
|:------|:------|:-------|:-----|
| `/olympus:oracle` | Vague idea | `spec.md` | Ambiguity ≤ 0.2 |
| `/olympus:genesis` | Spec | Evolved spec | Convergence ≥ 0.95 |
| `/olympus:pantheon` | Problem/decision | `analysis.md` | Consensus ≥ 67% |
| `/olympus:agora` | Debate topic | `decision.md` | Consensus ≥ 67% |
| `/olympus:odyssey` | Idea | Code + `verdict.md` | All gates |
| `/olympus:tribunal` | Implementation | `verdict.md` | Mechanical + Semantic |
| `/olympus:hestia` | (your project) | Skill recommendation | — |
| `/olympus:setup` | — | Installation report | — |
| `/olympus:audit` | — | `audit-report.md` | — |
| `/olympus:evolve` | — | Improved Olympus | Score ≥ 0.8 |
