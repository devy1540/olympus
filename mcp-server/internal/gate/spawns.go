package gate

import (
	"github.com/devy1540/olympus/mcp-server/internal/config"
	"github.com/devy1540/olympus/mcp-server/internal/store"
)

type SpawnReport struct {
	AllSpawned    bool     `json:"all_spawned"`
	Required      []string `json:"required"`
	Spawned       []string `json:"spawned"`
	Missing       []string `json:"missing"`
}

func CheckRequiredSpawns(st *store.Store, cfg *config.Config, pipelineID, skill string) (*SpawnReport, error) {
	required := cfg.RequiredAgents(skill, "")

	spawns, err := st.ListSpawns(pipelineID)
	if err != nil {
		return nil, err
	}

	spawnedSet := make(map[string]bool)
	spawnedNames := make([]string, 0)
	for _, s := range spawns {
		if !spawnedSet[s.AgentName] {
			spawnedSet[s.AgentName] = true
			spawnedNames = append(spawnedNames, s.AgentName)
		}
	}

	var missing []string
	for _, r := range required {
		if !spawnedSet[r] {
			missing = append(missing, r)
		}
	}

	return &SpawnReport{
		AllSpawned: len(missing) == 0,
		Required:   required,
		Spawned:    spawnedNames,
		Missing:    missing,
	}, nil
}
