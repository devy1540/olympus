#!/usr/bin/env bash
# postinstall.sh — Download platform-specific MCP server binary
# Called after plugin installation to set up the olympus-mcp binary

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BIN_DIR="${PLUGIN_ROOT}/bin"
BINARY_NAME="olympus-mcp"

# Detect platform
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)       ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *)
        echo "[olympus] Unsupported architecture: ${ARCH}"
        exit 0  # Don't fail install — hooks still work without MCP
        ;;
esac

# Only support darwin and linux
if [[ "$PLATFORM" != "darwin" && "$PLATFORM" != "linux" ]]; then
    echo "[olympus] Unsupported platform: ${PLATFORM}"
    exit 0
fi

# Get version from plugin.json
VERSION=$(jq -r '.version // "latest"' "${PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null || echo "latest")
ASSET_NAME="${BINARY_NAME}-${PLATFORM}-${ARCH}"
URL="https://github.com/devy1540/olympus/releases/download/v${VERSION}/${ASSET_NAME}"

echo "[olympus] Downloading MCP server: ${ASSET_NAME} (v${VERSION})"

mkdir -p "$BIN_DIR"

if command -v curl >/dev/null 2>&1; then
    HTTP_CODE=$(curl -fsSL -w "%{http_code}" -o "${BIN_DIR}/${BINARY_NAME}" "$URL" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" != "200" ]]; then
        echo "[olympus] Binary not available for v${VERSION} (HTTP ${HTTP_CODE}). MCP features disabled."
        rm -f "${BIN_DIR}/${BINARY_NAME}"
        exit 0
    fi
elif command -v wget >/dev/null 2>&1; then
    wget -q -O "${BIN_DIR}/${BINARY_NAME}" "$URL" 2>/dev/null || {
        echo "[olympus] Binary not available. MCP features disabled."
        rm -f "${BIN_DIR}/${BINARY_NAME}"
        exit 0
    }
else
    echo "[olympus] Neither curl nor wget found. MCP features disabled."
    exit 0
fi

chmod +x "${BIN_DIR}/${BINARY_NAME}"
echo "[olympus] MCP server installed: ${BIN_DIR}/${BINARY_NAME}"

# Verify binary works
if "${BIN_DIR}/${BINARY_NAME}" --version >/dev/null 2>&1; then
    echo "[olympus] MCP server verified."
else
    echo "[olympus] Binary verification failed. Removing."
    rm -f "${BIN_DIR}/${BINARY_NAME}"
fi
