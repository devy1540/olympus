package cli

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/devy1540/olympus/mcp-server/internal/store"
	"github.com/spf13/cobra"
)

func QueryCmd(dataDir string) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "query",
		Short: "Query pipeline state (for hooks)",
	}

	cmd.AddCommand(isSpawnedCmd(dataDir))
	cmd.AddCommand(gateStatusCmd(dataDir))
	cmd.AddCommand(nextPhaseCmd(dataDir))
	cmd.AddCommand(pipelineStatusCmd(dataDir))

	return cmd
}

func isSpawnedCmd(dataDir string) *cobra.Command {
	return &cobra.Command{
		Use:   "is-spawned [pipeline_id] [agent]",
		Short: "Check if an agent was spawned",
		Args:  cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			st, err := store.OpenRO(dataDir)
			if err != nil {
				return outputJSON(map[string]interface{}{"spawned": false, "error": err.Error()})
			}
			defer st.Close()

			spawned, phase, err := st.IsSpawned(args[0], args[1])
			if err != nil {
				return outputJSON(map[string]interface{}{"spawned": false})
			}

			result := map[string]interface{}{"spawned": spawned}
			if spawned {
				result["phase"] = phase
			}

			if !spawned {
				os.Exit(1)
			}
			return outputJSON(result)
		},
	}
}

func gateStatusCmd(dataDir string) *cobra.Command {
	return &cobra.Command{
		Use:   "gate-status [pipeline_id] [gate_type]",
		Short: "Check gate pass/fail status",
		Args:  cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			st, err := store.OpenRO(dataDir)
			if err != nil {
				return outputJSON(map[string]interface{}{"error": err.Error()})
			}
			defer st.Close()

			gs, err := st.GetLatestGateScore(args[0], args[1])
			if err != nil {
				fmt.Fprintf(os.Stderr, "no gate score found\n")
				os.Exit(1)
				return nil
			}

			result := map[string]interface{}{
				"passed": gs.Passed,
				"score":  gs.Score,
			}

			if !gs.Passed {
				os.Exit(1)
			}
			return outputJSON(result)
		},
	}
}

func nextPhaseCmd(dataDir string) *cobra.Command {
	return &cobra.Command{
		Use:   "next-phase [pipeline_id]",
		Short: "Get next valid phase",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			st, err := store.OpenRO(dataDir)
			if err != nil {
				return outputJSON(map[string]interface{}{"error": err.Error()})
			}
			defer st.Close()

			p, err := st.GetPipeline(args[0])
			if err != nil {
				return outputJSON(map[string]interface{}{"error": err.Error()})
			}

			return outputJSON(map[string]interface{}{
				"current": p.Phase,
			})
		},
	}
}

func pipelineStatusCmd(dataDir string) *cobra.Command {
	return &cobra.Command{
		Use:   "pipeline-status [pipeline_id]",
		Short: "Get full pipeline status",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			st, err := store.OpenRO(dataDir)
			if err != nil {
				return outputJSON(map[string]interface{}{"error": err.Error()})
			}
			defer st.Close()

			p, err := st.GetPipeline(args[0])
			if err != nil {
				return outputJSON(map[string]interface{}{"error": err.Error()})
			}

			spawns, _ := st.ListSpawns(args[0])
			spawnNames := make([]string, len(spawns))
			for i, s := range spawns {
				spawnNames[i] = s.AgentName
			}

			return outputJSON(map[string]interface{}{
				"id":      p.ID,
				"skill":   p.Skill,
				"phase":   p.Phase,
				"status":  p.Status,
				"spawned": spawnNames,
			})
		},
	}
}

func outputJSON(v interface{}) error {
	data, err := json.Marshal(v)
	if err != nil {
		return err
	}
	fmt.Println(string(data))
	return nil
}
