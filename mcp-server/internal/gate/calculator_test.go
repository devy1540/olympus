package gate

import (
	"testing"

	"github.com/devy1540/olympus/mcp-server/internal/config"
)

func testThresholds() config.Thresholds {
	return config.Thresholds{
		Ambiguity:              config.ThresholdRule{Threshold: 0.2, Operator: "<="},
		Convergence:            config.ThresholdRule{Threshold: 0.95, Operator: ">="},
		Consensus:              config.ThresholdRule{Threshold: 0.66, Operator: ">="},
		Semantic:               config.ThresholdRule{Threshold: 0.8, Operator: ">="},
		EvolveDimensionMinimum: config.ThresholdRule{Threshold: 0.6, Operator: ">="},
	}
}

func TestAmbiguityGatePass(t *testing.T) {
	calc := NewCalculator(testThresholds())
	r := calc.Check("ambiguity", 0.15)
	if !r.Passed {
		t.Errorf("ambiguity 0.15 should pass (threshold <= 0.2), got passed=%v", r.Passed)
	}
	if r.Threshold != 0.2 {
		t.Errorf("expected threshold 0.2, got %v", r.Threshold)
	}
}

func TestAmbiguityGateFail(t *testing.T) {
	calc := NewCalculator(testThresholds())
	r := calc.Check("ambiguity", 0.35)
	if r.Passed {
		t.Errorf("ambiguity 0.35 should fail (threshold <= 0.2), got passed=%v", r.Passed)
	}
	if r.Message == "" {
		t.Error("failed gate should have a message")
	}
}

func TestAmbiguityGateBoundary(t *testing.T) {
	calc := NewCalculator(testThresholds())
	r := calc.Check("ambiguity", 0.2)
	if !r.Passed {
		t.Errorf("ambiguity 0.2 should pass (threshold <= 0.2, boundary), got passed=%v", r.Passed)
	}
}

func TestConvergenceGatePass(t *testing.T) {
	calc := NewCalculator(testThresholds())
	r := calc.Check("convergence", 0.97)
	if !r.Passed {
		t.Errorf("convergence 0.97 should pass (threshold >= 0.95)")
	}
}

func TestConvergenceGateFail(t *testing.T) {
	calc := NewCalculator(testThresholds())
	r := calc.Check("convergence", 0.90)
	if r.Passed {
		t.Errorf("convergence 0.90 should fail (threshold >= 0.95)")
	}
}

func TestConsensusGatePass(t *testing.T) {
	calc := NewCalculator(testThresholds())
	r := calc.Check("consensus", 0.75)
	if !r.Passed {
		t.Errorf("consensus 0.75 should pass (threshold >= 0.66)")
	}
}

func TestConsensusGateFail(t *testing.T) {
	calc := NewCalculator(testThresholds())
	r := calc.Check("consensus", 0.50)
	if r.Passed {
		t.Errorf("consensus 0.50 should fail (threshold >= 0.66)")
	}
}

func TestSemanticGatePass(t *testing.T) {
	calc := NewCalculator(testThresholds())
	r := calc.Check("semantic", 0.85)
	if !r.Passed {
		t.Errorf("semantic 0.85 should pass (threshold >= 0.8)")
	}
}

func TestSemanticGateFail(t *testing.T) {
	calc := NewCalculator(testThresholds())
	r := calc.Check("semantic", 0.60)
	if r.Passed {
		t.Errorf("semantic 0.60 should fail (threshold >= 0.8)")
	}
}

func TestEvolveDimensionMinimumGatePass(t *testing.T) {
	calc := NewCalculator(testThresholds())
	r := calc.Check("evolve_dimension_minimum", 0.75)
	if !r.Passed {
		t.Errorf("evolve_dimension_minimum 0.75 should pass (threshold >= 0.6)")
	}
}

func TestEvolveDimensionMinimumGateFail(t *testing.T) {
	calc := NewCalculator(testThresholds())
	r := calc.Check("evolve_dimension_minimum", 0.45)
	if r.Passed {
		t.Errorf("evolve_dimension_minimum 0.45 should fail (threshold >= 0.6)")
	}
}

func TestEvolveDimensionMinimumGateBoundary(t *testing.T) {
	calc := NewCalculator(testThresholds())
	r := calc.Check("evolve_dimension_minimum", 0.6)
	if !r.Passed {
		t.Errorf("evolve_dimension_minimum 0.6 should pass (threshold >= 0.6, boundary)")
	}
}

func TestUnknownGateType(t *testing.T) {
	calc := NewCalculator(testThresholds())
	r := calc.Check("nonexistent", 0.5)
	if r.Passed {
		t.Error("unknown gate type should not pass")
	}
	if r.Message == "" {
		t.Error("unknown gate type should produce an error message")
	}
}
