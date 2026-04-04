package history

import (
	"fmt"

	"github.com/devy1540/olympus/mcp-server/internal/store"
)

type ValidationResult struct {
	Realistic  bool     `json:"realistic"`
	Warnings   []string `json:"warnings"`
	Historical *store.AggStats `json:"historical,omitempty"`
}

func ValidatePlan(st *store.Store, skill, phase, agent string, estimatedCalls int) (*ValidationResult, error) {
	stats, err := st.GetAggregateStats(skill, phase, agent)
	if err != nil {
		return &ValidationResult{Realistic: true, Warnings: []string{"실행 이력 없음 — 검증 불가"}}, nil
	}

	if stats.Count < 3 {
		return &ValidationResult{
			Realistic:  true,
			Warnings:   []string{fmt.Sprintf("실행 이력 %d건으로 검증 신뢰도 낮음 (최소 3건 필요)", stats.Count)},
			Historical: stats,
		}, nil
	}

	result := &ValidationResult{
		Realistic:  true,
		Historical: stats,
	}

	// Check if estimated calls are suspiciously low
	avgCalls := float64(stats.Count) / float64(stats.Count) // This would need per-pipeline grouping
	if estimatedCalls > 0 && float64(estimatedCalls) < avgCalls*0.5 {
		result.Warnings = append(result.Warnings, fmt.Sprintf(
			"과소 예측 의심: 계획 %d회, 과거 평균 %.1f회",
			estimatedCalls, avgCalls,
		))
		result.Realistic = false
	}

	if stats.AvgDuration > 300000 { // > 5 minutes average
		result.Warnings = append(result.Warnings, fmt.Sprintf(
			"이 유형의 작업 평균 소요시간: %.0f초 — 장시간 작업 예상",
			stats.AvgDuration/1000,
		))
	}

	return result, nil
}
