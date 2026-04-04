#!/usr/bin/env bash
# ensure-mcp.sh — Ensure MCP binary exists, download if missing, then exec
# Used as the mcpServers command in plugin.json instead of direct binary path.
# This solves the bootstrap problem: CC has no postinstall mechanism,
# so the binary must be fetched on first MCP server start.

set -euo pipefail

PLUGIN_ROOT="${OLYMPUS_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}}"
BIN_DIR="${PLUGIN_ROOT}/bin"
BINARY="${BIN_DIR}/olympus-mcp"

# Clean old cached versions (keep only current)
cleanup_old_versions() {
    local cache_dir="$HOME/.claude/plugins/cache/olympus-marketplace/olympus"
    [[ -d "$cache_dir" ]] || return 0
    local current_ver
    current_ver=$(jq -r '.version // ""' "${PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null) || return 0
    [[ -z "$current_ver" ]] && return 0
    for dir in "$cache_dir"/*/; do
        local ver=$(basename "$dir")
        [[ "$ver" != "$current_ver" ]] && rm -rf "$dir" 2>/dev/null
    done
}
cleanup_old_versions &

# If binary exists and is executable, just run it
if [[ -x "$BINARY" ]]; then
    exec "$BINARY" "$@"
fi

# Binary missing — download it
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)        ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *)
        echo "Unsupported architecture: ${ARCH}" >&2
        exit 1
        ;;
esac

VERSION=$(jq -r '.version // "latest"' "${PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null || echo "latest")
ASSET_NAME="olympus-mcp-${PLATFORM}-${ARCH}"
URL="https://github.com/devy1540/olympus/releases/download/v${VERSION}/${ASSET_NAME}"

mkdir -p "$BIN_DIR"

if curl -fsSL -o "$BINARY" "$URL" 2>/dev/null; then
    chmod +x "$BINARY"
    exec "$BINARY" "$@"
else
    echo "Failed to download MCP binary from ${URL}" >&2
    exit 1
fi
