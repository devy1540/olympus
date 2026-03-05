# Olympus (올림푸스) ⚡

**하네스 엔지니어링 플러그인** — 14명의 신(에이전트)이 요구사항 정제부터 평가까지 소프트웨어 개발 전체 수명주기를 수행합니다.

Claude Code 플러그인으로 동작하며, 에이전트 간 역할 분리, 증거 기반 분석, 다층 품질 게이트를 통해 체계적인 소프트웨어 엔지니어링을 보장합니다.

## 핵심 원칙

- **자기 리뷰 방지**: 계획하는 자(Zeus)와 비평하는 자(Themis)를 분리하여 맹점을 구조적으로 차단
- **증거 기반**: 모든 주장에 `file:line` 참조 의무, 금지 표현("it depends", "might" 등) 차단
- **다층 게이트**: 모호성 → 수렴 → 합의 → 기계 검증 → 의미 평가의 단계별 품질 관문
- **권한 최소화**: 14개 에이전트 중 9개가 read-only, 코드 수정은 Prometheus만 수행

## 아키텍처

```
                         Odyssey (전체 파이프라인)
    ┌──────────┬──────────┬──────────┬──────────┬──────────┐
    │  Oracle  │ Genesis  │ Pantheon │ Plan+Exec│ Tribunal │
    │  (정제)   │  (진화)   │  (분석)   │  (구현)   │  (평가)   │
    └──────────┴──────────┴──────────┴──────────┴──────────┘
                    Agora (토론)  │  Audit (감사)
    ┌──────────────────────────────────────────────────────┐
    │                    14 Agents                         │
    │  Hermes → Apollo → Metis → Helios → Zeus → Themis   │
    │  Prometheus → Hephaestus → Athena → Ares/Poseidon   │
    │  Artemis → Eris → Hera                              │
    ├──────────────────────────────────────────────────────┤
    │              Shared Protocols (docs/)                │
    └──────────────────────────────────────────────────────┘
```

## 에이전트 (14명)

| 에이전트 | 역할 | 모델 | 권한 |
|---|---|---|---|
| **Zeus** (제우스) | Planner — 전략 설계와 작업 분해 | opus | 전체 |
| **Athena** (아테나) | Semantic Evaluator — AC 준수 검증 | opus | read-only |
| **Apollo** (아폴론) | Interviewer — 소크라테스식 질문으로 모호성 제거 | opus | read-only |
| **Hermes** (헤르메스) | Explorer — 코드베이스 탐색 및 컨텍스트 수집 | haiku | read-only |
| **Ares** (아레스) | Code Reviewer — 결함, 안티패턴, 품질 평가 | opus | read-only |
| **Hera** (헤라) | Verifier — 테스트 실행 및 최종 품질 게이트 | sonnet | Write |
| **Poseidon** (포세이돈) | Security Reviewer — OWASP Top 10 취약점 탐지 | opus | read-only |
| **Prometheus** (프로메테우스) | Executor — 계획에 따른 코드 구현 | sonnet | 전체 |
| **Artemis** (아르테미스) | Debugger — 버그 추적 및 근본 원인 분석 | sonnet | 전체 |
| **Metis** (메티스) | Analyst — 갭 분석, AC 도출, 가정 검증 | opus | read-only |
| **Themis** (테미스) | Critic — 계획/산출물 독립 검증 | opus | read-only |
| **Hephaestus** (헤파이스토스) | Mechanical Evaluator — 빌드/린트/테스트/타입체크 | sonnet | 전체 |
| **Eris** (에리스) | Devil's Advocate — 논리 오류 탐지 및 주장 챌린지 | opus | read-only |
| **Helios** (헬리오스) | Perspective Generator — 직교 관점 도출 | opus | read-only |

## 스킬 (7개)

### `/olympus:oracle` — 델포이의 신탁

요구사항을 체계적으로 정제하여 구조화된 `spec.md`를 생성합니다.

```
Hermes(탐색) → Apollo(인터뷰) → 모호성 게이트(≤0.2) → Metis(갭 분석) → spec.md
```

### `/olympus:genesis` — 창세

명세를 세대별로 진화시키는 Ouroboros 패턴의 진화 루프입니다.

```
Seed → Metis(Wonder) → Eris(Reflect) → Seed → 수렴 검사(≥0.95)
                ↑                                       ↓ NO
                └───────────────────────────────────────┘
```

- 정체 감지 (Spinning/Oscillation/Diminishing) 시 측면 사고 페르소나 활성화
- 최대 30세대, 리니지 관리로 세대별 되감기 지원

### `/olympus:pantheon` — 만신전의 회의

다중 관점에서 문제를 분석하고 Devil's Advocate를 통해 논리적 건전성을 검증합니다.

```
OSM(데이터 소스) → Helios(관점 생성) → 병렬 분석(Ares/Poseidon/Zeus) → Eris(챌린지) → 합의
```

- 3-6개 직교 관점 생성 (Perspective Quality Gate 적용)
- 22개 논리 오류 카탈로그 기반 검증
- Normal: Working 합의(≥67%) / Hell mode: 만장일치

### `/olympus:tribunal` — 신들의 재판

3단계 평가 파이프라인으로 구현을 검증합니다.

```
Stage 1: Hephaestus(빌드/테스트) → FAIL → BLOCKED
                                 → PASS
Stage 2: Athena(AC 검증)         → FAIL → INCOMPLETE
                                 → PASS
Stage 3: Ares+Eris+Hera(합의)   → APPROVED / REJECTED
```

### `/olympus:agora` — 토론의 광장

구조화된 위원회 토론을 통해 기술적 의사결정을 내립니다.

```
프레이밍 → 위원회(UX/Engineering/Planner) → 토론(최대 3라운드) → Eris 챌린지 → 권고안
```

### `/olympus:odyssey` — 대장정

Oracle부터 Tribunal까지 전체 파이프라인을 순서대로 실행합니다.

```
Oracle → Genesis(선택) → Pantheon → Zeus+Themis → Prometheus → Tribunal
  spec.md   진화 spec     analysis.md   plan.md      구현        verdict.md
```

- Tribunal REJECTED 시 최대 3회 재시도 후 Genesis로 되감기
- 전 구간 상태 관리 (`odyssey-state.json`)

### `/olympus:audit` — 올림푸스 감사

플러그인 자체의 내부 정합성을 자동 검증합니다.

```
Hephaestus(구조 검증) → Athena(의미 검증) → audit-report.md
```

- 권한-역할 정합성, 아티팩트 계약 완전성, 게이트 임계값 일관성, 명확성 규칙, 위임 패턴 검증

## 공유 프로토콜 (docs/shared/)

| 문서 | 역할 |
|---|---|
| `ambiguity-scoring.md` | 요구사항 모호성 정량 평가 (0.0~1.0, 게이트 ≤ 0.2) |
| `artifact-contracts.md` | 스킬별 산출물의 작성자/독자/Phase 정의 |
| `artifact-contracts.json` | 기계 검증용 구조화 계약 |
| `clarity-enforcement.md` | 금지 표현 목록 + 증거 요구 수준 (CRITICAL/WARNING/INFO) |
| `consensus-levels.md` | 합의 수준 정의 (Strong/Working/Partial/No) |
| `fallacy-catalog.md` | 22개 논리 오류 카탈로그 (Eris, Athena 사용) |
| `ontology-scope-mapping.md` | MCP 데이터 소스 발견 및 온톨로지 풀 구성 |
| `perspective-quality-gate.md` | 관점 품질 4대 기준 (Orthogonality/Evidence/Domain/Actionable) |
| `team-teardown.md` | 팀 정리 프로토콜 (graceful shutdown + force close) |
| `worker-preamble.md` | 워커 에이전트 표준 생명주기 |

## 산출물 구조

모든 산출물은 `.olympus/{id}/` 하위에 저장됩니다.

```
.olympus/
  oracle-20260305-a3f8b2c1/
    codebase-context.md
    interview-log.md
    ambiguity-scores.json
    gap-analysis.md
    spec.md
  pantheon-20260305-7d2e9f04/
    perspectives.md
    analyst-findings.md
    da-evaluation.md
    analysis.md
  tribunal-20260305-b1c4d5e6/
    mechanical-result.json
    semantic-matrix.md
    verdict.md
```

ID 형식: `{skill}-{YYYYMMDD}-{short-uuid}`

## 위임 패턴

Read-only 에이전트(Write/Edit 비활성화)는 파일을 직접 저장하지 않습니다:

```
Read-only Agent → SendMessage(결과) → Orchestrator → Write(파일 저장)
```

해당 에이전트: Apollo, Metis, Helios, Eris, Athena, Ares, Poseidon, Themis

## 설치

Claude Code 플러그인으로 설치합니다.

```bash
# 플러그인 디렉토리에 클론
git clone <repository-url> ~/.claude/plugins/olympus

# 또는 심볼릭 링크
ln -s /path/to/olympus ~/.claude/plugins/olympus
```

## 사용

```bash
# 요구사항 정제
/olympus:oracle

# 다관점 분석
/olympus:pantheon

# 전체 파이프라인
/olympus:odyssey

# 기술적 의사결정 토론
/olympus:agora

# 플러그인 정합성 감사
/olympus:audit
```

## 라이선스

Private
