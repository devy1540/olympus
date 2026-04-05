# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Olympus는 Claude Code 하네스 엔지니어링 플러그인. 15개 전문 에이전트(그리스 신)가 요구사항 정제, 다관점 분석, 구현, 평가를 구조적 적대적 협업과 수학적 게이트로 수행한다.

**Node.js/npm 프로젝트가 아님** — 순수 Claude Code 플러그인 (Markdown 에이전트 + shell hook + skill 오케스트레이션).

## Commands

```bash
# 설치
claude plugin marketplace add devy1540/olympus
claude plugin install olympus@olympus-marketplace

# 스킬 (Claude Code 내에서 호출)
/olympus:oracle      # 요구사항 정제 → spec.md
/olympus:genesis     # 스펙 진화 (세대 반복)
/olympus:pantheon    # 다관점 분석
/olympus:tribunal    # 3단계 평가 (기계적 → 의미적 → 합의)
/olympus:odyssey     # 전체 파이프라인
/olympus:agora       # 구조적 위원회 토론
/olympus:audit       # 플러그인 자가점검
/olympus:evolve      # 플러그인 자가개선
/olympus:setup       # 설치 검증 및 환경 체크
/olympus:hestia      # 프로젝트 온보딩 및 가이드

# 검증/테스트 (hooks/ 디렉토리의 셸 스크립트)
bash hooks/validate-agents.sh    # 에이전트 정의 스키마 검증
bash hooks/validate-gate.sh      # 게이트 임계값 검증
bash hooks/validate-state.sh     # 상태 전이 검증
bash hooks/verify-artifacts.sh   # 아티팩트 계약 검증
bash hooks/test-hooks.sh         # 훅 단위 테스트 (39건)
bash hooks/test-integration.sh   # 파이프라인 통합 테스트 (47건: 9개 파이프라인)
cd mcp-server && go test ./...   # MCP 서버 Go 테스트 (config, gate, store, history)
bash scripts/verify-all.sh       # 전체 검증 원커맨드 (위 3개 + 에이전트 일관성)

# 릴리스
bash scripts/release.sh patch    # 패치 릴리스 (x.x.X)
bash scripts/release.sh minor    # 마이너 릴리스 (x.X.0)
bash scripts/release.sh major    # 메이저 릴리스 (X.0.0)
```

## Architecture

### 파이프라인 & 게이트

```
Oracle → Genesis → Pantheon → Plan → Execute → Tribunal
 (ask)   (evolve)  (analyze)  (design) (build)  (judge)
   ↑                                               ↓
   └──────────── Rejected? Retry or rewind ─────────┘
```

각 단계는 수학적 임계값으로 게이트됨 (`docs/shared/gate-thresholds.json`):
- Ambiguity ≤ 0.2 (Oracle) / Convergence ≥ 0.95 (Genesis) / Consensus ≥ 67% (Pantheon·Tribunal) / Semantic ≥ 0.8 (Tribunal)

### 에이전트 권한 모델

- **Write/Edit 금지 (10)**: Hermes, Apollo, Metis, Ares, Poseidon, Athena, Themis, Eris, Helios, Nemesis — 최종 텍스트 출력으로 결과 반환, 오케스트레이터가 Agent tool 반환값에서 캡처하여 파일 기록. Hermes·Poseidon은 Bash 허용 (디렉토리 탐색·보안 스캔 목적)
- **Write, Edit 금지 (1)**: Hera (테스트 실행·품질 판정, Edit 불가)
- **Full (4)**: Zeus (계획), Prometheus (구현), Artemis (디버깅), Hephaestus (빌드/테스트 실행)

위임 패턴 (`Read-only → SendMessage → Orchestrator → Write`)은 보안 경계. `hooks/enforce-permissions.sh`가 강제.

### 전면 팀메이트 모드 + 유기적 대화

모든 에이전트를 팀메이트(TeamCreate + SendMessage)로 스폰. Proactive spawn + 필수 협의(Mandatory Consultation):

| 특성 | 설명 |
|:-----|:-----|
| 스폰 | Proactive — IMMEDIATE TASK를 스폰 prompt에 포함, "Wait for messages" 금지 (§6.3) |
| 수명 | 스킬 종료까지 유지 (cross-phase context retention) |
| 소통 | 에이전트 간 직접 SendMessage + 필수 협의 라운드 (§7) |
| 핵심 이점 | 에이전트 간 유기적 대화로 품질 향상 — 고립된 분석이 아닌 크로스 검증 |
| 리더 역할 | Phase 전환, 게이트 판정, MCP 상태 관리만 |

**필수 협의 경로**: apollo↔hermes (인터뷰 팩트검증), ares↔poseidon (품질↔보안 크로스레퍼런스), metis↔eris (Genesis 대화), ares↔eris (Tribunal 토론)

SKILL.md는 XML 태그 구조(`<Purpose>`, `<Execution_Policy>`, `<Steps>`, `<Tool_Usage>`)로 작성되어 LLM의 지시 준수율 향상. 각 Step은 MCP tool call을 포함하여 데이터 의존성으로 스킵 불가.

상세: `docs/shared/orchestrator-protocol.md §6-7`

### 에이전트 스폰 필수 규칙

SKILL.md의 Step에서 지정된 에이전트는 **반드시** Agent tool(name + team_name)로 팀메이트 스폰해야 한다. 오케스트레이터가 직접 Grep/Read로 대체 수행하거나 단계를 생략하면 안 된다. 역할 분리가 이 플러그인의 핵심 가치 — "내가 직접 하면 더 빠르다"는 이유로 스킵하면 적대적 검증이 무력화된다. 상세: `docs/shared/orchestrator-protocol.md §0`.

### 핵심 설계 원칙

- 에이전트 정의: `agents/{name}.md` (YAML frontmatter + prompt). 스키마: `docs/shared/agent-schema.json`
- 아티팩트 I/O: `docs/shared/artifact-contracts.json`이 페이즈별 읽기/쓰기 권한 통제
- 상태 머신: `docs/shared/pipeline-states.json` (CC의 query.ts Terminal/Continue 패턴 포팅)
- 훅: `hooks/hooks.json` — Pre-Write(권한·계약·스폰 검증), Post-Write(스키마·게이트·상태 검증 + 체크포인트)
- 스폰 강제: `artifact-contracts.json`의 `required_spawn` 필드 + `enforce-spawn-gate.sh` 훅이 §0 위반 차단 (22건 등록)
- 런타임 안정성: 에이전트 출력 5000자 권장/50000자 한도, 피어 무응답 시 2회 재시도 후 graceful degradation
- 런타임 아티팩트: `.olympus/{skill}-{YYYYMMDD}-{uuid}/` (gitignored, `.checkpoints/`에 자동 백업)

### 컨벤션

- 모든 주장에 `file:line`, 테스트 결과, 메트릭 등 증거 필수 — 모호한 표현 금지 (`docs/shared/clarity-enforcement.md`)
- 22개 논리적 오류 카탈로그로 적대적 검증 (`docs/shared/fallacy-catalog.md`)
- 에이전트명: 소문자, 하이픈 없음, 그리스 신 이름만

## Claude Code 소스 참조

CC 프로덕션 소스(`claude-code-restored`)에서 아키텍처를 광범위하게 차용. 수정/확장 시 원본 패턴의 의도 파악 필요.

### 직접 포팅

| Olympus | CC 원본 |
|---------|--------|
| `hooks/lib/denial-tracking.sh` | `denialTracking.ts:1-46` — 1:1 함수 포팅 |
| `pipeline-states.json` | `query.ts:204-217` — State/Terminal/Continue 타입 |
| `hook-responses.json` | `permissions.ts:174-324` — PermissionDecision 타입 |
| `agent-schema.json` | `Tool.ts:757-792` — TOOL_DEFAULTS + buildTool() |
| `context-management.md` | `autoCompact.ts:71-239` — 토큰 임계값 + 컴팩션 전략 |
| `agent-context.md` | `forkSubagent.ts:344-461` — 서브에이전트 컨텍스트 격리 |
| `orchestrator-protocol.md` | `query.ts` 전체 루프 — 게이트 판정·에러 복구 |

### 에이전트 페르소나 차용

- **Hermes** ← Explore Agent: 읽기 전용 탐색, 파일 수정 금지
- **Athena** ← Verification Agent: "구현을 깨뜨리는 것이 임무" 검증 마인드셋
- **Zeus** ← Plan Agent: "Critical Files for Implementation" 필수 출력
