#!/usr/bin/env bash
# postinstall.sh — Download or build platform-specific MCP server binary
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
        exit 0
        ;;
esac

if [[ "$PLATFORM" != "darwin" && "$PLATFORM" != "linux" ]]; then
    echo "[olympus] Unsupported platform: ${PLATFORM}"
    exit 0
fi

VERSION=$(jq -r '.version // "latest"' "${PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null || echo "latest")
ASSET_NAME="${BINARY_NAME}-${PLATFORM}-${ARCH}"
URL="https://github.com/devy1540/olympus/releases/download/v${VERSION}/${ASSET_NAME}"

# --- Functions ---

try_download() {
    echo "[olympus] Downloading MCP server: ${ASSET_NAME} (v${VERSION})"
    mkdir -p "$BIN_DIR"

    if command -v curl >/dev/null 2>&1; then
        HTTP_CODE=$(curl -fsSL -w "%{http_code}" -o "${BIN_DIR}/${BINARY_NAME}" "$URL" 2>/dev/null || echo "000")
        if [[ "$HTTP_CODE" == "200" ]]; then
            chmod +x "${BIN_DIR}/${BINARY_NAME}"
            if "${BIN_DIR}/${BINARY_NAME}" --version >/dev/null 2>&1; then
                echo "[olympus] MCP server downloaded and verified."
                return 0
            fi
            rm -f "${BIN_DIR}/${BINARY_NAME}"
        else
            rm -f "${BIN_DIR}/${BINARY_NAME}"
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q -O "${BIN_DIR}/${BINARY_NAME}" "$URL" 2>/dev/null; then
            chmod +x "${BIN_DIR}/${BINARY_NAME}"
            if "${BIN_DIR}/${BINARY_NAME}" --version >/dev/null 2>&1; then
                echo "[olympus] MCP server downloaded and verified."
                return 0
            fi
            rm -f "${BIN_DIR}/${BINARY_NAME}"
        fi
    fi

    echo "[olympus] Download failed or binary invalid."
    return 1
}

try_source_build() {
    if ! command -v go >/dev/null 2>&1; then
        echo "[olympus] Go not available for source build."
        return 1
    fi

    local MCP_SRC="${PLUGIN_ROOT}/mcp-server"
    if [[ ! -f "$MCP_SRC/go.mod" ]]; then
        echo "[olympus] MCP source not found at $MCP_SRC."
        return 1
    fi

    echo "[olympus] Building MCP server from source..."
    mkdir -p "$BIN_DIR"
    if (cd "$MCP_SRC" && go build -o "${BIN_DIR}/${BINARY_NAME}" ./cmd/olympus-mcp) 2>&1; then
        chmod +x "${BIN_DIR}/${BINARY_NAME}"
        echo "[olympus] MCP server built from source."
        return 0
    fi

    echo "[olympus] Source build failed."
    return 1
}

# --- Main ---

if try_download; then
    exit 0
fi

echo "[olympus] Falling back to source build..."
if try_source_build; then
    exit 0
fi

echo "[olympus] MCP server unavailable. Skills and hooks still work without MCP."
exit 0
