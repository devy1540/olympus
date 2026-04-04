package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/devy1540/olympus/mcp-server/internal/cli"
	"github.com/devy1540/olympus/mcp-server/internal/config"
	"github.com/devy1540/olympus/mcp-server/internal/server"
	"github.com/devy1540/olympus/mcp-server/internal/store"
	mcpserver "github.com/mark3labs/mcp-go/server"
	"github.com/spf13/cobra"
)

var Version = "dev"

func main() {
	rootCmd := &cobra.Command{
		Use:     "olympus-mcp",
		Short:   "Olympus MCP Server — pipeline state, gate scoring, execution history",
		Version: Version,
	}

	rootCmd.AddCommand(serveCmd())
	rootCmd.AddCommand(cli.QueryCmd(getDataDir()))

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func serveCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "serve",
		Short: "Start MCP server (stdio transport)",
		RunE: func(cmd *cobra.Command, args []string) error {
			dataDir := getDataDir()
			pluginRoot := getPluginRoot()

			cfg, err := config.Load(pluginRoot, dataDir)
			if err != nil {
				return fmt.Errorf("설정 로드 실패: %w", err)
			}

			st, err := store.OpenRW(dataDir)
			if err != nil {
				return fmt.Errorf("DB 열기 실패: %w", err)
			}
			defer st.Close()

			s := server.NewServer(st, cfg)
			return mcpserver.ServeStdio(s)
		},
	}
}

func getDataDir() string {
	if dir := os.Getenv("OLYMPUS_DATA_DIR"); dir != "" {
		return expandHome(dir)
	}
	if dir := os.Getenv("CLAUDE_PLUGIN_DATA"); dir != "" {
		return expandHome(dir)
	}
	home, _ := os.UserHomeDir()
	return home + "/.olympus-mcp"
}

func expandHome(path string) string {
	if len(path) > 0 && path[0] == '~' {
		home, _ := os.UserHomeDir()
		return home + path[1:]
	}
	return path
}

func getPluginRoot() string {
	if root := os.Getenv("OLYMPUS_PLUGIN_ROOT"); root != "" {
		return expandHome(root)
	}
	if root := os.Getenv("CLAUDE_PLUGIN_ROOT"); root != "" {
		return expandHome(root)
	}
	// Fallback: assume binary is in bin/ under plugin root
	exe, err := os.Executable()
	if err == nil && exe != "" {
		return filepath.Dir(filepath.Dir(exe))
	}
	return "."
}
