package store

import (
	"testing"
)

func newTestStore(t *testing.T) *Store {
	t.Helper()
	dir := t.TempDir()
	st, err := OpenRW(dir)
	if err != nil {
		t.Fatalf("failed to open store: %v", err)
	}
	t.Cleanup(func() { st.Close() })
	return st
}

func TestCreateAndGetPipeline(t *testing.T) {
	st := newTestStore(t)

	if err := st.CreatePipeline("test-001", "odyssey"); err != nil {
		t.Fatalf("create: %v", err)
	}

	p, err := st.GetPipeline("test-001")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if p.Skill != "odyssey" {
		t.Errorf("expected skill=odyssey, got %s", p.Skill)
	}
	if p.Phase != "init" {
		t.Errorf("expected phase=init, got %s", p.Phase)
	}
	if p.Status != "active" {
		t.Errorf("expected status=active, got %s", p.Status)
	}
}

func TestDuplicatePipeline(t *testing.T) {
	st := newTestStore(t)

	if err := st.CreatePipeline("dup-001", "oracle"); err != nil {
		t.Fatal(err)
	}
	if err := st.CreatePipeline("dup-001", "oracle"); err == nil {
		t.Error("duplicate pipeline ID should fail")
	}
}

func TestGetNonexistentPipeline(t *testing.T) {
	st := newTestStore(t)

	_, err := st.GetPipeline("nope")
	if err == nil {
		t.Error("should error on nonexistent pipeline")
	}
}

func TestUpdatePhaseValid(t *testing.T) {
	st := newTestStore(t)
	transitions := map[string][]string{
		"init":    {"oracle"},
		"oracle":  {"genesis", "pantheon"},
		"pantheon": {"planning"},
	}

	st.CreatePipeline("phase-001", "odyssey")

	// init -> oracle (allowed as init special case)
	if err := st.UpdatePhase("phase-001", "oracle", transitions); err != nil {
		t.Fatalf("init->oracle: %v", err)
	}

	p, _ := st.GetPipeline("phase-001")
	if p.Phase != "oracle" {
		t.Errorf("expected oracle, got %s", p.Phase)
	}

	// oracle -> pantheon (valid)
	if err := st.UpdatePhase("phase-001", "pantheon", transitions); err != nil {
		t.Fatalf("oracle->pantheon: %v", err)
	}
}

func TestUpdatePhaseInvalid(t *testing.T) {
	st := newTestStore(t)
	transitions := map[string][]string{
		"oracle": {"genesis", "pantheon"},
	}

	st.CreatePipeline("phase-002", "odyssey")
	st.UpdatePhase("phase-002", "oracle", map[string][]string{"init": {"oracle"}})

	// oracle -> execution (invalid — skips pantheon/planning)
	if err := st.UpdatePhase("phase-002", "execution", transitions); err == nil {
		t.Error("oracle->execution should be invalid")
	}
}

func TestRegisterAndCheckSpawn(t *testing.T) {
	st := newTestStore(t)
	st.CreatePipeline("spawn-001", "oracle")

	if err := st.RegisterSpawn("spawn-001", "hermes", "oracle"); err != nil {
		t.Fatalf("register: %v", err)
	}

	spawned, phase, err := st.IsSpawned("spawn-001", "hermes")
	if err != nil {
		t.Fatalf("check: %v", err)
	}
	if !spawned {
		t.Error("hermes should be spawned")
	}
	if phase != "oracle" {
		t.Errorf("expected phase=oracle, got %s", phase)
	}

	// Not spawned
	spawned2, _, _ := st.IsSpawned("spawn-001", "zeus")
	if spawned2 {
		t.Error("zeus should not be spawned")
	}
}

func TestDuplicateSpawnIgnored(t *testing.T) {
	st := newTestStore(t)
	st.CreatePipeline("spawn-dup", "oracle")

	st.RegisterSpawn("spawn-dup", "hermes", "oracle")
	if err := st.RegisterSpawn("spawn-dup", "hermes", "oracle"); err != nil {
		t.Errorf("duplicate spawn should be ignored (INSERT OR IGNORE), got error: %v", err)
	}

	spawns, _ := st.ListSpawns("spawn-dup")
	if len(spawns) != 1 {
		t.Errorf("expected 1 spawn, got %d", len(spawns))
	}
}

func TestGateScoreRecordAndQuery(t *testing.T) {
	st := newTestStore(t)
	st.CreatePipeline("gate-001", "oracle")

	if err := st.RecordGateScore("gate-001", "ambiguity", 0.15, true, ""); err != nil {
		t.Fatalf("record: %v", err)
	}

	gs, err := st.GetLatestGateScore("gate-001", "ambiguity")
	if err != nil {
		t.Fatalf("query: %v", err)
	}
	if !gs.Passed {
		t.Error("should be passed")
	}
	if gs.Score != 0.15 {
		t.Errorf("expected score 0.15, got %f", gs.Score)
	}
}

func TestGateScoreLatestWins(t *testing.T) {
	st := newTestStore(t)
	st.CreatePipeline("gate-002", "oracle")

	st.RecordGateScore("gate-002", "ambiguity", 0.35, false, "")
	st.RecordGateScore("gate-002", "ambiguity", 0.10, true, "")

	gs, _ := st.GetLatestGateScore("gate-002", "ambiguity")
	if !gs.Passed {
		t.Error("latest score (0.10, passed) should win")
	}
}

func TestCollaborationLog(t *testing.T) {
	st := newTestStore(t)
	st.CreatePipeline("collab-001", "odyssey")

	if err := st.LogCollaboration("collab-001", "hermes", "apollo", "oracle", "codebase context sent"); err != nil {
		t.Fatalf("log: %v", err)
	}

	logs, err := st.ListCollaborations("collab-001")
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(logs) != 1 {
		t.Fatalf("expected 1 log, got %d", len(logs))
	}
	if logs[0].FromAgent != "hermes" || logs[0].ToAgent != "apollo" {
		t.Errorf("unexpected log entry: %+v", logs[0])
	}
}

func TestExecutionRecord(t *testing.T) {
	st := newTestStore(t)
	st.CreatePipeline("exec-001", "odyssey")

	if err := st.RecordExecution("exec-001", "oracle", "hermes", 1500, 2000, 0, 0, true, ""); err != nil {
		t.Fatalf("record: %v", err)
	}

	stats, err := st.GetAggregateStats("odyssey", "oracle", "hermes")
	if err != nil {
		t.Fatalf("stats: %v", err)
	}
	if stats.Count != 1 {
		t.Errorf("expected count=1, got %d", stats.Count)
	}
	if stats.AvgDuration != 1500 {
		t.Errorf("expected avg_duration=1500, got %f", stats.AvgDuration)
	}
}
