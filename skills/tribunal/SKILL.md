---
name: tribunal
description: "신들의 재판 — 3단계 평가 파이프라인"
---

# /olympus:tribunal — 신들의 재판

기계적 검증 → 의미론적 평가 → 합의 평가의 3단계로 구현을 평가하는 파이프라인.

## 사용 에이전트
- **Hephaestus**: 기계적 검증 (Stage 1)
- **Athena**: 의미론적 평가 (Stage 2)
- **Ares + Eris + Hera**: 합의 평가 (Stage 3, 조건부)

## 최종 판정
APPROVED / BLOCKED / INCOMPLETE / REJECTED

## 아티팩트 계약
| 파일 | Stage | 작성자 | 읽는 곳 |
|---|---|---|---|
| `.olympus/{id}/mechanical-result.json` | 1 | Hephaestus | Athena |
| `.olympus/{id}/semantic-matrix.md` | 2 | Athena | Stage 3 |
| `.olympus/{id}/consensus-record.json` | 3 | Orchestrator | 최종 판정 |
| `.olympus/{id}/verdict.md` | 3 | Orchestrator | 사용자 |

---

## Execution Flow

```
Stage 1 (Mechanical) → FAIL? → BLOCKED
                     → PASS → Stage 2 (Semantic) → FAIL? → INCOMPLETE
                                                  → PASS → Stage 3? → Verdict
```

### Stage 1: Hephaestus의 기계적 검증

```
1. Hephaestus를 Task로 생성:
   - 프롬프트: "프로젝트의 빌드, 린트, 테스트, 타입체크를 실행하라"
2. Hephaestus가 순서대로 실행:
   a. Build: 빌드 명령 실행
   b. Lint: 린트 검사
   c. Type check: 타입 체크
   d. Test: 테스트 실행
3. 결과를 mechanical-result.json에 저장
4. 판정:
   - 모든 항목 PASS → Stage 2로
   - 하나라도 FAIL → BLOCKED 판정 + 구체적 오류 리포트
     verdict.md에 기록하고 종료
```

### Stage 2: Athena의 의미론적 평가

```
1. Athena를 Task로 생성:
   - 프롬프트: spec.md + mechanical-result.json
2. Athena가 평가:
   a. spec.md에서 AC 목록 추출
   b. 각 AC에 대해 구현 증거 탐색 (file:line)
   c. AC 충족 판정: MET (1.0) / PARTIALLY_MET (0.5) / NOT_MET (0.0)
   d. 전체 점수 계산: sum / count
3. 결과를 semantic-matrix.md에 저장
4. 판정:
   - AC 준수율 = 100% AND 전체 점수 ≥ 0.8 → Stage 3 조건 확인
   - 그 외 → INCOMPLETE 판정
     미충족 AC 목록과 함께 verdict.md에 기록
```

### Stage 3: 합의 평가 (조건부 트리거)

**트리거 조건** (하나라도 해당 시 실행):
- spec 수정이 발생한 경우
- 전체 점수 < 0.8
- 스코프 이탈이 감지된 경우
- 사용자가 명시적으로 요청한 경우

트리거 조건에 해당하지 않으면 Stage 2 결과로 바로 APPROVED.

```
트리거 시:
1. 세 에이전트를 Task로 병렬 생성:

   Ares (Proposer):
   - 역할: 품질 관점에서 승인/거부 논증
   - 입력: semantic-matrix.md + 코드
   - 출력: 승인 또는 거부 + 논거

   Eris (Devil's Advocate):
   - 역할: Ares의 논증에 반론
   - 입력: Ares의 논증 + semantic-matrix.md
   - 출력: 반론 + 증거

   Hera (Synthesizer):
   - 역할: 양쪽 의견 종합 + 테스트 실행 증거
   - 입력: Ares 논증 + Eris 반론 + 테스트 결과
   - 출력: 종합 판정

2. 승인 기준: 과반 ≥ 66%
   - 3명 중 2명 이상 승인 → APPROVED
   - 1명만 승인 → REJECTED + 반대 의견 기록
   - 전원 거부 → REJECTED

3. consensus-record.json에 투표 결과 저장
```

### 최종 판정

```
verdict.md 생성:

# Tribunal Verdict

## Stage Results
- Stage 1 (Mechanical): {PASS/FAIL}
- Stage 2 (Semantic): {점수} — {PASS/FAIL}
- Stage 3 (Consensus): {실행 여부} — {결과}

## Final Verdict: {APPROVED / BLOCKED / INCOMPLETE / REJECTED}

## Details
{판정별 상세 내용}

## Recommendations
{후속 조치 권고}
```

### 팀 정리

team-teardown.md 프로토콜에 따라 모든 평가 에이전트를 종료한다.
