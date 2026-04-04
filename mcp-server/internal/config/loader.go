package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

type ThresholdRule struct {
	Threshold float64 `json:"threshold"`
	Operator  string  `json:"operator"`
}

type Thresholds struct {
	Ambiguity   ThresholdRule `json:"ambiguity"`
	Convergence ThresholdRule `json:"convergence"`
	Consensus   ThresholdRule `json:"consensus"`
	Semantic    ThresholdRule `json:"semantic"`
}

type AgentConfig struct {
	Model           string `json:"model"`
	PermissionLevel string `json:"permissionLevel"`
	Role            string `json:"role"`
	MaxTurns        int    `json:"maxTurns"`
}

type AgentRegistry struct {
	Registry map[string]AgentConfig `json:"registry"`
}

type ArtifactEntry struct {
	Phase  interface{} `json:"phase"` // can be int or string
	Writer string      `json:"writer"`
	Source interface{} `json:"source"` // can be string or []string
}

type TransitionRule struct {
	Phases      []string            `json:"phases"`
	Transitions map[string][]string `json:"transitions"`
}

type Config struct {
	Thresholds    Thresholds
	Agents        AgentRegistry
	Transitions   TransitionRule
	Contracts     map[string]map[string]ArtifactEntry
	PluginRoot    string
	DataDir       string
}

func Load(pluginRoot, dataDir string) (*Config, error) {
	cfg := &Config{
		PluginRoot: pluginRoot,
		DataDir:    dataDir,
	}

	sharedDir := filepath.Join(pluginRoot, "docs", "shared")

	if err := loadJSON(filepath.Join(sharedDir, "gate-thresholds.json"), &cfg.Thresholds); err != nil {
		return nil, fmt.Errorf("gate-thresholds.json: %w", err)
	}

	schemaFile := filepath.Join(sharedDir, "agent-schema.json")
	if _, err := os.Stat(schemaFile); err == nil {
		var raw map[string]json.RawMessage
		if err := loadJSON(schemaFile, &raw); err != nil {
			return nil, fmt.Errorf("agent-schema.json: %w", err)
		}
		if regData, ok := raw["agentRegistry"]; ok {
			var reg struct {
				Registry map[string]AgentConfig `json:"registry"`
			}
			if err := json.Unmarshal(regData, &reg); err == nil {
				cfg.Agents = AgentRegistry{Registry: reg.Registry}
			}
		}
	}

	statesFile := filepath.Join(sharedDir, "pipeline-states.json")
	if _, err := os.Stat(statesFile); err == nil {
		// pipeline-states.json is a JSON Schema — transitions are nested at OdysseyPhases.transitions
		var raw map[string]json.RawMessage
		if err := loadJSON(statesFile, &raw); err != nil {
			return nil, fmt.Errorf("pipeline-states.json: %w", err)
		}
		if odysseyRaw, ok := raw["OdysseyPhases"]; ok {
			var odyssey struct {
				Phases      []string            `json:"enum"`
				Transitions map[string][]string `json:"transitions"`
			}
			if err := json.Unmarshal(odysseyRaw, &odyssey); err == nil {
				cfg.Transitions = TransitionRule{
					Phases:      odyssey.Phases,
					Transitions: odyssey.Transitions,
				}
			}
		}
	}

	contractsFile := filepath.Join(sharedDir, "artifact-contracts.json")
	if _, err := os.Stat(contractsFile); err == nil {
		if err := loadJSON(contractsFile, &cfg.Contracts); err != nil {
			return nil, fmt.Errorf("artifact-contracts.json: %w", err)
		}
	}

	return cfg, nil
}

func (c *Config) RequiredAgents(skill, phase string) []string {
	skillContracts, ok := c.Contracts[skill]
	if !ok {
		return nil
	}

	agentSet := make(map[string]bool)
	for _, entry := range skillContracts {
		if entry.Source == nil {
			continue
		}
		switch src := entry.Source.(type) {
		case string:
			if src != "" && src != "orchestrator" {
				agentSet[src] = true
			}
		case []interface{}:
			for _, s := range src {
				if str, ok := s.(string); ok && str != "orchestrator" {
					agentSet[str] = true
				}
			}
		}
	}

	result := make([]string, 0, len(agentSet))
	for agent := range agentSet {
		result = append(result, agent)
	}
	return result
}

func (c *Config) ValidTransitions(fromPhase string) []string {
	if transitions, ok := c.Transitions.Transitions[fromPhase]; ok {
		return transitions
	}
	return nil
}

func loadJSON(path string, v interface{}) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, v)
}
