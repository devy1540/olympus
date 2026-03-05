---
name: odyssey
description: "대장정 — Oracle→Genesis→Pantheon→Plan→Execute→Tribunal 전체 파이프라인"
---

# /olympus:odyssey — 대장정 (전체 파이프라인)

Oracle부터 Tribunal까지 전체 하네스 엔지니어링 파이프라인을 순서대로 실행한다.

## 전체 흐름

```
Phase 1: Oracle → spec.md
    ↓ Gate: 모호성 ≤ 0.2
Phase 2: Genesis (선택적) → 진화된 spec.md
    ↓ Gate: 온톨로지 수렴 ≥ 0.95
Phase 3: Pantheon → analysis.md
    ↓ Gate: 합의 ≥ Working
Phase 4: Zeus + Themis → plan.md
    ↓ Gate: Themis APPROVE
Phase 5: Prometheus → 구현
    ↓ Gate: Hephaestus 빌드/테스트 통과
Phase 6: Tribunal → verdict.md
    ↓ APPROVED → Phase 7
    ↓ REJECTED → Phase 5 복귀 (최대 3회)
    ↓ 3회 실패 → Genesis 되감기
Phase 7: 팀 정리
```

## 상태 관리

```json
{
  "id": "odyssey-{YYYYMMDD}-{short-uuid}",
  "phase": "oracle",
  "gates": {
    "ambiguityScore": null,
    "convergenceScore": null,
    "consensusLevel": null,
    "themisVerdict": null,
    "buildPass": null
  },
  "evaluationPass": 0,
  "maxPasses": 3,
  "genesisEnabled": false,
  "artifacts": {
    "specId": null,
    "genesisId": null,
    "pantheonId": null,
    "tribunalId": null
  }
}
```

상태 파일: `.olympus/{id}/odyssey-state.json`

---

## Phase 1: Oracle

```
1. /olympus:oracle 실행
2. 결과: spec.md
3. 게이트 확인:
   - ambiguityScore = read ambiguity-scores.json
   - ambiguityScore ≤ 0.2 → Phase 2
   - else → Oracle 재실행 (사용자 override 허용)
4. odyssey-state.json 업데이트: phase="genesis", specId="{oracle-id}"
```

## Phase 2: Genesis (선택적)

```
활성화 조건 (하나라도 해당 시):
  - 사용자가 --evolve 플래그 사용
  - 자동 감지: spec의 ONTOLOGY 항목 > 10개
  - 자동 감지: OPEN_QUESTIONS > 3개

비활성화 시:
  - Phase 3로 직행

활성화 시:
  1. /olympus:genesis 실행
  2. 결과: 진화된 spec.md
  3. 게이트 확인:
     - convergenceScore ≥ 0.95 → Phase 3
     - 수렴 실패 → 사용자에게 알림 + 현재 spec으로 진행 여부 확인
  4. odyssey-state.json 업데이트: phase="pantheon", genesisId="{genesis-id}"
```

## Phase 3: Pantheon

```
1. /olympus:pantheon 실행
   - spec.md를 입력으로 전달
2. 결과: analysis.md
3. 게이트 확인:
   - consensusLevel ≥ Working → Phase 4
   - Partial → 사용자 결정: 진행 / Pantheon 재실행 (최대 2회)
   - No → Pantheon 재실행 (최대 2회)
4. odyssey-state.json 업데이트: phase="planning", pantheonId="{pantheon-id}"
```

## Phase 4: Zeus의 작업 분해 + Themis의 비평

```
1. Zeus를 Task로 생성:
   - 입력: spec.md + analysis.md
   - 출력: plan.md

2. Themis를 Task로 생성:
   - 입력: plan.md + spec.md
   - 출력: 판정 (APPROVE / REVISE / REJECT)

3. 루프:
   - APPROVE → Phase 5
   - REVISE → Zeus에게 피드백 전달 → plan.md 수정 → Themis 재검토
   - REJECT → 사용자에게 알림 + AskUserQuestion:
     - "Oracle로 돌아가기": Phase 1(Oracle)로 복귀하여 요구사항 재정제
     - "Pantheon으로 돌아가기": Phase 3(Pantheon)로 복귀하여 분석 재실행
     - "현재 상태로 종료": Odyssey 종료
   - 최대 3회 반복

4. odyssey-state.json 업데이트: phase="execution", themisVerdict="APPROVE"
```

## Phase 5: Prometheus의 실행

```
1. Prometheus를 Task로 생성:
   - 입력: plan.md
   - worker-preamble 주입

2. 구현 완료 후 즉시 빌드 확인:
   - Hephaestus를 Task로 생성
   - 빌드/테스트 통과 → Phase 6
   - 빌드/테스트 실패 → Artemis(디버거) 투입 → 수정 → 재확인

3. 디버깅 필요 시:
   - Artemis를 Task로 생성: 근본 원인 분석
   - Prometheus를 Task로 생성: 수정 구현
   - Hephaestus로 재확인

4. odyssey-state.json 업데이트: phase="tribunal", buildPass=true
```

## Phase 6: Tribunal

```
1. /olympus:tribunal 실행
2. 판정 처리:
   - APPROVED → Hera 최종 검증 → Phase 7
   - BLOCKED → Phase 5로 복귀 (빌드 문제)
   - INCOMPLETE → Phase 5로 복귀 (AC 미충족)
   - REJECTED → evaluationPass++

3. 복귀 로직:
   if evaluationPass < maxPasses (3):
     → Phase 5로 복귀 (피드백 포함)
   else:
     → Genesis로 되감기 (spec 진화 필요)
     → AskUserQuestion: "3회 평가 실패. spec을 진화시킬까요?"
       - Yes → Phase 2 (Genesis)
       - No → 현재 상태로 종료

4. Hera 최종 검증 (APPROVED 시):
   - Hera를 Task로 생성
   - 판정: APPROVED / APPROVED_WITH_CAVEATS / REJECTED
   - REJECTED → Phase 5로 복귀
```

## Phase 7: 팀 정리

```
1. team-teardown.md 프로토콜 실행
2. 최종 리포트 생성:
   - 실행된 Phase 목록
   - 각 Phase의 게이트 결과
   - 총 소요 라운드
   - 최종 아티팩트 위치
3. odyssey-state.json 최종 업데이트: phase="completed"
```
