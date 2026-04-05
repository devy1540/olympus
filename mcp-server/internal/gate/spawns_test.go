package gate

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/devy1540/olympus/mcp-server/internal/config"
	"github.com/devy1540/olympus/mcp-server/internal/store"
)

func newTestStore(t *testing.T) *store.Store {
	t.Helper()
	dir := t.TempDir()
	st, err := store.OpenRW(dir)
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { st.Close() })
	return st
}

func testSpawnConfig(t *testing.T) *config.Config {
	t.Helper()
	dir := t.TempDir()
	sharedDir := filepath.Join(dir, "docs", "shared")
	os.MkdirAll(sharedDir, 0755)

	writeJSON(t, filepath.Join(sharedDir, "gate-thresholds.json"), `{
		"ambiguity": {"threshold": 0.2, "operator": "<="},
		"convergence": {"threshold": 0.95, "operator": ">="},
		"consensus": {"threshold": 0.66, "operator": ">="},
		"semantic": {"threshold": 0.8, "operator": ">="},
		"evolve_dimension_minimum": {"threshold": 0.6, "operator": ">="}
	}`)

	writeJSON(t, filepath.Join(sharedDir, "artifact-contracts.json"), `{
		"oracle": {
			"codebase-context.md": {"phase": 1, "writer": "hermes"},
			"interview-log.md":    {"phase": 2, "writer": "orchestrator", "source": "apollo"},
			"gap-analysis.md":     {"phase": 4, "writer": "orchestrator", "source": "metis"},
			"spec.md":             {"phase": 5, "writer": "orchestrator"}
		}
	}`)

	cfg, err := config.Load(dir, t.TempDir())
	if err != nil {
		t.Fatalf("load config: %v", err)
	}
	return cfg
}

func writeJSON(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

func TestCheckRequiredSpawnsAllPresent(t *testing.T) {
	st := newTestStore(t)
	cfg := testSpawnConfig(t)

	st.CreatePipeline("spawn-all", "oracle")
	st.RegisterSpawn("spawn-all", "apollo", "oracle")
	st.RegisterSpawn("spawn-all", "metis", "oracle")

	report, err := CheckRequiredSpawns(st, cfg, "spawn-all", "oracle")
	if err != nil {
		t.Fatalf("check: %v", err)
	}

	if !report.AllSpawned {
		t.Errorf("all required agents spawned, but AllSpawned=%v, missing=%v", report.AllSpawned, report.Missing)
	}
	if len(report.Missing) != 0 {
		t.Errorf("expected no missing, got %v", report.Missing)
	}
}

func TestCheckRequiredSpawnsMissing(t *testing.T) {
	st := newTestStore(t)
	cfg := testSpawnConfig(t)

	st.CreatePipeline("spawn-partial", "oracle")
	st.RegisterSpawn("spawn-partial", "apollo", "oracle")

	report, err := CheckRequiredSpawns(st, cfg, "spawn-partial", "oracle")
	if err != nil {
		t.Fatalf("check: %v", err)
	}

	if report.AllSpawned {
		t.Error("metis is missing, AllSpawned should be false")
	}
	if len(report.Missing) != 1 || report.Missing[0] != "metis" {
		t.Errorf("expected missing=[metis], got %v", report.Missing)
	}
}

func TestCheckRequiredSpawnsNoRequired(t *testing.T) {
	st := newTestStore(t)
	cfg := testSpawnConfig(t)

	st.CreatePipeline("spawn-none", "tribunal")

	report, err := CheckRequiredSpawns(st, cfg, "spawn-none", "tribunal")
	if err != nil {
		t.Fatalf("check: %v", err)
	}

	if !report.AllSpawned {
		t.Error("no required agents means AllSpawned should be true")
	}
	if len(report.Required) != 0 {
		t.Errorf("expected 0 required, got %v", report.Required)
	}
}

func TestCheckRequiredSpawnsDeduplicate(t *testing.T) {
	st := newTestStore(t)
	cfg := testSpawnConfig(t)

	st.CreatePipeline("spawn-dedup", "oracle")
	st.RegisterSpawn("spawn-dedup", "apollo", "oracle")
	st.RegisterSpawn("spawn-dedup", "apollo", "pantheon")
	st.RegisterSpawn("spawn-dedup", "metis", "oracle")

	report, err := CheckRequiredSpawns(st, cfg, "spawn-dedup", "oracle")
	if err != nil {
		t.Fatalf("check: %v", err)
	}

	if !report.AllSpawned {
		t.Error("all agents present, AllSpawned should be true")
	}

	apolloCount := 0
	for _, name := range report.Spawned {
		if name == "apollo" {
			apolloCount++
		}
	}
	if apolloCount != 1 {
		t.Errorf("apollo should appear once in Spawned, got %d", apolloCount)
	}
}
