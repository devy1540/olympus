---
name: oracle
description: "델포이의 신탁 — 요구사항 정제 파이프라인"
---

# /olympus:oracle — 델포이의 신탁

요구사항을 체계적으로 정제하여 구조화된 spec.md를 생성하는 파이프라인.

## 사용 에이전트 (subagent_type 바인딩)
- **Hermes**: 코드베이스 탐색 (Phase 1) → `subagent_type: "olympus:hermes"`
- **Apollo**: 인터뷰 루프 (Phase 2) → `subagent_type: "olympus:apollo"`
- **Metis**: 갭 분석 (Phase 4) → `subagent_type: "olympus:metis"`

## 게이트
- 모호성 점수 ≤ 0.2

## 아티팩트 계약
| 파일 | Phase | 작성자 | 읽는 곳 |
|---|---|---|---|
| `.olympus/{id}/codebase-context.md` | 1 | Hermes | Apollo, Metis |
| `.olympus/{id}/interview-log.md` | 2 | Apollo | Metis |
| `.olympus/{id}/ambiguity-scores.json` | 2 | Apollo | 게이트 판정 |
| `.olympus/{id}/gap-analysis.md` | 4 | Metis | Zeus, Helios |
| `.olympus/{id}/spec.md` | 5 | Orchestrator | 모든 후속 스킬 |

---

## Execution Flow

```
Phase 0 → Phase 1 → Phase 2 → Phase 3 (Gate) → Phase 4 → Phase 5
```

### Phase 0: 입력 분류

사용자 입력을 분류하여 인터뷰 깊이를 결정한다.

```
Input Classification:
- file: 파일 경로 → 내용 읽기
- URL: 웹 URL → WebFetch로 내용 가져오기
- text: 텍스트 → 직접 사용
- conversation: 대화 컨텍스트 → 이전 대화에서 추출

Complexity Assessment:
- Trivial: 명확하고 단순 → Phase 1-2 skip, 바로 Phase 5
- Clear: 대부분 명확, 약간의 확인 필요 → light interview (3 rounds max)
- Vague: 상당한 모호성 → full interview (10 rounds max)
- Contradictory: 모순 포함 → deep interview (모순 해결 우선)
```

### Phase 1: Hermes의 코드베이스 탐색

```
1. Hermes를 Task로 생성:
   - 프롬프트: "사용자 요구사항 '{input}'과 관련된 코드베이스 컨텍스트를 수집하라"
   - worker-preamble 주입
2. Hermes가 탐색 결과를 codebase-context.md에 저장
3. 탐색 결과를 Apollo에게 컨텍스트로 전달
```

### Phase 2: Apollo의 인터뷰 루프

```
1. Apollo를 Task로 생성:
   - 프롬프트: codebase-context.md + 사용자 입력 + 복잡도 수준
2. Apollo가 AskUserQuestion으로 1개씩 질문
3. 각 답변 후:
   a. 모호성 점수 갱신 (ambiguity-scoring.md 기준)
   b. interview-log.md 업데이트
   c. ambiguity-scores.json 업데이트
4. 정체 감지:
   - Spinning: 같은 주제로 3회 질문 → 다음 차원으로 이동
   - Oscillation: A↔B 반복 → 사용자에게 결정 요청
   - Diminishing: Δ < 0.02 → 현재 차원 종료
5. 종료 조건: 모호성 ≤ 0.2 또는 max rounds 도달
```

### Phase 3: 모호성 게이트

```
ambiguity = read ambiguity-scores.json

if ambiguity <= 0.2:
    → Phase 4
else if rounds >= 10:
    → 잔여 갭을 사용자에게 제시
    → AskUserQuestion: "다음 갭이 남아있습니다. 진행하시겠습니까?"
    → Override 시 Phase 4로
else:
    → Phase 2로 복귀
```

### Phase 4: Metis의 갭 분석

```
1. Metis를 Task로 생성:
   - 프롬프트: interview-log.md + codebase-context.md
2. Metis가 분석 수행:
   - Missing Questions
   - Undefined Guardrails
   - Scope Risks
   - Unvalidated Assumptions
   - Acceptance Criteria
   - Edge Cases
3. 결과를 gap-analysis.md에 저장
```

### Phase 5: Seed 생성

interview-log.md + gap-analysis.md를 종합하여 spec.md를 생성:

```markdown
# Specification: {title}

## GOAL
{목표 — 명확하고 측정 가능}

## CONSTRAINTS
{제약조건 목록}

## ACCEPTANCE_CRITERIA
1. GIVEN {전제} WHEN {행동} THEN {결과}
2. ...

## SCOPE
### In Scope
- {포함 항목}
### Out of Scope
- {제외 항목}

## ASSUMPTIONS
- {검증된 가정} — 검증 방법: {방법}

## EDGE_CASES
1. {케이스} — 예상 동작: {동작}

## OPEN_QUESTIONS
- {미해결 질문} (있으면)

## ONTOLOGY
| Term | Definition |
|---|---|
| {용어} | {정의} |

## AMBIGUITY_SCORE
{최종 점수}
```

### 팀 정리

team-teardown.md 프로토콜에 따라 Hermes, Apollo, Metis를 종료한다.
