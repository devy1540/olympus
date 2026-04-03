[English](../../README.md) | **한국어**

<p align="center">
  <br/>
  <strong>&#x1D6C0; ─────────── &#x1D6C0;</strong>
  <br/><br/>
  <strong>O L Y M P U S</strong>
  <br/>
  <sub>올 림 푸 스</sub>
  <br/><br/>
  <strong>&#x1D6C0; ─────────── &#x1D6C0;</strong>
  <br/>
</p>

<p align="center">
  <em>"신은 그저 질문하는 자일뿐, 운명은 내가 던지는 질문이다. 답은 그대들이 찾아라."</em>
  <br/>
  <sub>14명의 신이 논쟁하고, 도전하고, 검증한다 — 소프트웨어가 가정에 기대어 출시되지 않도록.</sub>
</p>

<p align="center">
  <a href="#빠른-시작">빠른 시작</a> ·
  <a href="#철학">철학</a> ·
  <a href="#파이프라인">파이프라인</a> ·
  <a href="#스킬">스킬</a> ·
  <a href="#열네-명의-신">에이전트</a> ·
  <a href="EXAMPLES.md">활용 예시</a>
</p>

---

> *신들은 동의하지 않는다. 그것이 핵심이다.*

Olympus는 Claude Code용 **하네스 엔지니어링 플러그인**이다. 14명의 에이전트 — 각각 고유한 역할과 엄격한 권한을 가진 그리스 신 — 가 구조화된 적대적 협업을 통해 요구사항을 정제하고, 다양한 관점에서 분석하고, 소프트웨어를 구현하고 평가한다.

대부분의 AI 코딩이 실패하는 이유는 아무도 요구사항에 의문을 제기하지 않기 때문이다. Olympus는 답을 허용하기 전에 반드시 질문을 강제한다.

---

## 철학

> *"너 자신을 알라"* — 델포이 아폴로 신전의 비문

소프트웨어는 세 지점에서 실패한다: **불명확한 요구사항**, **검증되지 않은 가정**, **확인되지 않은 결과**. Olympus는 에이전트 수준에서 관심사를 분리함으로써 이 세 가지를 모두 해결한다:

```
  계획하는 자(Zeus)는      자신의 계획을 검토할 수 없다 (Themis가 한다).
  구축하는 자(Prometheus)는 자신의 작업을 평가할 수 없다 (Athena가 한다).
  분석하는 자(Ares)는      악마의 변호인을 살아남아야 한다 (Eris가 한다).
```

이것은 관료주의가 아니다 — 이것은 **구조적 정직성**이다. 모든 주장은 `file:line` 증거를 요구한다. 모든 분석은 적대적 도전을 살아남아야 한다. 모든 게이트는 수학적 임계값을 가지며, 감각적 판단이 아니다.

```
  Ambiguity Gate     ≤ 0.2    "구축할 만큼 명확한가?"
  Convergence Gate   ≥ 0.95   "스펙이 안정화되었는가?"
  Consensus Gate     ≥ 67%    "검토자들이 동의하는가?"
  Quality Gate       ≥ 0.8    "결과물이 충분히 좋은가?"
```

네 개의 숫자. 수학이 승인할 때까지 시스템이 진행을 거부하는 네 개의 순간.

---

## 빠른 시작

```bash
# 터미널에서
claude plugin marketplace add devy1540/olympus
claude plugin install olympus@olympus-marketplace
```

```
# Claude Code 안에서
/plugin marketplace add devy1540/olympus
/plugin install olympus@olympus-marketplace

# 설치 검증
/olympus:setup

# 프로젝트 온보딩 — 프로젝트를 스캔하고 추천 받기
/olympus:hestia

# 요구사항 정제
/olympus:oracle

# 전체 파이프라인: 요구사항 → 분석 → 구현 → 평가
/olympus:odyssey
```

<details>
<summary><strong>무슨 일이 일어난 것인가?</strong></summary>

```
/olympus:oracle    →  소크라테스식 인터뷰로 숨겨진 가정 노출
                      모호성 점수화 및 게이트 통과 (≤ 0.2)
                      코드베이스 대비 갭 분석
                      → spec.md

/olympus:odyssey   →  Oracle (정제) → Genesis (진화) → Pantheon (분석)
                      → 계획 + 구현 → Tribunal (평가)
                      → verdict.md
```

신들이 숙고했다. 당신의 스펙은 시련을 통과했다.

</details>

---

## 파이프라인

Olympus는 특화된 스킬의 파이프라인으로 작동하며, 각 스킬은 여러 에이전트를 조율한다:

```
    Oracle → Genesis → Pantheon → Plan → Execute → Tribunal
     (질문)  (진화)    (분석)    (설계)  (구축)    (판결)
       ↑                                               ↓
       └──────────── 거부됨? 재시도 또는 되감기 ────────┘
```

각 단계에는 **게이트**가 있다. 통과하지 않으면 어떤 단계도 진행하지 않는다.

| 단계 | 게이트 | 임계값 | 내용 |
|:-----|:-------|:------:|:-----|
| **Oracle** | Ambiguity Score | ≤ 0.2 | 요구사항이 80% 이상 명확해질 때까지 소크라테스식 인터뷰 |
| **Genesis** | Ontology Convergence | ≥ 0.95 | 스펙이 안정될 때까지 세대별로 진화 |
| **Pantheon** | Consensus | ≥ 67% | 다관점 분석이 악마의 변호인을 살아남음 |
| **Tribunal** | Mechanical + Semantic | 모두 통과 | 빌드, 테스트, 타입 검사, 그 후 AC 검증 |

---

## 스킬

### `/olympus:oracle` — 델포이의 신탁

모호한 아이디어를 검증된 명세로 전환한다.

```
Hermes (탐색) → Apollo (인터뷰) → Ambiguity Gate → Metis (갭 분석) → spec.md
```

### `/olympus:genesis` — 창조

세대별 반복을 통해 명세를 진화시킨다.

```
씨앗 → Metis (경이) → Eris (반추) → 다음 씨앗 → 수렴? (≥ 0.95)
  ↑                                                    ↓ 아니오
  └────────────────────────────────────────────────────┘
```

- 정체 감지: 순환, 진동, 수확 체감
- 완전한 계보 추적과 함께 최대 30세대

### `/olympus:pantheon` — 신들의 회의

여러 직교적 관점에서 문제를 분석한다.

```
Helios (관점) → Ares + Poseidon + Zeus (병렬 분석) → Eris (도전) → 합의
```

- 각각 품질 게이트를 통과하는 3–6개의 직교적 관점
- 논리적 검증을 위한 22개 항목 오류 목록
- 악마의 변호인이 모든 결론에 도전

### `/olympus:tribunal` — 신들의 재판

세 단계 평가: 기계적, 의미적, 합의.

```
1단계: Hephaestus (빌드/테스트/린트)      → 실패 → 차단됨
2단계: Athena (AC 검증)                   → 실패 → 불완전
3단계: Ares + Eris + Hera (합의)          → 승인 / 거부
```

### `/olympus:agora` — 광장

기술적 결정을 위한 구조화된 위원회 토론.

```
프레이밍 → 위원회 (3개 역할) → 토론 (≤ 3라운드) → Eris (도전) → 결정
```

### `/olympus:odyssey` — 대여정

요구사항부터 판결까지 전체 파이프라인 조율.

```
Oracle → Genesis → Pantheon → Zeus + Themis → Prometheus → Tribunal
 스펙     진화      분석       계획 + 검토     구현          판결
```

- Tribunal 거부 시 최대 3회 재시도, 이후 Genesis로 되감기
- `odyssey-state.json`을 통한 완전한 상태 영속성

### `/olympus:setup` — 설치 검증

플러그인 설치를 검증하고 환경을 체크한다.

```
에이전트 파일 검증 → 훅 설정 확인 → 스킬 등록 확인 → 결과 리포트
```

### `/olympus:hestia` — 프로젝트 온보딩

프로젝트를 스캔하고 적합한 파이프라인을 추천한다.

```
프로젝트 스캔 → 기술 스택 파악 → 복잡도 분석 → 스킬 추천
```

### `/olympus:review-pr` — 네메시스의 재판

다관점 PR 리뷰 + 적대적 검증 + 신뢰도 보정 판결.

```
Hermes (정찰) → Helios (관점) → Ares + Poseidon + 동적 (병렬 리뷰)
  → Eris (도전) → Nemesis (합성) → 판결 + GitHub 리뷰 코멘트
```

**인터랙티브 모드** — 특정 PR, 브랜치, 커밋 범위를 리뷰:

```
/olympus:review-pr 123              # PR 번호
/olympus:review-pr feature/auth     # 브랜치명
/olympus:review-pr                  # 현재 브랜치 vs main
```

**자동 모드** — 미리뷰 PR을 자동으로 찾아 리뷰:

```
/olympus:review-pr --auto --repo myorg/myrepo --base main
```

`/loop` 또는 `/schedule`과 결합하면 지속적 리뷰 가능:

```
/loop 5m /olympus:review-pr --auto --repo myorg/myrepo --base main
/schedule create --cron "*/15 * * * *" --prompt "/olympus:review-pr --auto --repo myorg/myrepo"
```

- PR에 "리뷰 시작" 코멘트를 남기고, 완료 시 판결로 업데이트
- `--spec` 플래그로 도메인 인식 리뷰 (인수 기준 대비 검증)
- 심각도·신뢰도 점수가 포함된 GitHub 인라인 리뷰 코멘트

### `/olympus:audit` — 자기 검사

플러그인 자체의 내부 일관성을 검증한다.

```
Hephaestus (구조적) → Athena (의미적) → audit-report.md
```

### `/olympus:evolve` — 자기 진화

벤치마킹과 행동 평가를 통해 Olympus 자체를 개선한다.

```
벤치마크 → 자체 실험 → 평가 (5개 차원) → 진단 → 정제 → 감사 → 반복
```

- 5개 평가 차원: Specificity, Evidence Density, Role Adherence, Efficiency, Actionability
- 전체 점수 ≥ 0.8에서 수렴, 최대 5회 반복

---

## 열네 명의 신

| 에이전트 | 역할 | 모델 | 권한 |
|:---------|:-----|:----:|:-----|
| **Zeus** | 플래너 — 전략 및 작업 분해 | opus | 전체 |
| **Athena** | 의미적 평가자 — AC 준수 검증 | opus | 읽기 전용 |
| **Apollo** | 인터뷰어 — 소크라테스식 질문 | opus | 읽기 전용 |
| **Hermes** | 탐색자 — 코드베이스 정찰 | haiku | 읽기 전용 |
| **Ares** | 코드 검토자 — 결함 및 안티패턴 | opus | 읽기 전용 |
| **Hera** | 검증자 — 테스트 실행 및 품질 게이트 | sonnet | 쓰기 |
| **Poseidon** | 보안 검토자 — OWASP Top 10 | opus | 읽기 전용 |
| **Prometheus** | 실행자 — 코드 구현 | sonnet | 전체 |
| **Artemis** | 디버거 — 근본 원인 분석 | sonnet | 전체 |
| **Metis** | 분석가 — 갭 분석 및 가정 검증 | opus | 읽기 전용 |
| **Themis** | 비평가 — 독립적 계획/결과 검토 | opus | 읽기 전용 |
| **Hephaestus** | 기계적 평가자 — 빌드, 린트, 테스트, 타입 검사 | sonnet | 전체 |
| **Eris** | 악마의 변호인 — 오류 감지 및 도전 | opus | 읽기 전용 |
| **Helios** | 관점 생성자 — 직교적 시각 | opus | 읽기 전용 |

### 위임 패턴

14명 중 9명의 에이전트가 **읽기 전용**이다. 파일을 쓸 수 없다. 대신:

```
읽기 전용 에이전트 → SendMessage(결과) → 오케스트레이터 → Write(파일)
```

이것은 제한이 아니다 — 이것은 **보안 경계**다. 입증된 필요가 있는 에이전트만 쓰기 권한을 얻는다.

---

<details>
<summary><strong>공유 프로토콜</strong></summary>

| 프로토콜 | 목적 |
|:---------|:-----|
| `ambiguity-scoring.md` | 정량적 요구사항 명확성 (0.0–1.0, 게이트 ≤ 0.2) |
| `artifact-contracts.md` | 누가 무엇을 쓰고, 누가 무엇을 읽으며, 어느 단계에서 |
| `clarity-enforcement.md` | 금지된 표현 + 증거 요구사항 |
| `consensus-levels.md` | 강한 / 실무적 / 부분적 / 합의 없음 정의 |
| `fallacy-catalog.md` | 적대적 검증을 위한 22개 논리적 오류 |
| `source-scope-mapping.md` | MCP 데이터 소스 발견 및 분석 소스 풀 |
| `perspective-quality-gate.md` | 4개 기준: 직교성, 증거, 도메인, 실행 가능성 |
| `team-teardown.md` | 우아한 에이전트 종료 프로토콜 |
| `worker-preamble.md` | 표준 워커 에이전트 생명주기 |

</details>

<details>
<summary><strong>아티팩트 구조</strong></summary>

모든 아티팩트는 `.olympus/{id}/` 아래에 `{skill}-{YYYYMMDD}-{short-uuid}` ID 형식으로 저장된다.

```
.olympus/
  oracle-20260305-a3f8b2c1/
    codebase-context.md       # Hermes 탐색 결과
    interview-log.md          # Apollo Q&A 세션
    ambiguity-scores.json     # 정량화된 명확성 점수
    gap-analysis.md           # Metis 갭 분석
    spec.md                   # 최종 명세

  pantheon-20260305-7d2e9f04/
    perspectives.md           # Helios 관점
    analyst-findings.md       # 다관점 분석
    da-evaluation.md          # Eris 도전
    analysis.md               # 통합 결과

  tribunal-20260305-b1c4d5e6/
    mechanical-result.json    # 빌드/테스트/린트 결과
    semantic-matrix.md        # AC 검증 매트릭스
    verdict.md                # 최종 판결
```

</details>

---

## 기여하기

기여를 환영합니다! [CONTRIBUTING.md](../../CONTRIBUTING.md)에서 가이드를 확인하세요.

```bash
# 제출 전 테스트 실행
bash hooks/test-hooks.sh
bash hooks/test-integration.sh
```

## 라이선스

[MIT](../../LICENSE) &copy; hjyoon

---

<p align="center">
  <em>"검토되지 않은 코드는 출시할 가치가 없다."</em>
  <br/><br/>
  <strong>신들은 동의하지 않는다. 그것이 핵심이다.</strong>
</p>
