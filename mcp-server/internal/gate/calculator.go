package gate

import (
	"fmt"

	"github.com/devy1540/olympus/mcp-server/internal/config"
)

type GateResult struct {
	Passed    bool    `json:"passed"`
	Score     float64 `json:"score"`
	Threshold float64 `json:"threshold"`
	Operator  string  `json:"operator"`
	Message   string  `json:"message,omitempty"`
}

type Calculator struct {
	thresholds config.Thresholds
}

func NewCalculator(thresholds config.Thresholds) *Calculator {
	return &Calculator{thresholds: thresholds}
}

func (c *Calculator) Check(gateType string, score float64) *GateResult {
	var rule config.ThresholdRule

	switch gateType {
	case "ambiguity":
		rule = c.thresholds.Ambiguity
	case "convergence":
		rule = c.thresholds.Convergence
	case "consensus":
		rule = c.thresholds.Consensus
	case "semantic":
		rule = c.thresholds.Semantic
	default:
		return &GateResult{Passed: false, Message: fmt.Sprintf("unknown gate type: %s", gateType)}
	}

	passed := false
	switch rule.Operator {
	case "<=":
		passed = score <= rule.Threshold
	case ">=":
		passed = score >= rule.Threshold
	case "<":
		passed = score < rule.Threshold
	case ">":
		passed = score > rule.Threshold
	}

	msg := ""
	if !passed {
		msg = fmt.Sprintf("GATE FAIL: %s score %.3f does not satisfy %s %.3f", gateType, score, rule.Operator, rule.Threshold)
	}

	return &GateResult{
		Passed:    passed,
		Score:     score,
		Threshold: rule.Threshold,
		Operator:  rule.Operator,
		Message:   msg,
	}
}
