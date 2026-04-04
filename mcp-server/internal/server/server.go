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

	return s
}

// --- Handlers ---

func startPipelineHandler(st *store.Store, cfg *config.Config) mcpserver.ToolHandlerFunc {
	return func(ctx context.Context, req mcpgo.CallToolRequest) (*mcpgo.CallToolResult, error) {
		skill := req.GetArguments()["skill"].(string)
		pipelineID := req.GetArguments()["pipeline_id"].(string)

		if err := st.CreatePipeline(pipelineID, skill); err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("파이프라인 생성 실패: %v", err)), nil
		}

		required := cfg.RequiredAgents(skill, "")
		return toResult(map[string]interface{}{
			"pipeline_id":     pipelineID,
			"skill":           skill,
			"required_agents": required,
			"first_phase":     "oracle",
		})
	}
}

func nextPhaseHandler(st *store.Store, cfg *config.Config) mcpserver.ToolHandlerFunc {
	return func(ctx context.Context, req mcpgo.CallToolRequest) (*mcpgo.CallToolResult, error) {
		pipelineID := req.GetArguments()["pipeline_id"].(string)

		next, alternatives, err := st.NextPhase(pipelineID, cfg.Transitions.Transitions)
		if err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("다음 페이즈 조회 실패: %v", err)), nil
		}

		// Check spawn requirements before advancing
		p, _ := st.GetPipeline(pipelineID)
		spawnReport, _ := gate.CheckRequiredSpawns(st, cfg, pipelineID, p.Skill)

		result := map[string]interface{}{
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
		pipelineID := req.GetArguments()["pipeline_id"].(string)
		agentName := req.GetArguments()["agent_name"].(string)

		p, err := st.GetPipeline(pipelineID)
		if err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("파이프라인 미발견: %v", err)), nil
		}

		if err := st.RegisterSpawn(pipelineID, agentName, p.Phase); err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("스폰 기록 실패: %v", err)), nil
		}

		return toResult(map[string]interface{}{
			"registered": true,
			"agent":      agentName,
			"phase":      p.Phase,
		})
	}
}

func pipelineStatusHandler(st *store.Store) mcpserver.ToolHandlerFunc {
	return func(ctx context.Context, req mcpgo.CallToolRequest) (*mcpgo.CallToolResult, error) {
		pipelineID := req.GetArguments()["pipeline_id"].(string)

		p, err := st.GetPipeline(pipelineID)
		if err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("파이프라인 미발견: %v", err)), nil
		}

		spawns, _ := st.ListSpawns(pipelineID)
		spawnNames := make([]string, len(spawns))
		for i, s := range spawns {
			spawnNames[i] = s.AgentName
		}

		return toResult(map[string]interface{}{
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
		pipelineID := req.GetArguments()["pipeline_id"].(string)
		logPath := req.GetArguments()["interview_log_path"].(string)

		result, err := gate.CalculateAmbiguity(logPath)
		if err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("모호성 계산 실패: %v", err)), nil
		}

		gateResult := calc.Check("ambiguity", result.MechanicalScore)
		st.RecordGateScore(pipelineID, "ambiguity", result.MechanicalScore, gateResult.Passed, "")

		return toResult(map[string]interface{}{
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
		pipelineID := req.GetArguments()["pipeline_id"].(string)
		gateType := req.GetArguments()["gate_type"].(string)
		score := req.GetArguments()["score"].(float64)

		gateResult := calc.Check(gateType, score)
		st.RecordGateScore(pipelineID, gateType, score, gateResult.Passed, "")

		p, _ := st.GetPipeline(pipelineID)
		spawnReport, _ := gate.CheckRequiredSpawns(st, cfg, pipelineID, p.Skill)

		result := map[string]interface{}{
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
		pipelineID := req.GetArguments()["pipeline_id"].(string)
		phase := req.GetArguments()["phase"].(string)
		agent := req.GetArguments()["agent_name"].(string)

		var durationMS, tokenCount int64
		if v, ok := req.GetArguments()["duration_ms"].(float64); ok {
			durationMS = int64(v)
		}
		if v, ok := req.GetArguments()["token_count"].(float64); ok {
			tokenCount = int64(v)
		}

		if err := st.RecordExecution(pipelineID, phase, agent, durationMS, tokenCount, 0, 0, true, ""); err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("기록 실패: %v", err)), nil
		}

		return toResult(map[string]interface{}{"recorded": true})
	}
}

func validatePlanHandler(st *store.Store) mcpserver.ToolHandlerFunc {
	return func(ctx context.Context, req mcpgo.CallToolRequest) (*mcpgo.CallToolResult, error) {
		skill := req.GetArguments()["skill"].(string)
		phase := req.GetArguments()["phase"].(string)
		agent := req.GetArguments()["agent"].(string)

		var estimatedCalls int
		if v, ok := req.GetArguments()["estimated_calls"].(float64); ok {
			estimatedCalls = int(v)
		}

		result, err := history.ValidatePlan(st, skill, phase, agent, estimatedCalls)
		if err != nil {
			return mcpgo.NewToolResultError(fmt.Sprintf("검증 실패: %v", err)), nil
		}

		return toResult(result)
	}
}

func toResult(v interface{}) (*mcpgo.CallToolResult, error) {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return mcpgo.NewToolResultError(fmt.Sprintf("JSON 변환 실패: %v", err)), nil
	}
	return mcpgo.NewToolResultText(string(data)), nil
}
