package store

import (
	"time"
)

type ExecutionRecord struct {
	PipelineID   string `json:"pipeline_id"`
	Phase        string `json:"phase"`
	AgentName    string `json:"agent_name"`
	DurationMS   int64  `json:"duration_ms,omitempty"`
	TokenCount   int64  `json:"token_count,omitempty"`
	LOCChanged   int64  `json:"loc_changed,omitempty"`
	FilesTouched int64  `json:"files_touched,omitempty"`
	Success      bool   `json:"success"`
	RecordedAt   string `json:"recorded_at"`
	MetricsJSON  string `json:"metrics_json,omitempty"`
}

type AggStats struct {
	Count       int     `json:"count"`
	AvgDuration float64 `json:"avg_duration_ms"`
	AvgTokens   float64 `json:"avg_token_count"`
	AvgLOC      float64 `json:"avg_loc_changed"`
}

func (s *Store) RecordExecution(pipelineID, phase, agent string, durationMS, tokenCount, locChanged, filesTouched int64, success bool, metricsJSON string) error {
	now := time.Now().UTC().Format(time.RFC3339)
	successInt := 0
	if success {
		successInt = 1
	}
	_, err := s.db.Exec(
		"INSERT INTO execution_history (pipeline_id, phase, agent_name, duration_ms, token_count, loc_changed, files_touched, success, recorded_at, metrics_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
		pipelineID, phase, agent, durationMS, tokenCount, locChanged, filesTouched, successInt, now, metricsJSON,
	)
	return err
}

func (s *Store) GetAggregateStats(skill, phase, agent string) (*AggStats, error) {
	stats := &AggStats{}
	err := s.db.QueryRow(`
		SELECT COUNT(*), COALESCE(AVG(duration_ms), 0), COALESCE(AVG(token_count), 0), COALESCE(AVG(loc_changed), 0)
		FROM execution_history eh
		JOIN pipelines p ON eh.pipeline_id = p.id
		WHERE p.skill = ? AND eh.phase = ? AND eh.agent_name = ?`,
		skill, phase, agent,
	).Scan(&stats.Count, &stats.AvgDuration, &stats.AvgTokens, &stats.AvgLOC)
	if err != nil {
		return nil, err
	}
	return stats, nil
}
