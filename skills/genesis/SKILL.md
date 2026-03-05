---
name: genesis
description: "창세 — 명세/설계를 세대별로 진화시키는 진화 루프"
---

# /olympus:genesis — 창세 (진화 루프)

Ouroboros의 핵심 패턴. 명세/설계를 세대별로 진화시켜 수렴할 때까지 반복한다.

## 사용 에이전트
- **Metis**: Wonder (경이) — 근본 질문
- **Eris**: Reflect (성찰) — 논리 감사
- **Orchestrator**: Seed (결정화) + 수렴 검사

## 게이트
- 온톨로지 수렴 ≥ 0.95

## 아티팩트 계약
| 파일 | Phase | 작성자 | 읽는 곳 |
|---|---|---|---|
| `.olympus/{id}/gen-{n}/ontology.json` | 3 | Orchestrator | 수렴 검사 |
| `.olympus/{id}/gen-{n}/spec.md` | 3 | Orchestrator | 다음 세대 |
| `.olympus/{id}/gen-{n}/wonder.md` | 1 | Metis | Reflect |
| `.olympus/{id}/gen-{n}/reflect.md` | 2 | Eris | Seed |
| `.olympus/{id}/lineage.json` | 5 | Orchestrator | 되감기 |
| `.olympus/{id}/convergence.json` | 4 | Orchestrator | 진화 중단 판정 |

---

## Execution Flow

```
Phase 0 (Seed) → Phase 1 (Wonder) → Phase 2 (Reflect) → Phase 3 (Seed) → Phase 4 (Converge?)
                      ↑                                                        ↓ NO
                      └────────────────────────────────────────────────────────┘
                                                                               ↓ YES
                                                                         Phase 5 (Lineage)
```

### Phase 0: 초기 Seed

```
입력: spec.md (Oracle에서 생성) 또는 사용자 직접 입력

1. 초기 온톨로지 추출:
   - spec.md에서 핵심 개념/용어 추출
   - 각 개념: { name, type, description, relationships }
   - Gen 1 ontology.json으로 저장

2. Gen 1 디렉토리 생성:
   mkdir -p .olympus/{id}/gen-1/
   - ontology.json 저장
   - spec.md 복사
```

### Phase 1: Wonder (경이)

"아직 모르는 것이 무엇인가?"

```
1. Metis를 Task로 생성:
   - 프롬프트: 현재 세대의 spec.md + ontology.json
   - 미션: 4가지 근본 질문에 답하라

2. Metis의 4가지 근본 질문 (Ouroboros ontologist):
   a. 본질: "이것의 본질은 무엇인가?"
      - 각 온톨로지 개념의 본질적 속성 식별
      - 부수적 속성과 구분

   b. 근본 원인: "원인인가 증상인가?"
      - 요구사항이 근본 원인을 다루는지, 증상만 다루는지
      - 증상이면 근본 원인 추적

   c. 전제 조건: "이것이 작동하려면 무엇이 필요한가?"
      - 암묵적 전제 조건 발견
      - 의존성 그래프 확장

   d. 숨겨진 가정: "검증되지 않은 가정은?"
      - spec에 암묵적으로 포함된 가정 식별
      - 가정의 유효성 평가

3. 결과를 gen-{n}/wonder.md에 저장
```

### Phase 2: Reflect (성찰)

```
1. 이전 세대와 현재 세대를 비교
2. 온톨로지 돌연변이 식별:
   - 필드 변경: 속성 추가/제거/수정
   - 타입 변경: 개념의 분류 변경
   - 설명 변경: 정의의 정밀화

3. Eris를 Task로 생성 (논리 감사):
   - 프롬프트: wonder.md + 이전 ontology.json + 현재 ontology.json
   - 미션: 진화적 결정의 논리적 타당성 검증
   - fallacy-catalog 기반 검증

4. Eris의 검증:
   - 각 돌연변이에 대해 논리적 근거 확인
   - 순환 논증, 모순 등 검출
   - 결과를 gen-{n}/reflect.md에 저장
```

### Phase 3: Seed (결정화)

```
1. wonder.md + reflect.md를 기반으로:
   - 온톨로지 업데이트 (돌연변이 적용)
   - spec 업데이트 (새로운 이해 반영)
2. Gen N+1 스냅샷 저장:
   mkdir -p .olympus/{id}/gen-{n+1}/
   - ontology.json
   - spec.md
```

### Phase 4: 수렴 검사

```
온톨로지 유사도 계산:
  similarity = name_sim * 0.5 + type_sim * 0.3 + exact_sim * 0.2

  - name_sim: 개념 이름 집합의 Jaccard 유사도
  - type_sim: 개념 타입 분포의 코사인 유사도
  - exact_sim: 완전 일치 개념 비율

수렴 판정:
  if similarity >= 0.95:
    → 진화 중단 → Phase 5
  else:
    → 정체 감지 확인 → Phase 1로 복귀 (또는 측면 사고)

정체 감지:
  - Spinning: 같은 ontology 해시 3회 반복
  - Oscillation: A→B→A→B 2사이클 감지
  - Diminishing: 진행률(1-similarity) 변화 < 0.01 for 3회 연속

정체 감지 시 → 측면 사고 페르소나 활성화:
  AskUserQuestion로 페르소나 선택:
  - Hacker: "실제로 어떤 제약이 진짜인가?"
  - Simplifier: "작동하는 가장 단순한 것은?"
  - Researcher: "어떤 정보가 빠져 있는가?"
  - Architect: "처음부터 다시 설계한다면?"
  - Contrarian: "반대가 사실이라면?"

  선택된 페르소나의 시각으로 Wonder를 재실행

하드 캡: 최대 30세대 (초과 시 강제 중단 + 경고)

convergence.json 저장:
{
  "generation": n,
  "similarity": 0.97,
  "converged": true,
  "stagnation": null,
  "history": [
    { "gen": 1, "similarity": 0.0 },
    { "gen": 2, "similarity": 0.45 },
    ...
  ]
}
```

### Phase 5: 리니지 관리

```
lineage.json 생성:
{
  "id": "{id}",
  "total_generations": n,
  "convergence_score": 0.97,
  "generations": [
    {
      "gen": 1,
      "timestamp": "...",
      "mutations": [],
      "similarity_to_prev": null
    },
    {
      "gen": 2,
      "timestamp": "...",
      "mutations": ["added: PaymentMethod", "refined: User.role"],
      "similarity_to_prev": 0.45
    }
  ],
  "final_spec": "gen-{n}/spec.md",
  "final_ontology": "gen-{n}/ontology.json"
}

되감기 지원:
- 특정 세대로 되돌리기 가능
- lineage.json에서 세대 선택 → 해당 gen-{n}/spec.md 로드
```

### 팀 정리

team-teardown.md 프로토콜에 따라 Metis, Eris를 종료한다.
