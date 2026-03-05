---
name: evolve
description: "자기 진화 — 실전 테스트와 행동 평가를 통해 Olympus 자체를 개선하는 진화 루프"
---

# /olympus:evolve — 자기 진화

Olympus를 실제 태스크에 실행하고, 결과를 평가하고, 에이전트 프롬프트를 개선하는 셀프 개선 루프.
`/olympus:audit`가 뼈대(구조)를 지킨다면, `/olympus:evolve`는 근육(행동 품질)을 키운다.

## 사용 에이전트
- **Athena**: 산출물 품질 평가 (Semantic Evaluator)
- **Eris**: 평가 결과 챌린지 + 원인 진단 (Devil's Advocate)
- **Metis**: 기대-실제 갭 분석 (Analyst)
- **Prometheus**: 프롬프트 개선 구현 (Executor)

## 게이트
- 품질 점수 ≥ 0.8 (개선 목표 달성)
- `/olympus:audit` CLEAN (구조적 정합성 유지)

## 아티팩트 계약
| 파일 | Phase | 작성자 | 읽는 곳 |
|---|---|---|---|
| `.olympus/{id}/benchmark.md` | 1 | Orchestrator | 모든 Phase |
| `.olympus/{id}/dogfood-result.md` | 2 | Orchestrator | Athena, Metis |
| `.olympus/{id}/eval-matrix.md` | 3 | Orchestrator (from Athena) | Eris, Metis |
| `.olympus/{id}/diagnosis.md` | 4 | Orchestrator (from Metis+Eris) | Prometheus |
| `.olympus/{id}/refinement-log.md` | 5 | Orchestrator | 추적 |
| `.olympus/{id}/evolve-state.json` | all | Orchestrator | 상태 복구 |

---

## Execution Flow

```
Phase 1 (Benchmark) → Phase 2 (Dogfood) → Phase 3 (Evaluate) → Phase 4 (Diagnose)
                                                                       ↓
Phase 7 (Lineage) ← Phase 6 (Audit) ← Phase 5 (Refine) ←─────────────┘
      ↓ 목표 미달
      └──→ Phase 2로 복귀 (최대 5회)
```

### Phase 1: 벤치마크 선정

실행할 벤치마크 태스크를 선정하거나 생성한다.

```
입력 분류:
  - 사용자 제공: 사용자가 벤치마크 태스크를 직접 지정
  - 자동 생성: Olympus가 자체 벤치마크를 생성
  - 히스토리: 이전 evolve 실행의 벤치마크 재사용

자동 벤치마크 생성 시:
  AskUserQuestion:
    question: "어떤 스킬을 테스트할까요?"
    options:
      - "Oracle": 요구사항 정제 품질 테스트
      - "Pantheon": 다관점 분석 품질 테스트
      - "Tribunal": 평가 정확성 테스트
      - "Full pipeline": Odyssey 전체 테스트

벤치마크 정의:
  ## Benchmark

  ### Target Skill
  {테스트할 스킬}

  ### Scenario
  {테스트 시나리오 설명}

  ### Expected Quality
  | Dimension | Minimum | Ideal |
  |---|---|---|
  | Specificity | 0.7 | 0.9 |
  | Evidence Density | 0.6 | 0.8 |
  | Role Adherence | 0.8 | 1.0 |
  | Efficiency | 0.6 | 0.8 |
  | Actionability | 0.7 | 0.9 |

  ### Test Input
  {테스트 입력 데이터}

benchmark.md로 저장
```

### Phase 2: Dogfood (실전 테스트)

벤치마크 태스크에 대해 대상 스킬을 실제로 실행한다.

```
1. 벤치마크의 Target Skill을 확인한다
2. 해당 스킬을 Test Input으로 실행한다:
   - Oracle → spec.md 생성
   - Pantheon → analysis.md 생성
   - Tribunal → verdict.md 생성
   - Odyssey → 전체 파이프라인 실행

3. 실행 중 관찰 데이터 수집:
   - 각 에이전트의 출력 (SendMessage 내용)
   - 라운드 수 (효율성 측정)
   - 게이트 통과/실패 이력
   - 에이전트 간 핸드오프 기록

4. 모든 산출물과 관찰 데이터를 dogfood-result.md에 저장

주의: 실행은 실제 사용자 인터랙션이 필요할 수 있음 (Apollo 인터뷰 등)
     사용자가 벤치마크 답변을 미리 제공하거나, 실행 중 직접 응답
```

### Phase 3: Evaluate (행동 평가)

Athena를 Task로 생성하여 산출물 품질을 5개 차원에서 평가한다.

```
Athena에게 주입:
  - benchmark.md (기대 품질)
  - dogfood-result.md (실제 결과)
  - 평가 루브릭

평가 차원:

3-1. Specificity (구체성) — 0.0~1.0
  산출물의 주장이 얼마나 구체적인가?
  - 1.0: 모든 주장에 file:line, 수치, 구체적 사례 포함
  - 0.5: 일부 주장이 구체적, 나머지는 일반적
  - 0.0: 대부분 "~인 것으로 보인다" 수준

3-2. Evidence Density (증거 밀도) — 0.0~1.0
  주장 대비 증거의 비율
  - claims_with_evidence / total_claims
  - clarity-enforcement 위반 횟수 반영

3-3. Role Adherence (역할 준수) — 0.0~1.0
  각 에이전트가 자기 역할 경계를 지켰는가?
  - 1.0: 모든 에이전트가 역할 내에서만 활동
  - 0.5: 일부 역할 이탈 (예: Ares가 보안 이슈를 지적)
  - 0.0: 역할 구분이 무의미한 수준

3-4. Efficiency (효율성) — 0.0~1.0
  불필요한 라운드나 반복 없이 목표에 도달했는가?
  - 게이트 재시도 횟수
  - 정체(stagnation) 발생 여부
  - 총 라운드 수 대비 유효 라운드 수

3-5. Actionability (실행 가능성) — 0.0~1.0
  산출물이 즉시 실행 가능한 수준인가?
  - 1.0: 다음 단계를 바로 시작할 수 있는 수준
  - 0.5: 추가 명확화가 필요한 부분이 있음
  - 0.0: 산출물만으로는 다음 단계 진행 불가

출력: eval-matrix.md
  ## Evaluation Matrix

  | Dimension | Score | Evidence | Benchmark Target |
  |---|---|---|---|
  | Specificity | {n} | {근거} | {목표} |
  | Evidence Density | {n} | {근거} | {목표} |
  | Role Adherence | {n} | {근거} | {목표} |
  | Efficiency | {n} | {근거} | {목표} |
  | Actionability | {n} | {근거} | {목표} |

  ### Overall Score: {가중 평균}
  ### Weakest Dimension: {가장 낮은 차원}
  ### Strongest Dimension: {가장 높은 차원}
```

### Phase 4: Diagnose (원인 진단)

Metis와 Eris를 병렬로 Task 생성하여 품질 저하 원인을 에이전트 프롬프트까지 추적한다.

```
Metis (갭 분석):
  입력: eval-matrix.md + dogfood-result.md + agents/*.md
  미션: 품질 저하의 원인을 에이전트 프롬프트에서 추적

  분석 프로토콜:
  1. 가장 낮은 점수의 차원을 선택
  2. 해당 차원에서 문제가 된 구체적 산출물 식별
  3. 그 산출물을 생성한 에이전트 식별
  4. 에이전트 프롬프트에서 원인 추적:
     - Investigation_Protocol이 불충분한가?
     - Output_Format이 구체성을 강제하지 않는가?
     - Constraints가 역할 이탈을 허용하는가?
     - Examples가 올바른 행동을 보여주지 않는가?
     - Failure_Modes_To_Avoid가 실제 실패를 커버하지 않는가?
  5. 구체적 개선 제안 도출

Eris (챌린지):
  입력: eval-matrix.md + dogfood-result.md
  미션: Athena의 평가가 정확한지 검증 + 추가 문제 식별

  검증 항목:
  - 평가 점수가 너무 관대하지 않은가? (Generous Scoring)
  - 놓친 문제가 있지 않은가?
  - 표면적 증상이 아닌 근본 원인을 찾았는가?

두 결과를 종합하여 diagnosis.md 생성:

  ## Diagnosis

  ### Root Causes (근본 원인)
  | # | Symptom | Agent | Prompt Location | Root Cause | Severity |
  |---|---|---|---|---|---|
  | 1 | {증상} | {에이전트} | {섹션:라인} | {원인} | CRITICAL/HIGH/MEDIUM |

  ### Improvement Proposals (개선 제안)
  | # | Target | Current | Proposed | Expected Impact |
  |---|---|---|---|---|
  | 1 | {agent.md:섹션} | {현재 내용} | {개선 내용} | {예상 효과} |

  ### Eris Challenges
  - {챌린지 내용 + 해결 여부}
```

### Phase 5: Refine (프롬프트 개선)

```
1. diagnosis.md를 사용자에게 제시:
   AskUserQuestion:
     question: "다음 개선 사항을 적용할까요?"
     options:
       - "Apply all": 모든 개선 적용
       - "Select": 개선 사항 선택 적용
       - "Modify": 개선 사항 수정 후 적용
       - "Skip": 이번 사이클 건너뛰기

2. 승인된 개선 사항에 대해 Prometheus를 Task로 생성:
   - 입력: diagnosis.md의 Improvement Proposals
   - 미션: 에이전트 프롬프트 수정
   - 제약: diagnosis.md에 명시된 수정만 수행 (스코프 이탈 금지)

3. 변경 사항을 refinement-log.md에 기록:

   ## Refinement Log — Iteration {n}

   ### Changes Applied
   | # | File | Section | Change | Rationale |
   |---|---|---|---|---|
   | 1 | {파일} | {섹션} | {변경 내용} | {근거} |

   ### Changes Rejected
   | # | Proposal | Reason |
   |---|---|---|
   | 1 | {제안} | {거부 사유} |
```

### Phase 6: Audit (정합성 검증)

```
수정된 에이전트 프롬프트에 대해 /olympus:audit를 실행:

1. 구조적 정합성 확인:
   - 권한-역할 정합성 유지되는가?
   - 교차 참조 깨지지 않았는가?
   - 아티팩트 계약 일관성 유지되는가?

2. 판정:
   - CLEAN → Phase 7로
   - VIOLATION → Phase 5로 복귀 (수정이 구조를 깨뜨림)
   - WARNING → 사용자에게 알림 후 Phase 7로
```

### Phase 7: 리니지 & 수렴 판정

```
evolve-state.json 업데이트:
{
  "id": "evolve-{YYYYMMDD}-{short-uuid}",
  "iteration": n,
  "maxIterations": 5,
  "benchmark": "benchmark.md",
  "history": [
    {
      "iteration": 1,
      "scores": {
        "specificity": 0.6,
        "evidence_density": 0.5,
        "role_adherence": 0.9,
        "efficiency": 0.7,
        "actionability": 0.6
      },
      "overall": 0.66,
      "changes": ["apollo.md: Investigation_Protocol 강화", ...],
      "audit": "CLEAN"
    }
  ],
  "target": 0.8,
  "converged": false
}

수렴 판정:
  if overall >= 0.8:
    → 수렴 완료. 최종 리포트 생성
  elif iteration >= maxIterations:
    → 사용자에게 알림:
      AskUserQuestion:
        - "Continue": maxIterations 연장 (+3회)
        - "Accept": 현재 상태로 수용
        - "Reset benchmark": 벤치마크 변경 후 재시도
  elif score_delta < 0.02 for 2 iterations:
    → 정체 감지. 사용자에게 알림:
      "2회 연속 개선폭이 미미합니다. 벤치마크를 변경하거나 다른 차원에 집중할까요?"
  else:
    → Phase 2로 복귀 (같은 벤치마크로 재실행)

최종 리포트:
  ## Evolution Report

  ### Iterations: {총 반복 수}
  ### Score Progression
  | Iteration | Specificity | Evidence | Role | Efficiency | Action | Overall |
  |---|---|---|---|---|---|---|
  | 1 | ... | ... | ... | ... | ... | 0.66 |
  | 2 | ... | ... | ... | ... | ... | 0.74 |
  | 3 | ... | ... | ... | ... | ... | 0.82 |

  ### Key Improvements
  - {핵심 개선 사항 1}
  - {핵심 개선 사항 2}

  ### Files Modified
  | File | Total Changes | Most Impactful Change |
  |---|---|---|
  | {파일} | {변경 수} | {가장 효과적 변경} |

  ### Remaining Weaknesses
  - {아직 개선이 필요한 부분}
```

### 팀 정리

team-teardown.md 프로토콜에 따라 Athena, Eris, Metis, Prometheus를 종료한다.

---

## 벤치마크 라이브러리

반복 사용을 위한 벤치마크 예시:

### Oracle 벤치마크: "사용자 인증 시스템"
```
Target: Oracle
Input: "로그인 기능을 만들어주세요"
Expected: 모호한 입력에서 구체적 spec.md가 나오는지
Focus: Apollo의 인터뷰 품질, Metis의 갭 분석 깊이
```

### Pantheon 벤치마크: "결제 모듈 분석"
```
Target: Pantheon
Input: 샘플 결제 코드 + spec.md
Expected: 도메인 특화 관점이 나오는지 (범용 관점 배제)
Focus: Helios의 관점 품질, Ares/Poseidon의 분석 깊이
```

### Tribunal 벤치마크: "의도적 결함 코드"
```
Target: Tribunal
Input: AC 일부를 의도적으로 미충족한 코드
Expected: 미충족 AC를 정확히 탐지하는지
Focus: Athena의 정확도, Hephaestus의 기계 검증 완전성
```
