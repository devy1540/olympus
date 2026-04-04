package gate

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCalculateAmbiguityClean(t *testing.T) {
	// Well-structured interview with concrete values and GWT ACs
	content := `# Interview Log
## Round 1: Scope
**Q**: What is the goal?
**A**: Build a REST API for user management with CRUD operations.

## Round 2: Constraints
**Q**: What is the expected response time?
**A**: Under 200ms for 95th percentile. Max 10000 concurrent users.

## Round 3: Acceptance Criteria
GIVEN a valid user payload
WHEN POST /api/users is called
THEN the user is created and 201 is returned

GIVEN an existing user ID
WHEN GET /api/users/{id} is called
THEN the user data is returned with 200
`

	dir := t.TempDir()
	path := filepath.Join(dir, "interview-log.md")
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	result, err := CalculateAmbiguity(path)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result.MechanicalScore > 0.2 {
		t.Errorf("clean interview should have low ambiguity (<=0.2), got %f", result.MechanicalScore)
	}
	if result.Indicators.TotalQuestions == 0 {
		t.Error("should detect questions")
	}
	if result.Indicators.ConcreteValues == 0 {
		t.Error("should detect concrete values (200ms, 10000)")
	}
}

func TestCalculateAmbiguityVague(t *testing.T) {
	// Vague interview with TBD and uncertain language
	content := `# Interview Log
## Round 1: Scope
**Q**: What is the goal?
**A**: Something like a notification system, probably for mobile.

## Round 2: Constraints
**Q**: What is the volume?
**A**: TBD, maybe around 10k/day. We'll see.

## Round 3: Scale
**Q**: How many users?
**A**: Not sure yet. Approximately a few thousand.
`

	dir := t.TempDir()
	path := filepath.Join(dir, "interview-log.md")
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	result, err := CalculateAmbiguity(path)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result.MechanicalScore < 0.2 {
		t.Errorf("vague interview should have high ambiguity (>0.2), got %f", result.MechanicalScore)
	}
	if result.Indicators.VagueExprCount == 0 {
		t.Error("should detect vague expressions (probably, maybe, TBD, etc.)")
	}
}

func TestCalculateAmbiguityMissingFile(t *testing.T) {
	_, err := CalculateAmbiguity("/nonexistent/interview-log.md")
	if err == nil {
		t.Error("should return error for missing file")
	}
}

func TestCalculateAmbiguityEmpty(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "interview-log.md")
	if err := os.WriteFile(path, []byte(""), 0644); err != nil {
		t.Fatal(err)
	}

	result, err := CalculateAmbiguity(path)
	if err != nil {
		t.Fatalf("empty file should not error: %v", err)
	}
	if result.MechanicalScore < 0 || result.MechanicalScore > 1 {
		t.Errorf("score should be clamped to [0,1], got %f", result.MechanicalScore)
	}
}
