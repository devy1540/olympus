---
name: review-pr
description: "PR Review Pipeline — multi-perspective and adversarial PR analysis with confidence-calibrated verdict"
---

# /olympus:review-pr — Trial of Nemesis

A pipeline that reviews pull requests from multiple perspectives with adversarial challenge and confidence-calibrated synthesis. Supports both interactive and fully automated (`--auto`) modes.

## Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| **Interactive** (default) | `/olympus:review-pr [PR]` | AskUserQuestion at each decision point |
| **Auto** | `/olympus:review-pr --auto --repo {owner/repo} --base {branch}` | Zero-interaction: poll → review → post |

**Auto mode flags:**
- `--auto`: enable non-interactive mode (all AskUserQuestion → default action)
- `--repo {owner/repo}`: target repository (required in auto mode)
- `--base {branch}`: target base branch to watch (default: `main`)
- `--spec {path}`: spec.md path for strategic review (optional)
- `--post {event}`: auto-post event type: `REQUEST_CHANGES` | `COMMENT` | `APPROVE` (default: verdict-driven)
- `--state {path}`: state file path for tracking reviewed PRs (default: `.olympus/review-pr-state.json`)

## Agents (subagent_type bindings)
- **Hermes**: PR context gathering (diff, affected modules, dependencies) → `subagent_type: "olympus:hermes"`
- **Helios**: Review perspective generation based on PR characteristics → `subagent_type: "olympus:helios"`
- **Ares**: Code quality review (defects, anti-patterns, SOLID) → `subagent_type: "olympus:ares"`
- **Poseidon**: Security review (OWASP, vulnerabilities, secrets) → `subagent_type: "olympus:poseidon"`
- **Eris**: Adversarial challenge of review findings → `subagent_type: "olympus:eris"`
- **Nemesis**: Cross-perspective synthesis and final verdict → `subagent_type: "olympus:nemesis"`

**⚠ MANDATORY**: All agents above MUST be spawned via the Agent tool. In particular:
- **Hermes MUST be spawned** for PR context gathering (Phase 1). Do NOT read the diff yourself.
- **Eris MUST be spawned** for adversarial challenge (Phase 4). Do NOT skip even if reviewers agree.
- **Nemesis MUST be spawned** for synthesis (Phase 5). Do NOT synthesize findings yourself.
- Reviewer agents (Phase 3) MUST run in parallel via separate Agent tool calls.
See orchestrator-protocol.md §0.

## Gate
- consensus ≥ 67% (from gate-thresholds.json) — applied to finding survival rate after DA challenge

## Artifact Contracts
| File | Phase | Writer | Readers |
|---|---|---|---|
| `.olympus/{id}/pr-diff.patch` | 0 | Orchestrator | Hermes |
| `.olympus/{id}/spec-context.md` | 0.5 | Orchestrator | All agents |
| `.olympus/{id}/pr-context.md` | 1 | Orchestrator (source: Hermes) | All agents |
| `.olympus/{id}/review-perspectives.md` | 2 | Orchestrator (source: Helios) | Reviewer agents |
| `.olympus/{id}/review-findings.md` | 3 | Orchestrator (source: Ares, Poseidon, dynamic) | Eris, Nemesis |
| `.olympus/{id}/da-evaluation.md` | 4 | Orchestrator (source: Eris) | Nemesis |
| `.olympus/{id}/verdict.md` | 5 | Orchestrator (source: Nemesis) | User, GitHub |

**Auto mode state file** (persists across runs):
| File | Purpose |
|---|---|
| `.olympus/review-pr-state.json` | Tracks reviewed PR numbers, timestamps, verdicts |

---

## Execution Flow

```
Phase 0 → Phase 0.5 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
(Input)   (Spec Ctx)  (Recon)   (Persp)   (Review)  (DA)      (Synth)   (Output)
```

### Phase 0: Input Resolution

```
── Auto mode ──────────────────────────────────────────────────────────

  Step 1: Load state
    Read .olympus/review-pr-state.json (create if absent):
      {
        "reviewed": {
          "123": { "verdict": "APPROVE", "timestamp": "2026-04-03T10:00:00Z", "commit": "abc123" },
          "124": { "verdict": "REQUEST_CHANGES", "timestamp": "2026-04-03T11:00:00Z", "commit": "def456" }
        }
      }

  Step 2: Discover unreviewed PRs
    Run: gh pr list --repo {owner/repo} --base {base} --state open --json number,headRefOid,title,author
    Filter out:
      - PRs already in state with same headRefOid (already reviewed at this commit)
      - Draft PRs (unless --include-drafts)
    If no unreviewed PRs found → exit cleanly ("리뷰 대기 PR 없음")

  Step 3: For each unreviewed PR (sequential):
    Run: gh pr diff {number} --repo {owner/repo}
    Save diff to .olympus/{id}/pr-diff.patch
    Continue to Phase 0.5

    Note: Process one PR at a time per loop iteration.
    After Phase 6, update state and check for next PR.

── Interactive mode ───────────────────────────────────────────────────

  Option A — PR number provided (e.g., "/olympus:review-pr 123"):
    Run: gh pr view {number} --json title,body,author,baseRefName,headRefName
    Run: gh pr diff {number}
    Save diff to .olympus/{id}/pr-diff.patch

  Option B — Branch name provided (e.g., "/olympus:review-pr feature/auth"):
    Run: git diff main...{branch}
    Save diff to .olympus/{id}/pr-diff.patch

  Option C — No argument:
    Detect current branch. If not main:
      Run: git diff main...HEAD
      Save diff to .olympus/{id}/pr-diff.patch
    If on main:
      AskUserQuestion:
        question: "어떤 PR을 리뷰할까요?"
        context: "현재 main 브랜치에 있습니다. 리뷰 대상을 지정해주세요."
        options:
          - "PR 번호 입력"
          - "브랜치명 입력"
          - "최근 커밋 범위 입력"

  Option D — Commit range (e.g., "/olympus:review-pr abc123..def456"):
    Run: git diff {from}..{to}
    Save diff to .olympus/{id}/pr-diff.patch

── Common ─────────────────────────────────────────────────────────────

Validation:
  - If diff is empty → notify and skip ("변경사항이 없습니다")
  - If diff exceeds 5000 lines:
    - Interactive: warn user, offer to proceed or scope down
    - Auto: proceed with warning logged

Create artifact directory: .olympus/review-pr-{YYYYMMDD}-{short-uuid}/
```

### Phase 0.5: Spec Context Resolution (optional)

```
Activated when:
  - --spec flag is used (explicit path)
  - OR existing .olympus/ artifact directories are detected (auto-discovery)
Default behavior: skip and proceed to Phase 1 (tactical review only)

When activated:

  Step 1: Auto-discover existing artifacts
    Search for recent .olympus/*/spec.md and .olympus/*/gen-*/ontology.json
    If found:
      - Read spec.md → extract GOAL, CONSTRAINTS, ACCEPTANCE_CRITERIA, ONTOLOGY
      - Read latest ontology.json → extract domain concepts, relationships, boundaries
    If not found:
      - Interactive + --spec explicit → AskUserQuestion: "spec.md 경로를 입력하세요"
      - Auto mode → skip Phase 0.5 silently (no user to ask)
      - Auto-discovery miss → skip Phase 0.5 silently

  Step 2: Build spec-context.md
    Synthesize into .olympus/{id}/spec-context.md:
      ## Domain Ontology
      - Core concepts: {concepts from ontology}
      - Boundaries: {module/layer boundaries}
      - Invariants: {domain rules that must hold}

      ## Acceptance Criteria (relevant to changed files)
      - Filter ACs from spec.md that relate to modules in the PR diff

      ## Architectural Constraints
      - Layer rules, dependency direction, naming conventions from spec

  Effect on downstream phases:
    - Phase 2 (Helios): "Also read spec-context.md. Generate domain-aware perspectives
      such as 'Domain Model Consistency' or 'AC Regression'."
    - Phase 3 (Reviewers): "Also read spec-context.md. Check changes against domain
      invariants and AC requirements, not just code quality."
    - Phase 4 (Eris): "Also read spec-context.md. Challenge whether findings align with
      actual spec requirements vs reviewer assumptions."
    - Phase 5 (Nemesis): "Also read spec-context.md. Assess whether the PR moves the
      codebase toward or away from the spec's stated goals."

This phase transforms the review from tactical (bug-finding) to strategic
(domain/architecture/spec compliance).
```

### Phase 1: PR Reconnaissance (Hermes)

```
1. Spawn Hermes as a Task:
   - subagent_type: "olympus:hermes"
   - Prompt:
     "Artifact directory: .olympus/{id}/
      Read .olympus/{id}/pr-diff.patch and explore the affected codebase areas.
      For each changed file:
        - Identify the module it belongs to
        - Map what other files depend on it (imports/requires)
        - Note the type of change (added/modified/deleted)
      Output: structured PR context with changed files, modules, dependencies."

2. Hermes gathers:
   - Changed file list with change type (added/modified/deleted) and line counts
   - Affected module map (which modules/packages are impacted)
   - Dependency impact (what imports/depends on changed files)
   - PR metadata (title, description, author — if available from Phase 0)

3. Orchestrator saves Hermes result verbatim to .olympus/{id}/pr-context.md
```

### Phase 2: Review Perspective Generation (Helios)

```
1. Spawn Helios as a Task:
   - subagent_type: "olympus:helios"
   - Prompt:
     "Artifact directory: .olympus/{id}/
      Read .olympus/{id}/pr-context.md.
      {If spec-context.md exists: "Also read .olympus/{id}/spec-context.md for domain context."}
      Generate 3-5 review perspectives optimized for this specific PR's characteristics.
      MANDATORY perspectives: Code Quality (→ Ares), Security (→ Poseidon).
      DYNAMIC perspectives (add based on PR type):
        - Architecture Impact: if structural changes, new modules, or layer-crossing changes detected
        - Performance: if hot-path code, database queries, or loop-heavy code changed
        - Test Coverage: if test files are changed/missing relative to source changes
        - Breaking Changes: if public API, exports, or interface signatures modified
        - Error Handling: if error paths, catch blocks, or recovery logic changed
        - Concurrency: if shared state, async patterns, or locking code changed
        {If spec-context.md exists:
        - Domain Model Consistency: if domain entities or business logic changed
        - AC Regression: if code related to acceptance criteria is modified}
      Apply perspective-quality-gate: orthogonality (<20% overlap), evidence-based, domain-specific, actionable."

2. Orchestrator saves Helios result verbatim to .olympus/{id}/review-perspectives.md

3. Perspective approval:
   - Interactive:
     AskUserQuestion:
       question: "다음 관점으로 PR을 리뷰합니다:"
       context: "{generated perspectives summary}"
       options:
         - "진행": continue with generated perspectives
         - "관점 추가": user adds a custom perspective
         - "관점 제거": user removes a perspective
         - "최소 리뷰 (Ares+Poseidon만)": skip dynamic perspectives
   - Auto: proceed with Helios-generated perspectives (no approval needed)
```

### Phase 3: Parallel Multi-Perspective Review

```
Spawn reviewer agents as Tasks in parallel (one per perspective):

Fixed reviewers (always spawned):

  1. Ares (subagent_type: "olympus:ares"):
     Prompt:
       "Artifact directory: .olympus/{id}/
        Read .olympus/{id}/pr-context.md for changed file list.
        Read .olympus/{id}/review-perspectives.md for your assigned perspective.
        {If spec-context.md exists: "Read .olympus/{id}/spec-context.md for domain invariants."}
        Review ONLY the changed files listed in pr-context.md.
        Focus: code defects, anti-patterns, SOLID violations, maintainability issues.
        For each finding, include:
          - Severity: CRITICAL / WARNING / INFO
          - File:Line reference
          - Confidence: 0.0-1.0
          - Evidence: what specifically is wrong and why"

  2. Poseidon (subagent_type: "olympus:poseidon"):
     Prompt:
       "Artifact directory: .olympus/{id}/
        Read .olympus/{id}/pr-context.md for changed file list.
        {If spec-context.md exists: "Read .olympus/{id}/spec-context.md for security requirements."}
        Review ONLY the changed files listed in pr-context.md.
        Focus: OWASP Top 10, security vulnerabilities, secret exposure, input validation.
        For each finding, include:
          - Severity: CRITICAL / WARNING / INFO
          - CWE number
          - File:Line reference
          - Confidence: 0.0-1.0
          - Remediation suggestion"

Dynamic reviewers (based on Helios perspectives):

  For each dynamic perspective in review-perspectives.md:
    Spawn general-purpose agent with perspective-specific prompt:
      "You are reviewing a PR from the {perspective name} perspective.
       Artifact directory: .olympus/{id}/
       Read .olympus/{id}/pr-context.md for changed file list.
       Read .olympus/{id}/review-perspectives.md for your assigned perspective and key questions.
       {If spec-context.md exists: "Read .olympus/{id}/spec-context.md for domain context."}
       Review ONLY the changed files.
       Key questions to answer: {perspective's key questions from Helios}
       For each finding, include:
         - Severity: CRITICAL / WARNING / INFO
         - File:Line reference
         - Confidence: 0.0-1.0
         - Evidence"

⚠ Token efficiency: Do NOT inject full diff or file content into agent prompts.
  Agents Read pr-context.md and source files via tool calls.

Orchestrator aggregates all reviewer results into .olympus/{id}/review-findings.md:
  - Prepend each finding with reviewer attribution: "[Ares]", "[Poseidon]", "[Architecture]", etc.
  - Preserve original finding text verbatim
  - Add section headers per reviewer
```

### Phase 4: Adversarial Challenge (Eris)

```
1. Spawn Eris as a Task:
   - subagent_type: "olympus:eris"
   - Prompt:
     "Artifact directory: .olympus/{id}/
      Read .olympus/{id}/review-findings.md — these are PR review findings from multiple reviewers.
      Read docs/shared/fallacy-catalog.md for the 22 logical fallacy patterns.
      {If spec-context.md exists: "Read .olympus/{id}/spec-context.md — challenge whether findings
       align with actual spec requirements vs reviewer assumptions."}
      Your mission: challenge the review findings for soundness.
        - False positive detection: are the flagged issues actually problems in context?
        - Missing context: did reviewers miss framework protections or existing mitigations?
        - Logical fallacies: are reviewer arguments logically sound?
        - Severity calibration: are severity levels appropriate for the actual impact?
        - Contradictions: do any reviewers contradict each other?
      Max 2 challenge-response rounds."

2. Eris evaluates:
   - Each CRITICAL/WARNING finding: is it a true positive?
   - Reviewer reasoning: any logical fallacies per fallacy-catalog?
   - Cross-reviewer contradictions: flag if reviewers disagree
   - BLOCKING_QUESTIONs: questions that must be answered before verdict

3. Challenge-Response:
   - Round 1: Eris presents core challenges
   - If BLOCKING_QUESTIONs exist:
     - Solvable via tools → resolve with Grep/Read
     - Interactive: only user can answer → AskUserQuestion with full context (per orchestrator-protocol.md §4)
     - Auto: mark as UNRESOLVED_AUTO and proceed — Nemesis will factor this into confidence
   - Round 2: residual challenges (if needed)

4. Orchestrator saves Eris result verbatim to .olympus/{id}/da-evaluation.md
```

### Phase 5: Synthesis & Verdict (Nemesis)

```
1. Spawn Nemesis as a Task:
   - subagent_type: "olympus:nemesis"
   - Prompt:
     "Artifact directory: .olympus/{id}/
      Read all review artifacts:
        - .olympus/{id}/pr-context.md (PR metadata, changed files)
        - .olympus/{id}/review-findings.md (all reviewer findings)
        - .olympus/{id}/da-evaluation.md (Eris's adversarial evaluation)
        {If spec-context.md exists: "- .olympus/{id}/spec-context.md (domain/spec context)"}
      Produce final synthesis:
        1. Incorporate DA results (downgrade false positives, boost confirmed findings)
        2. Deduplicate findings (group by file:line proximity within 5 lines)
        3. Detect cross-perspective patterns (same issue found by 2+ reviewers)
        4. Identify blind spots (changed files with zero findings)
        5. Calibrate confidence per finding
        6. Render verdict: APPROVE / REQUEST_CHANGES / COMMENT_ONLY"

2. Orchestrator saves Nemesis result verbatim to .olympus/{id}/verdict.md

3. Gate check (consensus threshold from gate-thresholds.json):
   - Calculate: findings surviving DA / total findings
   - If survival rate < consensus threshold:
     Log warning: "DA invalidated majority of findings — review quality may be low"
     Proceed with verdict (Nemesis already accounts for this)
```

### Phase 6: Output & GitHub Integration

```
── Auto mode ──────────────────────────────────────────────────────────

  1. Determine post event:
     - If --post flag specified → use specified event
     - Else derive from verdict:
       - APPROVE → post as APPROVE
       - REQUEST_CHANGES → post as REQUEST_CHANGES
       - COMMENT_ONLY → post as COMMENT

  2. Format and post review:
     Format verdict.md as GitHub PR review:
       - Body: Overview + Verdict + Cross-Perspective Patterns + Blind Spots
       - For each CRITICAL/WARNING finding with valid file:line in the diff:
         Generate inline review comment
     Post via gh api:
       POST /repos/{owner}/{repo}/pulls/{pr}/reviews
       body: { event: "{event}", body: "{summary}", comments: [{path, line, body}] }

  3. Update state:
     Read .olympus/review-pr-state.json
     Add entry:
       "{pr_number}": {
         "verdict": "{APPROVE/REQUEST_CHANGES/COMMENT_ONLY}",
         "timestamp": "{ISO 8601}",
         "commit": "{headRefOid}",
         "criticals": {n},
         "warnings": {n},
         "artifact": ".olympus/{id}/"
       }
     Write updated state

  4. Check for next PR:
     Return to Phase 0 Step 2 for next unreviewed PR
     If no more PRs → exit cleanly

── Interactive mode ───────────────────────────────────────────────────

  Display verdict.md summary to user.

  If PR number was provided in Phase 0:
    AskUserQuestion:
      question: "GitHub에 리뷰 코멘트를 게시할까요?"
      context: "Verdict: {APPROVE/REQUEST_CHANGES/COMMENT_ONLY}, CRITICAL: {n}, WARNING: {n}"
      options:
        - "게시 (REQUEST_CHANGES)": post review with REQUEST_CHANGES event
        - "게시 (COMMENT)": post review with COMMENT event
        - "게시 (APPROVE)": post review with APPROVE event
        - "게시 안함": display verdict only, skip GitHub posting

    If posting:
      Format verdict.md as GitHub PR review:
        - Body: Overview + Verdict + Cross-Perspective Patterns + Blind Spots
        - For each CRITICAL/WARNING finding with file:line:
          Generate inline review comment via gh api:
            POST /repos/{owner}/{repo}/pulls/{pr}/reviews
            body: { event: "{event}", body: "{summary}", comments: [{path, line, body}] }

  If PR number was NOT provided:
    Display full verdict.md content and exit.
```

### Team Teardown

Shut down all spawned agents per the team-teardown.md protocol.

---

## Loop/Schedule Integration

This skill is designed to work with Claude Code's automation primitives:

### `/loop` (session-local polling)
```
/loop 5m /olympus:review-pr --auto --repo myorg/myrepo --base main
```
Runs every 5 minutes within the current session. Good for active development periods.

### `/schedule` (persistent cron)
```
/schedule create --cron "*/15 * * * *" --prompt "/olympus:review-pr --auto --repo myorg/myrepo --base develop"
```
Runs every 15 minutes as a remote trigger. Persists across sessions.

### State File Schema (`review-pr-state.json`)
```json
{
  "reviewed": {
    "{pr_number}": {
      "verdict": "APPROVE | REQUEST_CHANGES | COMMENT_ONLY",
      "timestamp": "ISO 8601",
      "commit": "{headRefOid — prevents re-review of same commit}",
      "criticals": 0,
      "warnings": 2,
      "artifact": ".olympus/review-pr-{YYYYMMDD}-{uuid}/"
    }
  },
  "config": {
    "repo": "{owner/repo}",
    "base": "{branch}",
    "spec": "{path or null}",
    "post": "{event or null}"
  }
}
```

**Re-review trigger**: When a PR's `headRefOid` changes (new commits pushed), the PR becomes
eligible for re-review even if previously reviewed. The state entry is updated, not duplicated.
