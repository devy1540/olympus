---
name: pantheon
description: "만신전의 회의 — 다관점 분석 파이프라인"
---

# /olympus:pantheon — 만신전의 회의

다중 관점에서 문제를 분석하고 Devil's Advocate를 통해 논리적 건전성을 검증하는 파이프라인.

## 사용 에이전트
- **Hermes**: 코드베이스 탐색
- **Helios**: 복잡도 평가 + 관점 생성
- **Ares/Poseidon/Zeus**: 관점별 분석
- **Eris**: Devil's Advocate 챌린지

## 게이트
- Normal: 합의 ≥ Working (67%)
- Hell mode (--hell): 만장일치

## 아티팩트 계약
| 파일 | Phase | 작성자 | 읽는 곳 |
|---|---|---|---|
| `.olympus/{id}/ontology-catalog.md` | 0 | Orchestrator | 모든 에이전트 |
| `.olympus/{id}/ontology-scope-analyst.md` | 0 | Orchestrator | 분석 에이전트 |
| `.olympus/{id}/ontology-scope-da.md` | 0 | Orchestrator | Eris |
| `.olympus/{id}/perspectives.md` | 2 | Helios | 모든 에이전트 |
| `.olympus/{id}/context.md` | 2 | Orchestrator | 모든 에이전트 |
| `.olympus/{id}/analyst-findings.md` | 3 | 분석 에이전트 | Eris |
| `.olympus/{id}/da-evaluation.md` | 4 | Eris | 합의 단계 |
| `.olympus/{id}/prior-iterations.md` | 5 | Orchestrator | 재진입 시 |
| `.olympus/{id}/analysis.md` | 5 | Orchestrator | 후속 스킬 |

---

## Execution Flow

```
Phase 0 (OSM) → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
                                       ↑                      ↓
                                       └──── Feedback Loop ───┘
```

### Phase 0: Ontology Scope Mapping

ontology-scope-mapping.md 프로토콜을 따른다:

```
Step 1: MCP 데이터 소스 발견
  - ListMcpResourcesTool로 사용 가능한 MCP 리소스 열거
  - ToolSearch로 추가 데이터 도구 탐색
  - 사용 가능한 소스 카탈로그 생성

Step 2: 소스 선택
  - AskUserQuestion (multiSelect=true):
    "분석에 사용할 데이터 소스를 선택하세요"
    - 발견된 MCP 소스들
    - 로컬 파일 시스템
    - 웹 검색

Step 3: 외부 소스 추가 (반복)
  - AskUserQuestion: "추가할 외부 소스가 있나요? (URL, 파일 경로, 또는 'done')"
  - URL → WebFetch로 내용 수집
  - File → Read로 내용 수집
  - 'done' → 종료

Step 4: 풀 확인
  - AskUserQuestion:
    - Proceed: 현재 풀로 진행
    - Reselect: Step 2로
    - Add more: Step 3로
    - Cancel: OSM 건너뛰기

Step 5: 스코프 블록 생성
  - ontology-catalog.md 생성
  - ontology-scope-analyst.md 생성 (분석가용)
  - ontology-scope-da.md 생성 (Eris용)

※ MCP가 없으면 Step 1-2를 건너뛰고 Step 3부터 시작 (soft dependency)
```

### Phase 1: Helios의 복잡도 평가 + 관점 생성

```
1. Helios를 Task로 생성:
   - 프롬프트: spec.md + codebase-context.md (있으면) + ontology-catalog.md (있으면)
2. Helios가 6개 차원 복잡도 평가:
   - Domain, Technical, Risk, Stakeholders, Timeline, Novelty
3. 복잡도 프로필에 기반하여 3-6개 직교 관점 도출
4. perspective-quality-gate 적용:
   - Orthogonality (겹침 < 20%)
   - Evidence-based
   - Domain-specific
   - Actionable
5. 각 관점에 분석 에이전트 매핑:
   - 코드 품질 → Ares
   - 보안 → Poseidon
   - 아키텍처 → Zeus (read-only 분석 모드)
   - 범용 → general-purpose에 관점 프롬프트 주입
```

### Phase 2: 관점 승인

```
AskUserQuestion:
  question: "다음 관점으로 분석을 진행합니다:"
  options:
    - "Proceed": 확정된 관점으로 진행
    - "Add perspective": 관점 추가
    - "Remove perspective": 관점 제거
    - "Modify perspective": 관점 수정

확정된 관점 → perspectives.md에 저장 (이후 수정 불가)
context.md 생성: spec + perspectives + ontology 종합
```

### Phase 3: 병렬 분석

```
관점별로 에이전트를 Task로 병렬 생성:

각 에이전트에 주입:
  - worker-preamble.md
  - clarity-enforcement.md
  - ontology-scope-analyst.md (있으면)
  - context.md
  - 할당된 관점의 key questions

에이전트 매핑:
  - 코드 품질 관점 → Ares (olympus:ares)
  - 보안 관점 → Poseidon (olympus:poseidon)
  - 아키텍처 관점 → Zeus (read-only 프롬프트)
  - 기타 관점 → general-purpose + 관점별 프롬프트

모든 분석 결과를 analyst-findings.md에 합산
```

### Phase 4: Eris의 챌린지

```
1. Eris를 Task로 생성:
   - 프롬프트: analyst-findings.md + fallacy-catalog.md + ontology-scope-da.md (있으면)
2. Eris가 모든 분석 결과를 스캔:
   - fallacy-catalog 기반 논리 오류 검출
   - 증거 부족 주장 식별
3. Challenge-Response (최대 2라운드):
   - Round 1: 핵심 챌린지 → 분석가에게 전달
   - Round 2: 잔여 챌린지 (필요시)
4. BLOCKING_QUESTION 해결 우선순위:
   - 도구로 해결 가능 → 도구 실행
   - 분석가가 답할 수 있음 → 분석가 전달
   - 사용자만 답할 수 있음 → AskUserQuestion
5. 판정: SUFFICIENT / NOT_SUFFICIENT / NEEDS_TRIBUNAL
```

### Phase 5: 합의 & 종합

```
consensus-levels.md 기준 적용:

if consensus >= threshold:  # Normal: Working, Hell: Strong
    → analysis.md 생성 (모든 관점의 종합)
    → Phase 6으로
else:
    → 피드백 루프:
      - 기존 분석 결과 보존 (prior-iterations.md에 저장)
      - 새 관점만 추가
      - Phase 3-4 재실행
      - 최대 2회 (normal) / 무제한 (--hell)
      - 2회 실패 후 → 사용자에게 에스컬레이션

analysis.md 구조:
  ## 관점별 요약
  ## 교차 관점 발견
  ## DA 검증 결과
  ## 합의 수준 및 이견
  ## 권고 사항
```

### Phase 6: 팀 정리

team-teardown.md 프로토콜에 따라 모든 분석 에이전트를 종료한다.
