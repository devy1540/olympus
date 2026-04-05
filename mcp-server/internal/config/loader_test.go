package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadThresholds(t *testing.T) {
	dir := setupTestFiles(t)

	cfg, err := Load(dir, t.TempDir())
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	if cfg.Thresholds.Ambiguity.Threshold != 0.2 {
		t.Errorf("ambiguity threshold: expected 0.2, got %f", cfg.Thresholds.Ambiguity.Threshold)
	}
	if cfg.Thresholds.Ambiguity.Operator != "<=" {
		t.Errorf("ambiguity operator: expected <=, got %s", cfg.Thresholds.Ambiguity.Operator)
	}
	if cfg.Thresholds.Convergence.Threshold != 0.95 {
		t.Errorf("convergence threshold: expected 0.95, got %f", cfg.Thresholds.Convergence.Threshold)
	}
	if cfg.Thresholds.Consensus.Threshold != 0.66 {
		t.Errorf("consensus threshold: expected 0.66, got %f", cfg.Thresholds.Consensus.Threshold)
	}
	if cfg.Thresholds.Semantic.Threshold != 0.8 {
		t.Errorf("semantic threshold: expected 0.8, got %f", cfg.Thresholds.Semantic.Threshold)
	}
	if cfg.Thresholds.EvolveDimensionMinimum.Threshold != 0.6 {
		t.Errorf("evolve_dimension_minimum threshold: expected 0.6, got %f", cfg.Thresholds.EvolveDimensionMinimum.Threshold)
	}
	if cfg.Thresholds.EvolveDimensionMinimum.Operator != ">=" {
		t.Errorf("evolve_dimension_minimum operator: expected >=, got %s", cfg.Thresholds.EvolveDimensionMinimum.Operator)
	}
}

func TestLoadAgentRegistry(t *testing.T) {
	dir := setupTestFiles(t)

	cfg, err := Load(dir, t.TempDir())
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	if cfg.Agents.Registry == nil {
		t.Fatal("agent registry should not be nil")
	}

	zeus, ok := cfg.Agents.Registry["zeus"]
	if !ok {
		t.Fatal("zeus should be in registry")
	}
	if zeus.Model != "opus" {
		t.Errorf("zeus model: expected opus, got %s", zeus.Model)
	}
	if zeus.PermissionLevel != "full" {
		t.Errorf("zeus permission: expected full, got %s", zeus.PermissionLevel)
	}

	hermes, ok := cfg.Agents.Registry["hermes"]
	if !ok {
		t.Fatal("hermes should be in registry")
	}
	if hermes.PermissionLevel != "read-only" {
		t.Errorf("hermes permission: expected read-only, got %s", hermes.PermissionLevel)
	}
}

func TestLoadTransitions(t *testing.T) {
	dir := setupTestFiles(t)

	cfg, err := Load(dir, t.TempDir())
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	oracleNext := cfg.ValidTransitions("oracle")
	if len(oracleNext) != 2 {
		t.Fatalf("oracle should have 2 transitions, got %d: %v", len(oracleNext), oracleNext)
	}

	found := false
	for _, p := range oracleNext {
		if p == "pantheon" {
			found = true
		}
	}
	if !found {
		t.Error("oracle should transition to pantheon")
	}

	completedNext := cfg.ValidTransitions("completed")
	if len(completedNext) != 0 {
		t.Errorf("completed should have no transitions, got %v", completedNext)
	}
}

func TestLoadContracts(t *testing.T) {
	dir := setupTestFiles(t)

	cfg, err := Load(dir, t.TempDir())
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	if cfg.Contracts == nil {
		t.Fatal("contracts should not be nil")
	}

	oracle, ok := cfg.Contracts["oracle"]
	if !ok {
		t.Fatal("oracle contracts should exist")
	}

	spec, ok := oracle["spec.md"]
	if !ok {
		t.Fatal("spec.md should be in oracle contracts")
	}
	if spec.Writer != "orchestrator" {
		t.Errorf("spec.md writer: expected orchestrator, got %s", spec.Writer)
	}
}

func TestRequiredAgents(t *testing.T) {
	dir := setupTestFiles(t)

	cfg, err := Load(dir, t.TempDir())
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	required := cfg.RequiredAgents("oracle", "")
	if len(required) == 0 {
		t.Fatal("oracle should have required agents")
	}

	agentSet := make(map[string]bool)
	for _, a := range required {
		agentSet[a] = true
	}

	// hermes is a writer (not source) so not in required list
	for _, expected := range []string{"apollo", "metis"} {
		if !agentSet[expected] {
			t.Errorf("expected %s in required agents, got %v", expected, required)
		}
	}
}

func TestRequiredAgentsWithRequiredSpawn(t *testing.T) {
	dir := t.TempDir()
	sharedDir := filepath.Join(dir, "docs", "shared")
	os.MkdirAll(sharedDir, 0755)

	writeFile(t, filepath.Join(sharedDir, "gate-thresholds.json"), `{
		"ambiguity": {"threshold": 0.2, "operator": "<="},
		"convergence": {"threshold": 0.95, "operator": ">="},
		"consensus": {"threshold": 0.66, "operator": ">="},
		"semantic": {"threshold": 0.8, "operator": ">="},
		"evolve_dimension_minimum": {"threshold": 0.6, "operator": ">="}
	}`)

	// Test that required_spawn takes priority over source
	writeFile(t, filepath.Join(sharedDir, "artifact-contracts.json"), `{
		"evolve": {
			"eval-matrix.md":  {"phase": 3, "writer": "orchestrator", "source": "athena", "required_spawn": "athena"},
			"diagnosis.md":    {"phase": 4, "writer": "orchestrator", "source": ["metis", "eris"], "required_spawn": ["metis", "eris"]},
			"benchmark.md":    {"phase": 1, "writer": "orchestrator"}
		}
	}`)

	cfg, err := Load(dir, t.TempDir())
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	required := cfg.RequiredAgents("evolve", "")
	agentSet := make(map[string]bool)
	for _, a := range required {
		agentSet[a] = true
	}

	for _, expected := range []string{"athena", "metis", "eris"} {
		if !agentSet[expected] {
			t.Errorf("expected %s in required agents (from required_spawn), got %v", expected, required)
		}
	}

	if len(required) != 3 {
		t.Errorf("expected 3 required agents, got %d: %v", len(required), required)
	}
}

func TestLoadMissingFiles(t *testing.T) {
	dir := t.TempDir()
	sharedDir := filepath.Join(dir, "docs", "shared")
	os.MkdirAll(sharedDir, 0755)

	// Only gate-thresholds.json is required — others are optional
	writeFile(t, filepath.Join(sharedDir, "gate-thresholds.json"), `{
		"ambiguity": {"threshold": 0.2, "operator": "<="},
		"convergence": {"threshold": 0.95, "operator": ">="},
		"consensus": {"threshold": 0.66, "operator": ">="},
		"semantic": {"threshold": 0.8, "operator": ">="},
		"evolve_dimension_minimum": {"threshold": 0.6, "operator": ">="}
	}`)

	cfg, err := Load(dir, t.TempDir())
	if err != nil {
		t.Fatalf("Load should succeed with only thresholds: %v", err)
	}

	if len(cfg.Agents.Registry) > 0 {
		t.Error("registry should be empty when agent-schema.json is missing")
	}
}

// --- Test fixtures ---

func setupTestFiles(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	sharedDir := filepath.Join(dir, "docs", "shared")
	os.MkdirAll(sharedDir, 0755)

	writeFile(t, filepath.Join(sharedDir, "gate-thresholds.json"), `{
		"ambiguity": {"threshold": 0.2, "operator": "<="},
		"convergence": {"threshold": 0.95, "operator": ">="},
		"consensus": {"threshold": 0.66, "operator": ">="},
		"semantic": {"threshold": 0.8, "operator": ">="},
		"evolve_dimension_minimum": {"threshold": 0.6, "operator": ">="}
	}`)

	writeFile(t, filepath.Join(sharedDir, "agent-schema.json"), `{
		"agentRegistry": {
			"agents": {
				"zeus":    {"model": "opus",  "permissionLevel": "full",      "role": "Planner",  "maxTurns": 25},
				"hermes":  {"model": "haiku", "permissionLevel": "read-only", "role": "Explorer", "maxTurns": 15}
			}
		}
	}`)

	writeFile(t, filepath.Join(sharedDir, "pipeline-states.json"), `{
		"OdysseyPhases": {
			"enum": ["oracle","genesis","pantheon","planning","execution","tribunal","completed"],
			"transitions": {
				"oracle": ["genesis","pantheon"],
				"genesis": ["pantheon"],
				"pantheon": ["planning"],
				"planning": ["execution"],
				"execution": ["tribunal"],
				"tribunal": ["completed","execution"]
			}
		}
	}`)

	writeFile(t, filepath.Join(sharedDir, "artifact-contracts.json"), `{
		"oracle": {
			"codebase-context.md": {"phase": 1, "writer": "hermes"},
			"interview-log.md":    {"phase": 2, "writer": "orchestrator", "source": "apollo"},
			"ambiguity-scores.json": {"phase": 2, "writer": "orchestrator", "source": "apollo"},
			"gap-analysis.md":     {"phase": 4, "writer": "orchestrator", "source": "metis"},
			"spec.md":             {"phase": 5, "writer": "orchestrator"}
		}
	}`)

	return dir
}

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}
