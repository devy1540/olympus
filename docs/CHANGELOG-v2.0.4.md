# Olympus v2.0.4

Released: 2026-04-05

## Changes

- 하네스 패턴 회귀 테스트 7건 추가 (142/142)
- 나머지 4개 에이전트 Teammate_Protocol 강화
- 프로덕션 강화: 소스 빌드 fallback + ~ 확장
- MCP 서버: ~ 홈 디렉토리 확장 + pluginRoot fallback 수정
- 프로액티브 스폰 + 필수 협의 프로토콜 전면 도입
- test-all.sh에 deploy 테스트 추가 (135건)
- test-all.sh run_check에 서브셸 적용 (cd 디렉토리 격리)
- Go 유닛 테스트 추가 + MCP 서버 에러 핸들링 강화
- 에이전트 간 크로스레퍼런스 + read-only 경고 43건 추가
- plugin.json/marketplace 14→15 동기화 + SQLite PRAGMA synchronous=NORMAL
- 문서 에이전트/스킬 수 14→15, 9→10, 10→11 갱신
- 팀메이트 응답 재시도 규칙 + WAL 레이스 + 아티팩트 계약 수정
- artifact-contracts.json에 odyssey implementation-report.md 추가
- E2E 테스트에 실제 SKILL.md 흐름 시뮬레이션 추가 + 전환 로더 수정
- read-only 에이전트에 파일 쓰기 지시 제거
- init 페이즈 전환 버그 수정
- setup SKILL.md에서 외부 참조 문구 제거
- 배포/설치 시나리오 테스트 추가 (12건)
- ensure-mcp에 과거 플러그인 캐시 자동 정리 추가
- setup 스킬 경로를 CLAUDE_SKILL_DIR 기반 절대경로로 수정
