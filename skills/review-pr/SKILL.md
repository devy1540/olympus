---
name: review-pr
description: "PR Review Pipeline — multi-perspective and adversarial PR analysis with confidence-calibrated verdict"
---

<Purpose>
Review pull requests from multiple perspectives with adversarial challenge and confidence-calibrated synthesis.
All agents operate as teammates for inter-reviewer communication and context retention.
Supports interactive and fully automated (--auto) modes.
</Purpose>

<Execution_Policy>
- This skill uses FULL TEAMMATE mode. ALL agents are teammates in one team.
- Each Step MUST call the specified MCP tool. Do NOT skip MCP calls.
- Hermes MUST be spawned for PR context (do NOT read diff yourself).
- Eris MUST be spawned for DA challenge (do NOT skip even if reviewers agree).
- Nemesis MUST be spawned for synthesis (do NOT synthesize yourself).
- Reviewer agents MUST run in parallel (send all SendMessages before waiting).
- Leader handles ONLY: team management, gate checks, artifact writing, GitHub posting.
- IMPORTANT: Do NOT skip ToolSearch at Step 0.
- TEAMMATE RESPONSE RULE: When a teammate goes idle without sending results,
  send a follow-up: SendMessage(to: "{agent}", "Report your findings now via SendMessage. Keep under 5000 chars.")
  Retry up to 3 times. NEVER do the agent's work directly — this violates §0.
</Execution_Policy>

<Modes>
  | Mode | Trigger | Behavior |
  |------|---------|----------|
  | Interactive | `/olympus:review-pr [PR]` | AskUserQuestion at each decision |
  | Auto | `/olympus:review-pr --auto --repo {owner/repo} --base {branch}` | Zero-interaction |

  Auto flags: --auto, --repo, --base, --spec, --post, --state
</Modes>

<Team_Structure>
  team_name: "review-pr-${CLAUDE_SESSION_ID}"

  Teammates:
  | Agent | Role | Comm Targets |
  |-------|------|-------------|
  | hermes | PR reconnaissance | leader |
  | helios | Perspective generation | leader |
  | ares | Code quality review | eris (responds to challenges), leader |
  | poseidon | Security review | leader |
  | eris | Adversarial challenge | reviewers (challenges), leader |
  | nemesis | Cross-perspective synthesis | leader |
</Team_Structure>

<Steps>

## Step 0: Load MCP Tools (REQUIRED FIRST)

```
Call ToolSearch("+olympus pipeline") to load MCP tools.
```

---

## Step 1: Initialize

```
1. TeamCreate(team_name: "review-pr-${CLAUDE_SESSION_ID}")
2. olympus_start_pipeline(skill: "review-pr", pipeline_id: ...)
3. Create artifact directory: .olympus/review-pr-{YYYYMMDD}-{short-uuid}/
```

---

## Step 2: Input Resolution

```
── Auto mode ─────────────────────────────────────────────
  1. Load state: .olympus/review-pr-state.json
  2. Discover unreviewed PRs:
     gh pr list --repo {owner/repo} --base {base} --state open --json number,headRefOid,title,author
     Filter out: already reviewed at same commit, drafts
     If none → exit ("리뷰 대기 PR 없음")
  3. For each PR: gh pr diff {number} → pr-diff.patch

── Interactive mode ──────────────────────────────────────
  A. PR number → gh pr view + gh pr diff
  B. Branch → git diff main...{branch}
  C. No arg → detect current branch, git diff main...HEAD
  D. Commit range → git diff {from}..{to}

── Common ────────────────────────────────────────────────
  Validation: empty diff → skip. >5000 lines → warn.
  
  Review start notification (if PR number available):
    gh api repos/{owner}/{repo}/issues/{pr}/comments
    → Post progress table, save REVIEW_START_COMMENT_ID
```

---

## Step 3: Spec Context (optional)

```
Activated when: --spec flag OR existing .olympus/*/spec.md detected.
Default: skip (tactical review only).

When activated:
  - Read spec.md → extract GOAL, CONSTRAINTS, AC, ONTOLOGY
  - Read latest ontology.json → domain concepts, boundaries
  - Generate spec-context.md

Effect: downstream agents also read spec-context.md for strategic review.
```

---

## Step 4: Hermes PR Reconnaissance

```
IF "hermes" not in team:
  Agent(name: "hermes", team_name: ${TEAM},
        subagent_type: "olympus:hermes",
        prompt: "You are Hermes, a teammate in ${TEAM}.
          Artifact directory: ${ARTIFACT_DIR}/
          Wait for messages — do not act until prompted.")
  olympus_register_agent_spawn(pipeline_id, "hermes")

SendMessage(to: "hermes", summary: "PR 정찰",
  "DO NOT write files — you are read-only.
   Read ${ARTIFACT_DIR}/pr-diff.patch and explore affected codebase areas.
   For each changed file: module, dependencies, change type (add/modify/delete).
   Output: structured PR context with files, modules, dependency impact.
   Report to leader.")

WAIT → leader writes pr-context.md
olympus_record_execution(pipeline_id, "review-pr", "hermes", ...)
```

---

## Step 5: Helios Perspective Generation

```
IF "helios" not in team:
  Agent(name: "helios", team_name: ${TEAM},
        subagent_type: "olympus:helios", prompt: "...")
  olympus_register_agent_spawn(pipeline_id, "helios")

SendMessage(to: "helios", summary: "리뷰 관��� 생성",
  "DO NOT write files — you are read-only.
   Read ${ARTIFACT_DIR}/pr-context.md.
   {If spec-context.md: 'Also read spec-context.md for domain context.'}
   Generate 3-5 perspectives. Mandatory: Code Quality (→ ares), Security (→ poseidon).
   Dynamic: Architecture, Performance, Test Coverage, Breaking Changes, Error Handling, Concurrency.
   {If spec-context.md: + Domain Model Consistency, AC Regression.}
   Report to leader.")

WAIT → leader writes review-perspectives.md
olympus_record_execution(pipeline_id, "review-pr", "helios", ...)

Perspective approval:
  Interactive: AskUserQuestion ["진행", "관점 추가", "관점 제거", "최소 리뷰"]
  Auto: proceed with Helios perspectives
```

---

## Step 6: Parallel Multi-Perspective Review

```
Spawn reviewer teammates (lazy):

IF "ares" not in team:
  Agent(name: "ares", team_name: ${TEAM}, subagent_type: "olympus:ares", prompt: "...")
  olympus_register_agent_spawn(pipeline_id, "ares")

IF "poseidon" not in team:
  Agent(name: "poseidon", team_name: ${TEAM}, subagent_type: "olympus:poseidon", prompt: "...")
  olympus_register_agent_spawn(pipeline_id, "poseidon")

Send ALL review tasks in PARALLEL:

SendMessage(to: "ares", summary: "코드 품질 리뷰",
  "DO NOT write files — you are read-only.
   Read ${ARTIFACT_DIR}/pr-context.md, review-perspectives.md.
   {If spec-context.md: 'Read spec-context.md for domain invariants.'}
   Review ONLY changed files. Focus: defects, anti-patterns, SOLID.
   Each finding: Severity (CRITICAL/WARNING/INFO), file:line, confidence 0-1, evidence.
   CROSS-REFERENCE: After initial analysis, share key findings with 'poseidon' via SendMessage.
   Incorporate their feedback, then report FINAL findings to leader via SendMessage.")

SendMessage(to: "poseidon", summary: "보안 리뷰",
  "DO NOT write files — you are read-only.
   Read ${ARTIFACT_DIR}/pr-context.md.
   {If spec-context.md: 'Read spec-context.md for security requirements.'}
   Review ONLY changed files. Focus: OWASP Top 10, vulnerabilities, secrets, input validation.
   Each finding: Severity, CWE, file:line, confidence 0-1, remediation.
   CROSS-REFERENCE: After initial analysis, share key findings with 'ares' via SendMessage.
   Incorporate their feedback, then report FINAL findings to leader via SendMessage.")

For dynamic perspectives: spawn general-purpose agents or reuse existing teammates.

WAIT for ALL reviewers → leader aggregates into review-findings.md
olympus_record_execution for each reviewer
```

---

## Step 7: Eris Adversarial Challenge

```
IF "eris" not in team:
  Agent(name: "eris", team_name: ${TEAM}, subagent_type: "olympus:eris", prompt: "...")
  olympus_register_agent_spawn(pipeline_id, "eris")

SendMessage(to: "eris", summary: "DA 챌린지",
  "DO NOT write files — you are read-only.
   Read ${ARTIFACT_DIR}/review-findings.md.
   Read docs/shared/fallacy-catalog.md.
   {If spec-context.md: 'Read spec-context.md — challenge spec alignment.'}
   Challenge findings:
     - False positive detection
     - Missing context (framework protections, existing mitigations)
     - Logical fallacies
     - Severity calibration
     - Cross-reviewer contradictions
   Max 2 rounds. Flag BLOCKING_QUESTIONs.
   Report to leader.")

WAIT → leader writes da-evaluation.md
olympus_record_execution(pipeline_id, "review-pr", "eris", ...)

BLOCKING_QUESTION resolution:
  - Tool-solvable → resolve with Grep/Read
  - Interactive: AskUserQuestion
  - Auto: mark UNRESOLVED_AUTO (Nemesis factors into confidence)
```

---

## Step 8: Nemesis Synthesis & Verdict

```
IF "nemesis" not in team:
  Agent(name: "nemesis", team_name: ${TEAM}, subagent_type: "olympus:nemesis", prompt: "...")
  olympus_register_agent_spawn(pipeline_id, "nemesis")

SendMessage(to: "nemesis", summary: "종합 판정",
  "DO NOT write files — you are read-only.
   Read all artifacts: pr-context.md, review-findings.md, da-evaluation.md.
   {If spec-context.md: 'Read spec-context.md.'}
   Synthesize:
     1. Incorporate DA results (downgrade false positives, boost confirmed)
     2. Deduplicate (file:line proximity within 5 lines)
     3. Cross-perspective patterns (same issue by 2+ reviewers)
     4. Blind spots (changed files with zero findings)
     5. Confidence calibration per finding
   Verdict: APPROVE / REQUEST_CHANGES / COMMENT_ONLY.
   Report to leader.")

WAIT → leader writes verdict.md
olympus_record_execution(pipeline_id, "review-pr", "nemesis", ...)

Gate check:
  survival_rate = findings_surviving_DA / total_findings
  olympus_gate_check(pipeline_id, "consensus", survival_rate)
```

---

## Step 9: Output & GitHub Integration

```
── Update Start Comment ──────────────────────────────────
  If REVIEW_START_COMMENT_ID:
    gh api PATCH with completion status + verdict

── Auto mode ─────────────────────────────────────────────
  1. Determine post event (--post flag or verdict-driven)
  2. Format verdict.md as GitHub PR review:
     Body: Overview + Verdict + Patterns + Blind Spots
     Inline comments: CRITICAL/WARNING with valid file:line
     POST /repos/{owner}/{repo}/pulls/{pr}/reviews
  3. Update review-pr-state.json
  4. Return to Step 2 for next PR

── Interactive mode ──────────────────────────────────────
  Display verdict.md summary.
  If PR number available:
    AskUserQuestion: "GitHub에 리뷰 게시할까요?"
    ["게시 (REQUEST_CHANGES)", "게시 (COMMENT)", "게시 (APPROVE)", "게시 안함"]
```

---

## Step 10: Teardown

```
Shutdown all teammates → TeamDelete
```

</Steps>

<Tool_Usage>
  MCP Tools:
  - olympus_start_pipeline: Step 1 (MUST)
  - olympus_register_agent_spawn: after each spawn (MUST)
  - olympus_gate_check: Step 8 consensus (MUST)
  - olympus_record_execution: after each agent (SHOULD)

  Team Tools:
  - TeamCreate: Step 1
  - Agent (name + team_name): spawn teammates
  - SendMessage: all communication (PARALLEL for reviewers!)
  - TeamDelete: Step 10
</Tool_Usage>

<Artifact_Contracts>
  | File | Step | Writer | Readers |
  |------|------|--------|---------|
  | pr-diff.patch | 2 | Leader | hermes |
  | spec-context.md | 3 | Leader | All agents |
  | pr-context.md | 4 | Leader (from hermes) | All agents |
  | review-perspectives.md | 5 | Leader (from helios) | Reviewers |
  | review-findings.md | 6 | Leader (from reviewers) | eris, nemesis |
  | da-evaluation.md | 7 | Leader (from eris) | nemesis |
  | verdict.md | 8 | Leader (from nemesis) | User, GitHub |
</Artifact_Contracts>

<State_File>
  .olympus/review-pr-state.json (persists across runs):
  {
    "reviewed": {
      "{pr_number}": {
        "verdict": "APPROVE | REQUEST_CHANGES | COMMENT_ONLY",
        "timestamp": "ISO 8601",
        "commit": "{headRefOid}",
        "criticals": 0, "warnings": 2,
        "artifact": ".olympus/review-pr-{id}/"
      }
    }
  }
  Re-review trigger: headRefOid changes → eligible for re-review.
</State_File>

<Loop_Schedule_Integration>
  /loop 5m /olympus:review-pr --auto --repo myorg/myrepo --base main
  /schedule create --cron "*/15 * * * *" --prompt "/olympus:review-pr --auto ..."
</Loop_Schedule_Integration>
