package store

import (
	"time"
)

type GateScore struct {
	PipelineID string  `json:"pipeline_id"`
	GateType   string  `json:"gate_type"`
	Score      float64 `json:"score"`
	Passed     bool    `json:"passed"`
	DetailJSON string  `json:"detail_json,omitempty"`
	ScoredAt   string  `json:"scored_at"`
}

func (s *Store) RecordGateScore(pipelineID, gateType string, score float64, passed bool, detail string) error {
	now := time.Now().UTC().Format(time.RFC3339)
	passedInt := 0
	if passed {
		passedInt = 1
	}
	_, err := s.db.Exec(
		"INSERT INTO gate_scores (pipeline_id, gate_type, score, passed, detail_json, scored_at) VALUES (?, ?, ?, ?, ?, ?)",
		pipelineID, gateType, score, passedInt, detail, now,
	)
	return err
}

func (s *Store) GetLatestGateScore(pipelineID, gateType string) (*GateScore, error) {
	gs := &GateScore{}
	var passedInt int
	err := s.db.QueryRow(
		"SELECT pipeline_id, gate_type, score, passed, COALESCE(detail_json, ''), scored_at FROM gate_scores WHERE pipeline_id = ? AND gate_type = ? ORDER BY scored_at DESC LIMIT 1",
		pipelineID, gateType,
	).Scan(&gs.PipelineID, &gs.GateType, &gs.Score, &passedInt, &gs.DetailJSON, &gs.ScoredAt)
	if err != nil {
		return nil, err
	}
	gs.Passed = passedInt == 1
	return gs, nil
}
