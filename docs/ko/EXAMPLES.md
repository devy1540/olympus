[English](../EXAMPLES.md) | **한국어**

# Olympus 활용 예시

각 스킬을 언제, 어떻게 사용하는지 실전 시나리오로 설명한다.

---

## 어떤 스킬을 써야 할까?

```
"막연한 아이디어가 있어"                  → /olympus:oracle
"스펙이 있는데 더 다듬고 싶어"            → /olympus:genesis
"여러 관점에서 분석해줘"                  → /olympus:pantheon
"A랑 B 중 뭘 선택할지 결정해줘"           → /olympus:agora
"처음부터 끝까지 다 만들어줘"             → /olympus:odyssey
"만든 걸 평가해줘"                       → /olympus:tribunal
"Olympus 처음 써봐"                     → /olympus:hestia
"플러그인 설치 확인"                      → /olympus:setup
```

---

## 예시 1: 막연한 아이디어를 스펙으로

**상황**: 푸시 알림 기능을 추가하고 싶은데 세부사항을 정리하지 못했다.

```
나:  /olympus:oracle

     "앱에 푸시 알림 기능을 추가하고 싶어"
```

**진행 과정:**

1. **Hermes**가 코드베이스 탐색 — 기존 인증, API 라우트, DB 스키마 파악
2. **Apollo**가 소크라테스식 인터뷰 시작:
   ```
   Apollo: "알림을 발생시키는 트리거는? 사용자 행동, 시스템 이벤트, 스케줄?"
   나:     "사용자 행동과 시스템 이벤트 둘 다"
   Apollo: "전달 채널은? 푸시만, 아니면 이메일/SMS도?"
   나:     "지금은 푸시와 이메일, SMS는 나중에"
   Apollo: "예상 볼륨은? 하루 100건, 10만건?"
   나:     "하루 약 1만건"
   ```
3. **모호성 게이트** 확인: 점수 0.15 (≤ 0.2) — 통과
4. **Metis**가 코드베이스 대비 갭 분석 수행
5. 결과물: `.olympus/{id}/spec.md` — GOAL, ACCEPTANCE_CRITERIA, 식별된 갭이 포함된 구조화된 명세

**Oracle을 쓸 때:**
- 범위가 불명확한 새 기능을 시작할 때
- 이해관계자로부터 새 요구사항을 받았을 때
- 복잡한 기능의 코드 작성 전

---

## 예시 2: 세대별 스펙 진화

**상황**: Oracle에서 나온 스펙이 있지만 더 깊은 정제가 필요하다.

```
나:  /olympus:genesis

     (spec.md를 붙여넣거나 Oracle 아티팩트를 참조)
```

**진행 과정:**

각 세대 사이클:
1. **Metis** (탐구): "어떤 근본적 질문이 남아있나? 검증되지 않은 가정은?"
2. **Eris** (성찰): "이 스펙은 동기 처리를 가정하는데 — 큐가 밀리면?"
3. **오케스트레이터** (결정화): 통찰을 새 버전의 스펙으로 결정화
4. **수렴 확인**: 세대 간 온톨로지(핵심 개념) 비교

```
Gen 1: 수렴도 0.45 — "에러 처리에 주요 갭"
Gen 2: 수렴도 0.72 — "큐 백프레셔 전략 추가"
Gen 3: 수렴도 0.91 — "재시도 로직 엣지 케이스"
Gen 4: 수렴도 0.96 — 수렴 완료 (≥ 0.95)
```

**Genesis를 쓸 때:**
- 스펙이 불완전한데 어디가 빠졌는지 짚기 어려울 때
- 상호작용하는 컴포넌트가 많은 복잡한 도메인
- 구현 전에 스펙을 "성숙"시키고 싶을 때

---

## 예시 3: 다관점 분석

**상황**: 데이터베이스 마이그레이션 전략을 평가해야 한다.

```
나:  /olympus:pantheon

     "MySQL에서 PostgreSQL로 마이그레이션할 계획이야. 마이그레이션 전략을 평가해줘."
```

**진행 과정:**

1. **Hermes**가 코드베이스 탐색 — ORM 사용, 로우 쿼리, 스토어드 프로시저 파악
2. **Helios**가 4개 직교 관점 생성:
   - 성능 (쿼리 패턴, 인덱싱 차이)
   - 데이터 무결성 (타입 매핑, 제약조건 마이그레이션)
   - 보안 (권한 모델, 암호화 차이)
   - 운영 리스크 (롤백 전략, 다운타임)
3. **Ares + Poseidon + Zeus**가 각 관점에서 병렬 분석
4. **Eris** (악마의 변호인): "ORM이 모든 차이를 추상화한다고 가정하지만 — MySQL 전용 문법의 로우 쿼리가 23개 있는데..."
5. 합의: 75% (실무적) — 통과

**Pantheon을 쓸 때:**
- 아키텍처 결정을 평가할 때
- 대규모 변경 전 리스크 평가
- 분석의 사각지대를 찾아야 할 때

---

## 예시 4: 기술적 의사결정

**상황**: 팀이 새 API에 REST vs GraphQL을 놓고 합의하지 못한다.

```
나:  /olympus:agora

     "새 공개 API에 REST와 GraphQL 중 뭘 써야 해?
      맥락: 50개 이상 엔드포인트, 모바일+웹 클라이언트, 8명 팀"
```

**진행 과정:**

1. **프레이밍**: 오케스트레이터가 토론 구조화 (이해관계자, 제약, 기준)
2. **위원회** (3인):
   - Zeus (아키텍트): "GraphQL이 모바일의 오버페칭을 줄인다"
   - Ares (엔지니어): "REST가 캐싱과 레이트 리밋이 더 간단하다"
   - UX 비평가: "모바일은 유연한 쿼리가 필요 — 여기선 GraphQL이 우세"
3. **토론** (최대 3라운드): 각 역할이 상대 논점에 반론
4. **Eris** 도전: "팀에 GraphQL 경험이 있다고 다들 가정하는데. 학습 비용은?"
5. **결정**: 다수 의견과 반대 의견이 구조화된 판결

**Agora를 쓸 때:**
- 팀 내 기술 방향 의견 충돌
- "만들기 vs 구매" 결정
- 경쟁하는 접근법 중 선택

---

## 예시 5: 전체 파이프라인 (처음부터 끝까지)

**상황**: 사용자 인증 시스템을 아이디어부터 검증된 코드까지 완성.

```
나:  /olympus:odyssey

     "리프레시 토큰이 포함된 OAuth2 인증 시스템을 만들어줘"
```

**진행 과정 (6단계):**

```
Phase 1: Oracle
  Hermes 탐색 → Apollo 인터뷰 → spec.md
  게이트: 모호성 ≤ 0.2 ✓

Phase 2: Genesis (필요시)
  Metis 질문 → Eris 도전 → 진화된 스펙
  게이트: 수렴도 ≥ 0.95 ✓

Phase 3: Pantheon
  인증 설계의 다관점 분석
  게이트: 합의 ≥ 67% ✓

Phase 4: 계획
  Zeus 구현 계획 작성 → Themis 검토
  게이트: Themis 승인 ✓

Phase 5: 실행
  Prometheus가 코드 구현

Phase 6: Tribunal
  Hephaestus: 빌드/테스트/린트 → 통과
  Athena: AC 검증 → 8/8 충족
  합의: Ares + Eris + Hera → 승인
```

Tribunal이 거부하면: 최대 3회 재시도 → 이후 Genesis로 되감기.

**Odyssey를 쓸 때:**
- 완전한 엄격함이 필요한 새 기능
- 요구사항 + 구현 + 평가를 모두 원할 때
- 실수가 비용이 큰 고위험 기능

---

## 예시 6: 기존 코드 평가

**상황**: PR이 올라왔고 철저한 리뷰가 필요하다.

```
나:  /olympus:tribunal

     "src/auth/ 에 있는 인증 서비스 구현을 평가해줘"
```

**진행 과정 (3단계):**

```
Stage 1 — 기계적 검증 (Hephaestus)
  빌드:     ✓ 컴파일 성공
  테스트:   ✓ 47/47 통과
  린트:     ✓ 경고 0건
  타입체크: ✓ 에러 없음
  → 통과 (Stage 2로 진행)

Stage 2 — 의미적 평가 (Athena)
  AC 1: "유효한 자격증명 GIVEN /login WHEN THEN 200 + 토큰"  → 충족 (auth.test.ts:15)
  AC 2: "만료된 토큰 GIVEN /refresh WHEN THEN 새 토큰 쌍"   → 충족 (refresh.test.ts:8)
  AC 3: "유효하지 않은 토큰 GIVEN /api/* WHEN THEN 401"     → 충족 (middleware.test.ts:22)
  → 3/3 AC 충족

Stage 3 — 합의 평가
  Ares:  "구현이 견고함. 사소: /login에 레이트 리밋 고려 필요"
  Eris:  "리프레시 토큰 순환이 빠져있음 — RFC 6749 §10.4"
  Hera:  "테스트 통과하지만 토큰 순환 통합 테스트 없음"
  → 조건부 승인 (APPROVED_WITH_CAVEATS)
```

**Tribunal을 쓸 때:**
- 기능 구현 후 셀프 리뷰
- 머지 전 코드 품질 평가
- 증거 기반 승인/거부가 필요할 때

---

## 예시 7: 프로젝트 온보딩

**상황**: 기존 프로젝트에서 Olympus를 처음 사용한다.

```
나:  /olympus:hestia
```

**진행 과정:**

1. **스캔**: Next.js + TypeScript + Prisma + PostgreSQL 감지
2. **평가**:
   - LOC: ~45k
   - 테스트 커버리지: 62%
   - 복잡도: 중간
   - CI: GitHub Actions 존재
3. **추천**:
   ```
   중간 복잡도의 웹 앱이며 테스트 커버리지가 양호합니다.

   추천 첫 스킬: /olympus:oracle
     → 실시간 기능을 추가하고 싶다고 하셨습니다.
       코딩 전에 Oracle로 요구사항을 명확히 하세요.

   기존 코드 리뷰: /olympus:tribunal
     → 인증 모듈을 인수 기준 대비 평가하세요.

   아키텍처 결정: /olympus:agora
     → 실시간 기능에 WebSocket vs SSE를 토론하세요.
   ```

---

## 스킬 조합

스킬은 조합해서 사용할 수 있다. 자주 쓰는 조합:

| 목표 | 조합 |
|:-----|:-----|
| 기능 처음부터 | Oracle → Genesis → Odyssey |
| 평가 + 개선 | Tribunal → (수정) → Tribunal |
| 결정 후 구현 | Agora → Oracle → Odyssey |
| 분석 후 결정 | Pantheon → Agora |
| 스펙 정제 | Oracle → Genesis → Genesis |

### 팁: 아티팩트 체이닝

각 스킬의 출력이 다음 스킬의 입력이 된다:

```
Oracle   → spec.md
Genesis  → 진화된 spec.md (Oracle의 spec.md를 읽음)
Pantheon → analysis.md (spec.md를 읽음)
Odyssey  → verdict.md (위 모든 것을 오케스트레이션)
```

모든 아티팩트는 `.olympus/{skill}-{date}-{uuid}/`에 저장되고 자동으로 연결된다.

---

## 빠른 참조

| 스킬 | 입력 | 출력 | 게이트 |
|:-----|:-----|:-----|:-------|
| `/olympus:oracle` | 막연한 아이디어 | `spec.md` | 모호성 ≤ 0.2 |
| `/olympus:genesis` | 스펙 | 진화된 스펙 | 수렴도 ≥ 0.95 |
| `/olympus:pantheon` | 문제/결정 | `analysis.md` | 합의 ≥ 67% |
| `/olympus:agora` | 토론 주제 | `decision.md` | 합의 ≥ 67% |
| `/olympus:odyssey` | 아이디어 | 코드 + `verdict.md` | 모든 게이트 |
| `/olympus:tribunal` | 구현체 | `verdict.md` | 기계적 + 의미적 |
| `/olympus:hestia` | (프로젝트) | 스킬 추천 | — |
| `/olympus:setup` | — | 설치 리포트 | — |
| `/olympus:audit` | — | `audit-report.md` | — |
| `/olympus:evolve` | — | 개선된 Olympus | 점수 ≥ 0.8 |
