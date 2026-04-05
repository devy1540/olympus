package history

import (
	"testing"

	"github.com/devy1540/olympus/mcp-server/internal/store"
)

func setupTestStore(t *testing.T) *store.Store {
	t.Helper()
	dir := t.TempDir()
	st, err := store.OpenRW(dir)
	if err != nil {
		t.Fatalf("store.OpenRW failed: %v", err)
	}
	t.Cleanup(func() { st.Close() })
	return st
}

func TestValidatePlan_NoHistory(t *testing.T) {
	st := setupTestStore(t)

	result, err := ValidatePlan(st, "oracle", "oracle", "hermes", 5)
	if err != nil {
		t.Fatalf("ValidatePlan failed: %v", err)
	}

	if !result.Realistic {
		t.Error("expected realistic=true when no history")
	}
	if len(result.Warnings) == 0 {
		t.Error("expected warning about no history")
	}
}

func TestValidatePlan_InsufficientHistory(t *testing.T) {
	st := setupTestStore(t)

	// Add 2 records (below 3 threshold)
	st.RecordExecution("pipe-1", "oracle", "hermes", 1000, 500, 10, 2, true, "{}")
	st.RecordExecution("pipe-2", "oracle", "hermes", 2000, 800, 15, 3, true, "{}")

	result, err := ValidatePlan(st, "oracle", "oracle", "hermes", 5)
	if err != nil {
		t.Fatalf("ValidatePlan failed: %v", err)
	}

	if !result.Realistic {
		t.Error("expected realistic=true with insufficient history")
	}
	if result.Historical == nil {
		t.Error("expected historical stats")
	}
}

func TestValidatePlan_SufficientHistory(t *testing.T) {
	st := setupTestStore(t)

	for i := 0; i < 5; i++ {
		pid := "pipe-suf-" + string(rune('A'+i))
		st.CreatePipeline(pid, "oracle")
		st.RecordExecution(pid, "oracle", "hermes", 1000, 500, 10, 2, true, "{}")
	}

	result, err := ValidatePlan(st, "oracle", "oracle", "hermes", 5)
	if err != nil {
		t.Fatalf("ValidatePlan failed: %v", err)
	}

	if result.Historical == nil {
		t.Error("expected historical stats with 5 records")
	}
	if result.Historical.Count != 5 {
		t.Errorf("expected count=5, got %d", result.Historical.Count)
	}
}

func TestValidatePlan_LongDurationWarning(t *testing.T) {
	st := setupTestStore(t)

	for i := 0; i < 5; i++ {
		pid := "pipe-long-" + string(rune('A'+i))
		st.CreatePipeline(pid, "oracle")
		st.RecordExecution(pid, "oracle", "hermes", 400000, 1000, 5, 1, true, "{}")
	}

	result, err := ValidatePlan(st, "oracle", "oracle", "hermes", 5)
	if err != nil {
		t.Fatalf("ValidatePlan failed: %v", err)
	}

	foundDurationWarning := false
	for _, w := range result.Warnings {
		if len(w) > 20 {
			foundDurationWarning = true
		}
	}
	if !foundDurationWarning {
		t.Error("expected duration warning for >5min average")
	}
}
