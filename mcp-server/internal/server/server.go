package server

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/devy1540/olympus/mcp-server/internal/config"
	"github.com/devy1540/olympus/mcp-server/internal/gate"
	"github.com/devy1540/olympus/mcp-server/internal/history"
	"github.com/devy1540/olympus/mcp-server/internal/store"
	mcpgo "github.com/mark3labs/mcp-go/mcp"
	mcpserver "github.com/mark3labs/mcp-go/server"
)

func NewServer(st *store.Store, cfg *config.Config) *mcpserver.MCPServer {
	calc := gate.NewCalculator(cfg.Thresholds)

	s := mcpserver.NewMCPServer(
		"olympus-pipeline",
		"1.0.0",
		mcpserver.WithToolCapabilities(true),
	)

	// --- Pipeline management ---

	s.AddTool(
		mcpgo.NewTool("olympus_start_pipeline",
			mcpgo.WithDescription("파이프라인을 시작하고 필수 에이전트 목록을 반환합니다"),
			mcpgo.WithString("skill", mcpgo.Required(), mcpgo.Description("스킬 이름 (odyssey, oracle, etc.)")),
			mcpgo.WithString("pipeline_id", mcpgo.Required(), mcpgo.Description("파이프라인 ID")),
		),
		startPipelineHandler(st, cfg),
	)

	s.AddTool(
		mcpgo.NewTool("olympus_next_phase",
			mcpgo.WithDescription("다음 유효 페이즈를 반환합니다. 스킵 불가."),
			mcpgo.WithString("pipeline_id", mcpgo.Required(), mcpgo.Description("파이프라인 ID")),
		),
		nextPhaseHandler(st, cfg),
	)

	s.AddTool(
		mcpgo.NewTool("olympus_register_agent_spawn",
			mcpgo.WithDescription("에이전트 스폰을 기록합니다"),
			mcpgo.WithString("pipeline_id", mcpgo.Required(), mcpgo.Description("파이프라인 ID")),
			mcpgo.WithString("agent_name", mcpgo.Required(), mcpgo.Description("에이전트 이름")),
		),
		registerSpawnHandler(st),
	)

	s.AddTool(
		mcpgo.NewTool("olympus_pipeline_status",
			mcpgo.WithDescription("파이프라인 상태를 반환합니다"),
			mcpgo.WithString("pipeline_id", mcpgo.Required(), mcpgo.Description("파이프라인 ID")),
		),
		pipelineStatusHandler(st),
	)

	// --- Gate scoring ---

	s.AddTool(
		mcpgo.NewTool("olympus_calculate_ambiguity",
			mcpgo.WithDescription("인터뷰 로그를 기계적으로 분석하여 모호성 점수를 산정합니다"),
			mcpgo.WithString("pipeline_id", mcpgo.Required(), mcpgo.Description("파이프라인 ID")),
			mcpgo.WithString("interview_log_path", mcpgo.Required(), mcpgo.Description("interview-log.md 파일 경로")),
		),
		calculateAmbiguityHandler(st, calc),
	)

	s.AddTool(
		mcpgo.NewTool("olympus_gate_check",
			mcpgo.WithDescription("게이트 판정을 수행합니다 (스폰 검증 포함)"),
			mcpgo.WithString("pipeline_id", mcpgo.Required(), mcpgo.Description("파이프라인 ID")),
			mcpgo.WithString("gate_type", mcpgo.Required(), mcpgo.Description("게이트 유형 (ambiguity, convergence, consensus, semantic)")),
			mcpgo.WithNumber("score", mcpgo.Required(), mcpgo.Description("게이트 점수")),
		),
		gateCheckHandler(st, cfg, calc),
	)

	// --- Execution history ---

	s.AddTool(
		mcpgo.NewTool("olympus_record_execution",
			mcpgo.WithDescription("에이전트 실행 기록을 저장합니다"),
			mcpgo.WithString("pipeline_id", mcpgo.Required(), mcpgo.Description("파이프라인 ID")),
			mcpgo.WithString("phase", mcpgo.Required(), mcpgo.Description("실행 페이즈")),
			mcpgo.WithString("agent_name", mcpgo.Required(), mcpgo.Description("에이전트 이름")),
			mcpgo.WithNumber("duration_ms", mcpgo.Description("실행 시간(ms)")),
			mcpgo.WithNumber("token_count", mcpgo.Description("토큰 수")),
		),
		recordExecutionHandler(st),
	)

	s.AddTool(
		mcpgo.NewTool("olympus_validate_plan",
			mcpgo.WithDescription("과거 데이터 기반으로 계획의 현실성을 검증합니다"),
			mcpgo.WithString("pipeline_id", mcpgo.Required(), mcpgo.Description("파이프라인 ID")),
			mcpgo.WithString("skill", mcpgo.Required(), mcpgo.Description("스킬 이름")),
			mcpgo.WithString("phase", mcpgo.Required(), mcpgo.Description("페이즈")),
			mcpgo.WithString("agent", mcpgo.Required(), mcpgo.Description("에이전트 이름")),
			mcpgo.WithNumber("estimated_calls", mcpgo.Description("예상 호출 횟수")),
		),
		validatePlanHandler(st),
	)

	// --- Teammate support ---

	s.AddTool(
		mcpgo.NewTool("olympus_next_action",
			mcpgo.WithDescription("현재 파이프라인 상태 기반으로 다음 행동을 반환합니다. 리더 또는 팀메이트가 호출."),
			mcpgo.WithString("pipeline_id", mcpgo.Required(), mcpgo.Description("파이프라인 ID")),
			mcpgo.WithString("agent", mcpgo.Description("호출하는 에이전트 이름 (생략 시 리더 관점)")),
		),
		nextActionHandler(st, cfg),
	)

	s.AddTool(
		mcpgo.NewTool("olympus_log_collaboration",
			mcpgo.WithDescription("팀메이트 간 소통을 기록합니다"),
			mcpgo.WithString("pipeline_id", mcpgo.Required(), mcpgo.Description("파이프라인 ID")),
			mcpgo.WithString("from", mcpgo.Required(), mcpgo.Description("발신 에이전트")),
			mcpgo.WithString("to", mcpgo.Required(), mcpgo.Description("수신 에이전트")),
			mcpgo.WithString("summary", mcpgo.Required(), mcpgo.Description("소통 요약")),
		),
		logCollaborationHandler(st),
	)

	return s
}

// --- Handlers ---

func startPipelineHandler(st *store.Store, cfg *config.Config) mcpserver.ToolHandlerFunc {
	return func(ctx context.Context, req mcpgo.CallToolRequest) (*mcpgo.CallToolResult, error) {
		skill, err := req.RequireString("skill")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}
		pipelineID, err := req.RequireString("pipeline_id")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}

		if err := st.CreatePipeline(pipelineID, skill); err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("파이프라인 생성 실패: %v", err)), nil
		}

		// Advance from "init" to first phase immediately
		firstPhase := "oracle"
		if err := st.UpdatePhase(pipelineID, firstPhase, cfg.Transitions.Transitions); err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("초기 페이즈 전환 실패: %v", err)), nil
		}

		required := cfg.RequiredAgents(skill, "")
		return toResult(map[string]any{
			"pipeline_id":     pipelineID,
			"skill":           skill,
			"required_agents": required,
			"first_phase":     firstPhase,
		})
	}
}

func nextPhaseHandler(st *store.Store, cfg *config.Config) mcpserver.ToolHandlerFunc {
	return func(ctx context.Context, req mcpgo.CallToolRequest) (*mcpgo.CallToolResult, error) {
		pipelineID, err := req.RequireString("pipeline_id")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}

		next, alternatives, err := st.NextPhase(pipelineID, cfg.Transitions.Transitions)
		if err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("다음 페이즈 조회 실패: %v", err)), nil
		}

		// Check spawn requirements before advancing
		p, _ := st.GetPipeline(pipelineID)
		spawnReport, _ := gate.CheckRequiredSpawns(st, cfg, pipelineID, p.Skill)

		result := map[string]any{
			"next_phase":   next,
			"alternatives": alternatives,
		}
		if spawnReport != nil && !spawnReport.AllSpawned {
			result["spawn_warning"] = fmt.Sprintf("미스폰 에이전트: %v", spawnReport.Missing)
			result["missing_spawns"] = spawnReport.Missing
		}

		return toResult(result)
	}
}

func registerSpawnHandler(st *store.Store) mcpserver.ToolHandlerFunc {
	return func(ctx context.Context, req mcpgo.CallToolRequest) (*mcpgo.CallToolResult, error) {
		pipelineID, err := req.RequireString("pipeline_id")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}
		agentName, err := req.RequireString("agent_name")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}

		p, err := st.GetPipeline(pipelineID)
		if err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("파이프라인 미발견: %v", err)), nil
		}

		if err := st.RegisterSpawn(pipelineID, agentName, p.Phase); err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("스폰 기록 실패: %v", err)), nil
		}

		return toResult(map[string]any{
			"registered": true,
			"agent":      agentName,
			"phase":      p.Phase,
		})
	}
}

func pipelineStatusHandler(st *store.Store) mcpserver.ToolHandlerFunc {
	return func(ctx context.Context, req mcpgo.CallToolRequest) (*mcpgo.CallToolResult, error) {
		pipelineID, err := req.RequireString("pipeline_id")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}

		p, err := st.GetPipeline(pipelineID)
		if err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("파이프라인 미발견: %v", err)), nil
		}

		spawns, _ := st.ListSpawns(pipelineID)
		spawnNames := make([]string, len(spawns))
		for i, s := range spawns {
			spawnNames[i] = s.AgentName
		}

		return toResult(map[string]any{
			"id":             p.ID,
			"skill":          p.Skill,
			"phase":          p.Phase,
			"status":         p.Status,
			"spawned_agents": spawnNames,
		})
	}
}

func calculateAmbiguityHandler(st *store.Store, calc *gate.Calculator) mcpserver.ToolHandlerFunc {
	return func(ctx context.Context, req mcpgo.CallToolRequest) (*mcpgo.CallToolResult, error) {
		pipelineID, err := req.RequireString("pipeline_id")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}
		logPath, err := req.RequireString("interview_log_path")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}

		result, err := gate.CalculateAmbiguity(logPath)
		if err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("모호성 계산 실패: %v", err)), nil
		}

		gateResult := calc.Check("ambiguity", result.MechanicalScore)
		if err := st.RecordGateScore(pipelineID, "ambiguity", result.MechanicalScore, gateResult.Passed, ""); err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("게이트 점수 기록 실패: %v", err)), nil
		}

		return toResult(map[string]any{
			"mechanical_score": result.MechanicalScore,
			"dimensions":      result.Dimensions,
			"indicators":      result.Indicators,
			"gate_passed":     gateResult.Passed,
			"threshold":       gateResult.Threshold,
		})
	}
}

func gateCheckHandler(st *store.Store, cfg *config.Config, calc *gate.Calculator) mcpserver.ToolHandlerFunc {
	return func(ctx context.Context, req mcpgo.CallToolRequest) (*mcpgo.CallToolResult, error) {
		pipelineID, err := req.RequireString("pipeline_id")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}
		gateType, err := req.RequireString("gate_type")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}
		score, err := req.RequireFloat("score")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}

		gateResult := calc.Check(gateType, score)
		if err := st.RecordGateScore(pipelineID, gateType, score, gateResult.Passed, ""); err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("게이트 점수 기록 실패: %v", err)), nil
		}

		p, _ := st.GetPipeline(pipelineID)
		spawnReport, _ := gate.CheckRequiredSpawns(st, cfg, pipelineID, p.Skill)

		result := map[string]any{
			"passed":    gateResult.Passed,
			"score":     score,
			"threshold": gateResult.Threshold,
			"operator":  gateResult.Operator,
		}
		if gateResult.Message != "" {
			result["message"] = gateResult.Message
		}
		if spawnReport != nil && !spawnReport.AllSpawned {
			result["spawn_check"] = false
			result["missing_spawns"] = spawnReport.Missing
		}

		return toResult(result)
	}
}

func recordExecutionHandler(st *store.Store) mcpserver.ToolHandlerFunc {
	return func(ctx context.Context, req mcpgo.CallToolRequest) (*mcpgo.CallToolResult, error) {
		pipelineID, err := req.RequireString("pipeline_id")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}
		phase, err := req.RequireString("phase")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}
		agent, err := req.RequireString("agent_name")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}

		durationMS := int64(req.GetFloat("duration_ms", 0))
		tokenCount := int64(req.GetFloat("token_count", 0))

		if err := st.RecordExecution(pipelineID, phase, agent, durationMS, tokenCount, 0, 0, true, ""); err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("기록 실패: %v", err)), nil
		}

		return toResult(map[string]any{"recorded": true})
	}
}

func validatePlanHandler(st *store.Store) mcpserver.ToolHandlerFunc {
	return func(ctx context.Context, req mcpgo.CallToolRequest) (*mcpgo.CallToolResult, error) {
		skill, err := req.RequireString("skill")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}
		phase, err := req.RequireString("phase")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}
		agent, err := req.RequireString("agent")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}

		estimatedCalls := req.GetInt("estimated_calls", 0)

		result, err := history.ValidatePlan(st, skill, phase, agent, estimatedCalls)
		if err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("검증 실패: %v", err)), nil
		}

		return toResult(result)
	}
}

func nextActionHandler(st *store.Store, cfg *config.Config) mcpserver.ToolHandlerFunc {
	return func(ctx context.Context, req mcpgo.CallToolRequest) (*mcpgo.CallToolResult, error) {
		pipelineID, err := req.RequireString("pipeline_id")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}

		p, err := st.GetPipeline(pipelineID)
		if err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("파이프라인 미발견: %v", err)), nil
		}

		spawns, _ := st.ListSpawns(pipelineID)
		spawnSet := make(map[string]bool)
		for _, s := range spawns {
			spawnSet[s.AgentName] = true
		}

		required := cfg.RequiredAgents(p.Skill, p.Phase)

		// Check for missing spawns
		var missing []string
		for _, r := range required {
			if !spawnSet[r] {
				missing = append(missing, r)
			}
		}

		// Determine agent-specific or leader action
		agentName := req.GetString("agent", "")

		if agentName != "" {
			// Agent-specific: what should this agent do?
			collabs, _ := st.ListCollaborations(pipelineID)
			var collaborators []string
			for _, c := range collabs {
				if c.FromAgent == agentName || c.ToAgent == agentName {
					peer := c.ToAgent
					if peer == agentName {
						peer = c.FromAgent
					}
					collaborators = append(collaborators, peer)
				}
			}

			return toResult(map[string]any{
				"agent":         agentName,
				"pipeline_id":   pipelineID,
				"current_phase": p.Phase,
				"status":        p.Status,
				"action":        "check_with_leader",
				"hint":          fmt.Sprintf("Agent %s is in phase %s. Report status to leader via SendMessage.", agentName, p.Phase),
				"collaborators": collaborators,
			})
		}

		// Leader perspective: overall next action
		if len(missing) > 0 {
			return toResult(map[string]any{
				"action":         "spawn_agent",
				"agent":          missing[0],
				"all_missing":    missing,
				"reason":         "필수 에이전트 미스폰",
				"current_phase":  p.Phase,
				"spawned_agents": spawnSet,
			})
		}

		// Check latest gate
		latestGate, _ := st.GetLatestGateScoreAny(pipelineID)
		if latestGate != nil && !latestGate.Passed {
			return toResult(map[string]any{
				"action":        "retry_phase",
				"reason":        fmt.Sprintf("게이트 실패: %s (%.2f)", latestGate.GateType, latestGate.Score),
				"current_phase": p.Phase,
				"gate":          latestGate.GateType,
				"score":         latestGate.Score,
			})
		}

		// All good — advance
		nextPhases := cfg.ValidTransitions(p.Phase)
		action := "advance_phase"
		if len(nextPhases) == 0 {
			action = "pipeline_complete"
		}

		return toResult(map[string]any{
			"action":        action,
			"current_phase": p.Phase,
			"next_phases":   nextPhases,
			"all_spawned":   true,
		})
	}
}

func logCollaborationHandler(st *store.Store) mcpserver.ToolHandlerFunc {
	return func(ctx context.Context, req mcpgo.CallToolRequest) (*mcpgo.CallToolResult, error) {
		pipelineID, err := req.RequireString("pipeline_id")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}
		from, err := req.RequireString("from")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}
		to, err := req.RequireString("to")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}
		summary, err := req.RequireString("summary")
		if err != nil {
			return mcpgo.NewToolResultError(err.Error()), nil
		}

		p, err := st.GetPipeline(pipelineID)
		if err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("파이프라인 미발견: %v", err)), nil
		}

		if err := st.LogCollaboration(pipelineID, from, to, p.Phase, summary); err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("기록 실패: %v", err)), nil
		}

		return toResult(map[string]any{
			"logged": true,
			"from":   from,
			"to":     to,
			"phase":  p.Phase,
		})
	}
}

func toResult(v any) (*mcpgo.CallToolResult, error) {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return mcpgo.NewToolResultError(fmt.Sprintf("JSON 변환 실패: %v", err)), nil
	}
	return mcpgo.NewToolResultText(string(data)), nil
}
