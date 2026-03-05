---
name: agora
description: "토론의 광장 — 위원회 토론을 통한 의사결정"
---

# /olympus:agora — 토론의 광장

구조화된 위원회 토론을 통해 기술적 의사결정을 내리는 스킬.

## 사용 에이전트 (subagent_type 바인딩)
- **Zeus**: Planner 역할 (tie-breaker) → `subagent_type: "olympus:zeus"`
- **Ares**: Engineering 비평가 → `subagent_type: "olympus:ares"`
- **Eris**: Devil's Advocate (모든 포지션에 대해) → `subagent_type: "olympus:eris"`
- **UX Critic**: UX 비평가 → `subagent_type: "general-purpose"` (UX 프롬프트 주입)

## 게이트
- Normal: Working consensus (≥67%)
- Hell mode (--hell): 만장일치

---

## Execution Flow

```
Phase 1 → Phase 2 → Phase 3 (max 3 rounds) → Phase 4 → Phase 5 → Phase 6
                          ↑                                  ↓
                          └────── Disagreement ──────────────┘
```

### Phase 1: 질문 프레이밍

```
사용자의 의사결정 사항을 구조화:

1. 사용자 입력에서 결정 사항 추출
2. 2-4개 구체적 선택지로 변환
3. AskUserQuestion으로 확인:
   question: "다음과 같이 토론을 구성합니다. 수정할 사항이 있나요?"
   options:
     - "Proceed": 현재 구성으로 진행
     - "Modify options": 선택지 수정
     - "Add context": 추가 컨텍스트 제공
     - "Cancel": 취소

토론 프레임 문서 생성:
{
  "question": "어떤 인증 방식을 사용할 것인가?",
  "options": [
    { "id": "A", "title": "JWT", "description": "..." },
    { "id": "B", "title": "Session", "description": "..." },
    { "id": "C", "title": "OAuth2", "description": "..." }
  ],
  "context": "..."
}
```

### Phase 2: 위원회 구성

```
Prism committee 패턴에 기반:

1. UX 비평가:
   - general-purpose 에이전트에 UX 관점 프롬프트 주입
   - "사용자 경험, 접근성, 사용 편의성 관점에서 각 선택지를 평가하라"

2. Engineering 비평가:
   - Ares (olympus:ares) 사용
   - "기술적 실현 가능성, 유지보수성, 확장성 관점에서 평가하라"

3. Planner (tie-breaker):
   - Zeus (olympus:zeus) 사용
   - "전략적 관점에서 평가하라. UX/Engineering 불일치 시 최종 결정"
```

### Phase 3: 토론 라운드 (최대 3회)

```
각 라운드:

1. 각 위원이 독립적으로 입장 제시 (Task 병렬 실행):
   - 선호 선택지 + 논거
   - 다른 선택지의 장단점
   - clarity-enforcement 준수

2. Orchestrator가 불일치 식별:
   - 각 위원의 선호를 비교
   - 불일치 지점을 명확히 정리

3. 교차 질문 (불일치가 있을 때):
   - 각 위원에게 다른 위원의 논거에 대한 반론 요청
   - 새로운 증거나 관점 제시 기회

4. 합의도 측정 (consensus-levels.md 기준):
   - Strong (3/3): 전원 동일 선택지 → 즉시 종료
   - Working (2/3): 다수 동의 → 이견 기록 후 종료
   - Partial: 추가 라운드 필요
   - No: 추가 라운드 또는 에스컬레이션

5. 합의 도달 또는 3라운드 완료 시 Phase 4로
```

### Phase 4: Eris의 챌린지

```
1. Eris를 Task로 생성:
   - 프롬프트: 모든 위원의 논거 + 현재 합의 상태
   - 미션: 모든 포지션(승인/거부 모두)에 대해 논리적 챌린지

2. Eris의 챌린지:
   - 합의된 선택지의 약점 지적
   - 거부된 선택지의 놓친 장점 지적
   - fallacy-catalog 기반 논리 오류 검출

3. 위원들의 응답 (필요시):
   - Eris의 챌린지가 합의를 변경시킬 수 있음
   - 변경 시 합의도 재측정
```

### Phase 5: 합의 → 권고안

```
Normal mode:
  - Working 이상이면 진행
  - Partial → Zeus가 tie-breaker로 결정
  - No → 사용자에게 에스컬레이션

Hell mode (--hell):
  - Strong 필수 (만장일치)
  - 미달 시 추가 라운드 (제한 없음)

권고안 생성:
  ## Decision: {선택된 옵션}

  ### Rationale
  - {핵심 근거 1}
  - {핵심 근거 2}

  ### Committee Positions
  | Member | Position | Key Argument |
  |---|---|---|
  | UX Critic | {선택지} | {논거} |
  | Engineering (Ares) | {선택지} | {논거} |
  | Planner (Zeus) | {선택지} | {논거} |

  ### Dissent (이견)
  - {반대 의견 + 근거}

  ### DA Challenges (Eris)
  - {해결된 챌린지}
  - {미해결 챌린지 + 리스크}

  ### Consensus Level: {Strong/Working/Partial}

  ### Implementation Notes
  - {선택지 구현 시 주의사항}
```

### Phase 6: 팀 정리

team-teardown.md 프로토콜에 따라 모든 위원을 종료한다.
