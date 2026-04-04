package gate

import (
	"os"
	"regexp"
	"strings"
)

type AmbiguityResult struct {
	MechanicalScore float64            `json:"mechanical_score"`
	Dimensions      map[string]float64 `json:"dimensions"`
	Indicators      AmbiguityIndicators `json:"indicators"`
}

type AmbiguityIndicators struct {
	TotalQuestions   int `json:"total_questions"`
	UnansweredCount  int `json:"unanswered_count"`
	VagueExprCount   int `json:"vague_expression_count"`
	GWTCount         int `json:"gwt_ac_count"`
	TotalACCount     int `json:"total_ac_count"`
	ConcreteValues   int `json:"concrete_values"`
	VagueQualifiers  int `json:"vague_qualifiers"`
}

var vaguePatterns = regexp.MustCompile(`(?i)\b(probably|maybe|something like|approximately|around|not sure|we'll see|TBD|N/A|미정|추후 결정|나중에|적절한|충분한|가능하면|대략|정도)\b`)
var gwtPattern = regexp.MustCompile(`(?i)(GIVEN|WHEN|THEN|주어진|때|그러면)`)
var concretePattern = regexp.MustCompile(`\b\d+(\.\d+)?\s*(ms|MB|GB|KB|s|분|초|건|개|줄|lines|files|%)\b`)
var questionPattern = regexp.MustCompile(`\?`)
var unansweredPatterns = regexp.MustCompile(`(?i)(TBD|to be determined|will decide later|not yet decided|미정|추후|나중에 결정)`)

func CalculateAmbiguity(interviewLogPath string) (*AmbiguityResult, error) {
	data, err := os.ReadFile(interviewLogPath)
	if err != nil {
		return nil, err
	}
	content := string(data)
	lines := strings.Split(content, "\n")

	indicators := AmbiguityIndicators{}

	// Count questions and unanswered
	for _, line := range lines {
		if questionPattern.MatchString(line) && (strings.HasPrefix(strings.TrimSpace(line), "Q") || strings.HasPrefix(strings.TrimSpace(line), "**Q")) {
			indicators.TotalQuestions++
		}
		if unansweredPatterns.MatchString(line) {
			indicators.UnansweredCount++
		}
	}

	// Count vague expressions
	indicators.VagueExprCount = len(vaguePatterns.FindAllString(content, -1))

	// Count GWT patterns (acceptance criteria structure)
	indicators.GWTCount = len(gwtPattern.FindAllString(content, -1)) / 3 // each AC needs GIVEN+WHEN+THEN
	// Rough AC count from numbered items after "ACCEPTANCE" or "AC" headers
	acSection := extractSection(content, "ACCEPTANCE_CRITERIA", "AC")
	if acSection != "" {
		acLines := strings.Split(acSection, "\n")
		for _, l := range acLines {
			trimmed := strings.TrimSpace(l)
			if len(trimmed) > 0 && (trimmed[0] >= '1' && trimmed[0] <= '9' || strings.HasPrefix(trimmed, "- ")) {
				indicators.TotalACCount++
			}
		}
	}
	if indicators.TotalACCount == 0 {
		indicators.TotalACCount = 1 // avoid division by zero
	}

	// Count concrete values vs vague qualifiers
	indicators.ConcreteValues = len(concretePattern.FindAllString(content, -1))
	indicators.VagueQualifiers = indicators.VagueExprCount

	// Calculate dimensions
	goalClarity := 1.0
	if indicators.TotalQuestions > 0 {
		unansweredRatio := float64(indicators.UnansweredCount) / float64(indicators.TotalQuestions)
		goalClarity = 1.0 - unansweredRatio
	}

	constraintClarity := 1.0
	totalMentions := float64(indicators.ConcreteValues + indicators.VagueQualifiers)
	if totalMentions > 0 {
		constraintClarity = float64(indicators.ConcreteValues) / totalMentions
	}

	acTestability := float64(indicators.GWTCount) / float64(indicators.TotalACCount)
	if acTestability > 1.0 {
		acTestability = 1.0
	}

	// Weighted score: lower = more ambiguous
	clarity := goalClarity*0.4 + constraintClarity*0.3 + acTestability*0.3
	ambiguityScore := 1.0 - clarity

	// Clamp to [0, 1]
	if ambiguityScore < 0 {
		ambiguityScore = 0
	}
	if ambiguityScore > 1 {
		ambiguityScore = 1
	}

	return &AmbiguityResult{
		MechanicalScore: ambiguityScore,
		Dimensions: map[string]float64{
			"goal_clarity":       goalClarity,
			"constraint_clarity": constraintClarity,
			"ac_testability":     acTestability,
		},
		Indicators: indicators,
	}, nil
}

func extractSection(content, header1, header2 string) string {
	upper := strings.ToUpper(content)
	idx := strings.Index(upper, strings.ToUpper(header1))
	if idx == -1 {
		idx = strings.Index(upper, strings.ToUpper(header2))
	}
	if idx == -1 {
		return ""
	}

	rest := content[idx:]
	// Find next ## header
	lines := strings.Split(rest, "\n")
	var section strings.Builder
	started := false
	for _, line := range lines {
		if started && strings.HasPrefix(line, "## ") {
			break
		}
		if strings.Contains(strings.ToUpper(line), strings.ToUpper(header1)) || strings.Contains(strings.ToUpper(line), strings.ToUpper(header2)) {
			started = true
		}
		if started {
			section.WriteString(line)
			section.WriteString("\n")
		}
	}
	return section.String()
}
