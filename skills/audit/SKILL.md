---
name: audit
description: "올림푸스 감사 — 플러그인 내부 정합성을 자동 검증"
---

# /olympus:audit — 올림푸스 감사

Olympus 플러그인의 내부 정합성을 자동으로 검증하는 스킬. 에이전트 권한, 교차 참조, 아티팩트 계약, 게이트 임계값, 명확성 규칙의 일관성을 검사한다.

## 사용 에이전트
- **Hephaestus**: 기계적 검증 (YAML, 파일 존재, 구조)
- **Athena**: 의미론적 검증 (권한-역할 정합성, 계약 완전성)

## 판정
- CLEAN: 모든 검증 통과
- WARNING: 비치명적 불일치 발견 (수동 확인 권장)
- VIOLATION: 치명적 정합성 위반 (수정 필요)

## 아티팩트 계약
| 파일 | Phase | 작성자 | 읽는 곳 |
|---|---|---|---|
| `.olympus/{id}/audit-mechanical.json` | 1 | Hephaestus | Athena |
| `.olympus/{id}/audit-semantic.json` | 2 | Athena | Orchestrator |
| `.olympus/{id}/audit-report.md` | 3 | Orchestrator | User |

---

## Execution Flow

```
Phase 1 (Mechanical) → Phase 2 (Semantic) → Phase 3 (Report)
```

### Phase 1: Hephaestus의 기계적 검증

Hephaestus를 Task로 생성하여 구조적 정합성을 검사한다.

```
입력: 플러그인 루트 경로
검사 항목:

1-1. YAML Frontmatter 유효성
  - agents/*.md의 frontmatter에 name, description, model, disallowedTools가 있는가
  - skills/*/SKILL.md의 frontmatter에 name, description이 있는가
  - model 값이 유효한가 (opus | sonnet | haiku)
  - disallowedTools가 배열인가

1-2. 파일 존재 검증
  - agents/*.md에서 "Hand off to:" 또는 "→ {AgentName}" 패턴 추출
  - 참조된 에이전트명이 agents/ 디렉토리에 존재하는가
  - skills/*/SKILL.md에서 "## 사용 에이전트" 섹션의 에이전트명 추출
  - 참조된 에이전트가 agents/ 디렉토리에 존재하는가

1-3. 공유 문서 참조
  - agents/*.md와 skills/*.md에서 docs/shared/ 파일 참조 추출
  - 참조된 문서가 docs/shared/에 존재하는가

1-4. artifact-contracts.json 대조 (있으면)
  - artifact-contracts.json의 모든 writer 에이전트가 존재하는가
  - artifact-contracts.json의 모든 reader 에이전트가 존재하는가

출력: audit-mechanical.json
{
  "yaml_validity": { "pass": [], "fail": [] },
  "cross_references": { "valid": [], "broken": [] },
  "doc_references": { "valid": [], "broken": [] },
  "contract_agents": { "valid": [], "missing": [] },
  "overall": "PASS | FAIL"
}
```

### Phase 2: Athena의 의미론적 검증

Athena를 Task로 생성하여 논리적 정합성을 검사한다.

```
입력: audit-mechanical.json + agents/*.md + skills/*.md + docs/shared/*
검사 항목:

2-1. 권한-역할 정합성 (Permission-Role Consistency)
  각 에이전트에 대해:
  a. disallowedTools 파싱
  b. 프롬프트 본문에서 파일 저장 관련 표현 탐색:
     - Write/Edit가 비활성화된 에이전트: "저장", "생성", "작성하다", "save", "write", "create file" 등
     - 단, "SendMessage로 전달" 맥락은 허용
  c. Tool_Usage 섹션의 도구가 disallowedTools와 충돌하는가
  d. 위반 시: VIOLATION + 에이전트명 + 충돌 위치

2-2. 아티팩트 계약 완전성 (Contract Completeness)
  각 스킬에 대해:
  a. SKILL.md 본문에서 파일명 패턴 추출 (*.md, *.json)
  b. artifact-contracts.md (또는 .json)와 대조
  c. 스킬에서 언급되지만 계약에 없는 파일 → WARNING
  d. 계약에 있지만 어떤 스킬에서도 언급되지 않는 파일 → INFO (orphan)

2-3. 게이트 일관성 (Gate Consistency)
  게이트 임계값 추출:
  a. ambiguity-scoring.md의 gate threshold
  b. oracle/SKILL.md의 모호성 게이트 값
  c. consensus-levels.md의 Normal/Hell 임계값
  d. pantheon/SKILL.md의 합의 임계값
  e. tribunal/SKILL.md의 semantic 점수 임계값
  f. genesis/SKILL.md의 수렴 임계값
  동일 게이트의 값이 모든 참조 위치에서 일치하는지 검증
  불일치 시: VIOLATION + 위치 + 값 차이

2-4. 명확성 규칙 스캔 (Clarity Scan)
  clarity-enforcement.md의 금지 표현 목록 추출
  모든 에이전트 Output_Format 및 Examples 섹션에서 금지 표현 탐색
  (템플릿 플레이스홀더 {}, 의도적 Bad 예시는 제외)
  위반 시: WARNING + 에이전트명 + 위치 + 표현

2-5. 위임 패턴 일관성 (Delegation Pattern)
  Write/Edit가 비활성화된 에이전트 목록 추출
  각 에이전트에 대해:
  a. Tool_Usage에 SendMessage가 있는가
  b. Final_Checklist에 "오케스트레이터에게 전달" 관련 항목이 있는가
  c. 누락 시: WARNING + 에이전트명

출력: audit-semantic.json
{
  "permission_role": { "violations": [], "clean": [] },
  "contract_completeness": { "missing": [], "orphans": [] },
  "gate_consistency": { "consistent": [], "inconsistent": [] },
  "clarity_scan": { "violations": [], "clean": [] },
  "delegation_pattern": { "compliant": [], "non_compliant": [] },
  "overall": "CLEAN | WARNING | VIOLATION"
}
```

### Phase 3: 감사 리포트 생성

오케스트레이터가 두 검증 결과를 종합하여 리포트를 생성한다.

```markdown
# Olympus Audit Report

## Timestamp
{ISO 8601}

## Summary
- Mechanical: {PASS/FAIL}
- Semantic: {CLEAN/WARNING/VIOLATION}
- **Overall: {CLEAN/WARNING/VIOLATION}**

## Violations (즉시 수정 필요)
| # | Category | Target | Issue | Location |
|---|---|---|---|---|
| 1 | {카테고리} | {대상} | {문제} | {위치} |

## Warnings (수동 확인 권장)
| # | Category | Target | Issue | Location |
|---|---|---|---|---|
| 1 | {카테고리} | {대상} | {문제} | {위치} |

## Info
- {참고 사항}

## Coverage
- Agents scanned: {n}/{total}
- Skills scanned: {n}/{total}
- Docs referenced: {n}/{total}
- Contracts verified: {n}/{total}
```

### 팀 정리

team-teardown.md 프로토콜에 따라 Hephaestus, Athena를 종료한다.

---

## 사용 시나리오

### 1. 변경 후 검증
에이전트나 스킬을 수정한 후 `/olympus:audit`를 실행하여 정합성을 확인한다.

### 2. 정기 검증
새 에이전트나 스킬을 추가한 후 전체 정합성을 점검한다.

### 3. 특정 카테고리만 검증
프롬프트에 카테고리를 지정하여 부분 검증이 가능하다:
- "권한 검증만" → Phase 2-1만 실행
- "계약 검증만" → Phase 2-2만 실행
- "게이트 검증만" → Phase 2-3만 실행
