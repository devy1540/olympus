package store

import (
	"fmt"
	"time"
)

type Pipeline struct {
	ID        string `json:"id"`
	Skill     string `json:"skill"`
	Phase     string `json:"phase"`
	Status    string `json:"status"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
	StateJSON string `json:"state_json,omitempty"`
}

type AgentSpawn struct {
	PipelineID string `json:"pipeline_id"`
	AgentName  string `json:"agent_name"`
	Phase      string `json:"phase"`
	SpawnedAt  string `json:"spawned_at"`
}

func (s *Store) CreatePipeline(id, skill string) error {
	now := time.Now().UTC().Format(time.RFC3339)
	_, err := s.db.Exec(
		"INSERT INTO pipelines (id, skill, phase, status, created_at, updated_at) VALUES (?, ?, 'init', 'active', ?, ?)",
		id, skill, now, now,
	)
	return err
}

func (s *Store) GetPipeline(id string) (*Pipeline, error) {
	p := &Pipeline{}
	err := s.db.QueryRow(
		"SELECT id, skill, phase, status, created_at, updated_at, COALESCE(state_json, '') FROM pipelines WHERE id = ?", id,
	).Scan(&p.ID, &p.Skill, &p.Phase, &p.Status, &p.CreatedAt, &p.UpdatedAt, &p.StateJSON)
	if err != nil {
		return nil, fmt.Errorf("pipeline not found: %s", id)
	}
	return p, nil
}

func (s *Store) UpdatePhase(id, newPhase string, validTransitions map[string][]string) error {
	p, err := s.GetPipeline(id)
	if err != nil {
		return err
	}

	allowed := validTransitions[p.Phase]
	valid := false
	for _, t := range allowed {
		if t == newPhase {
			valid = true
			break
		}
	}

	// Also allow "init" -> first phase
	if p.Phase == "init" {
		valid = true
	}

	if !valid {
		return fmt.Errorf("invalid transition: %s → %s (allowed: %v)", p.Phase, newPhase, allowed)
	}

	now := time.Now().UTC().Format(time.RFC3339)
	_, err = s.db.Exec(
		"UPDATE pipelines SET phase = ?, updated_at = ? WHERE id = ?",
		newPhase, now, id,
	)
	return err
}

func (s *Store) UpdateStatus(id, status string) error {
	now := time.Now().UTC().Format(time.RFC3339)
	_, err := s.db.Exec(
		"UPDATE pipelines SET status = ?, updated_at = ? WHERE id = ?",
		status, now, id,
	)
	return err
}

func (s *Store) RegisterSpawn(pipelineID, agentName, phase string) error {
	now := time.Now().UTC().Format(time.RFC3339)
	_, err := s.db.Exec(
		"INSERT OR IGNORE INTO agent_spawns (pipeline_id, agent_name, phase, spawned_at) VALUES (?, ?, ?, ?)",
		pipelineID, agentName, phase, now,
	)
	return err
}

func (s *Store) IsSpawned(pipelineID, agentName string) (bool, string, error) {
	var phase string
	err := s.db.QueryRow(
		"SELECT phase FROM agent_spawns WHERE pipeline_id = ? AND agent_name = ? ORDER BY spawned_at DESC LIMIT 1",
		pipelineID, agentName,
	).Scan(&phase)
	if err != nil {
		return false, "", nil
	}
	return true, phase, nil
}

func (s *Store) ListSpawns(pipelineID string) ([]AgentSpawn, error) {
	rows, err := s.db.Query(
		"SELECT pipeline_id, agent_name, phase, spawned_at FROM agent_spawns WHERE pipeline_id = ? ORDER BY spawned_at",
		pipelineID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var spawns []AgentSpawn
	for rows.Next() {
		var sp AgentSpawn
		if err := rows.Scan(&sp.PipelineID, &sp.AgentName, &sp.Phase, &sp.SpawnedAt); err != nil {
			return nil, err
		}
		spawns = append(spawns, sp)
	}
	return spawns, nil
}

func (s *Store) NextPhase(pipelineID string, transitions map[string][]string) (string, []string, error) {
	p, err := s.GetPipeline(pipelineID)
	if err != nil {
		return "", nil, err
	}

	// "init" is the internal start state — transition to the first defined phase
	phase := p.Phase
	if phase == "init" {
		phase = "oracle"
	}

	allowed := transitions[phase]
	if len(allowed) == 0 {
		return "", nil, fmt.Errorf("no transitions from phase: %s", phase)
	}

	return allowed[0], allowed, nil
}

// LogCollaboration records inter-agent communication for teammate mode.
func (s *Store) LogCollaboration(pipelineID, fromAgent, toAgent, phase, summary string) error {
	now := time.Now().UTC().Format(time.RFC3339)
	_, err := s.db.Exec(
		"INSERT INTO collaboration_logs (pipeline_id, from_agent, to_agent, phase, summary, logged_at) VALUES (?, ?, ?, ?, ?, ?)",
		pipelineID, fromAgent, toAgent, phase, summary, now,
	)
	return err
}

// ListCollaborations returns all collaboration logs for a pipeline.
func (s *Store) ListCollaborations(pipelineID string) ([]CollaborationLog, error) {
	rows, err := s.db.Query(
		"SELECT from_agent, to_agent, phase, summary, logged_at FROM collaboration_logs WHERE pipeline_id = ? ORDER BY logged_at",
		pipelineID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []CollaborationLog
	for rows.Next() {
		var log CollaborationLog
		if err := rows.Scan(&log.FromAgent, &log.ToAgent, &log.Phase, &log.Summary, &log.LoggedAt); err != nil {
			return nil, err
		}
		logs = append(logs, log)
	}
	return logs, nil
}

type CollaborationLog struct {
	FromAgent string `json:"from_agent"`
	ToAgent   string `json:"to_agent"`
	Phase     string `json:"phase"`
	Summary   string `json:"summary"`
	LoggedAt  string `json:"logged_at"`
}
