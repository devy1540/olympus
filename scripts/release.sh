#!/usr/bin/env bash
# Olympus Release Script
# Usage: bash scripts/release.sh [major|minor|patch]
# Example: bash scripts/release.sh patch  →  1.0.0 → 1.0.1

set -euo pipefail

BUMP_TYPE="${1:-}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# --- Color output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Validate arguments ---
if [[ -z "$BUMP_TYPE" ]]; then
  echo "Usage: bash scripts/release.sh [major|minor|patch]"
  echo ""
  echo "  major  →  X.0.0  (breaking changes)"
  echo "  minor  →  0.X.0  (new features, backward compatible)"
  echo "  patch  →  0.0.X  (bug fixes)"
  exit 1
fi

if [[ "$BUMP_TYPE" != "major" && "$BUMP_TYPE" != "minor" && "$BUMP_TYPE" != "patch" ]]; then
  error "Invalid bump type: '$BUMP_TYPE'. Use major, minor, or patch."
fi

cd "$ROOT_DIR"

# --- Pre-flight checks ---
info "Pre-flight checks..."

# Clean working tree?
if [[ -n "$(git status --porcelain)" ]]; then
  error "Working tree is not clean. Commit or stash changes first."
fi

# On main branch?
BRANCH=$(git branch --show-current)
if [[ "$BRANCH" != "main" ]]; then
  warn "Not on main branch (current: $BRANCH). Continue? [y/N]"
  read -r REPLY
  [[ "$REPLY" =~ ^[Yy]$ ]] || exit 0
fi

# jq available?
command -v jq >/dev/null 2>&1 || error "jq is required. Install: brew install jq"

# --- Read current version ---
CURRENT_VERSION=$(jq -r '.version' .claude-plugin/plugin.json)
info "Current version: v${CURRENT_VERSION}"

IFS='.' read -r V_MAJOR V_MINOR V_PATCH <<< "$CURRENT_VERSION"

case "$BUMP_TYPE" in
  major) V_MAJOR=$((V_MAJOR + 1)); V_MINOR=0; V_PATCH=0 ;;
  minor) V_MINOR=$((V_MINOR + 1)); V_PATCH=0 ;;
  patch) V_PATCH=$((V_PATCH + 1)) ;;
esac

NEW_VERSION="${V_MAJOR}.${V_MINOR}.${V_PATCH}"
TAG="v${NEW_VERSION}"

info "New version: ${TAG}"

# Check tag doesn't already exist
if git tag -l "$TAG" | grep -q "$TAG"; then
  error "Tag $TAG already exists."
fi

# --- Run validation tests ---
info "Running validation tests..."

bash hooks/test-hooks.sh > /dev/null 2>&1
HOOK_RESULT=$?
if [[ $HOOK_RESULT -ne 0 ]]; then
  error "Hook tests failed. Fix issues before releasing."
fi
ok "Hook tests passed (30/30)"

bash hooks/test-integration.sh > /dev/null 2>&1
INTEGRATION_RESULT=$?
if [[ $INTEGRATION_RESULT -ne 0 ]]; then
  error "Integration tests failed. Fix issues before releasing."
fi
ok "Integration tests passed"

# --- Bump version in files ---
info "Bumping version: ${CURRENT_VERSION} → ${NEW_VERSION}"

# plugin.json
jq --arg v "$NEW_VERSION" '.version = $v' .claude-plugin/plugin.json > .claude-plugin/plugin.json.tmp
mv .claude-plugin/plugin.json.tmp .claude-plugin/plugin.json

# marketplace.json
jq --arg v "$NEW_VERSION" '.version = $v | .plugins[0].version = $v' .claude-plugin/marketplace.json > .claude-plugin/marketplace.json.tmp
mv .claude-plugin/marketplace.json.tmp .claude-plugin/marketplace.json

ok "Version bumped in plugin.json and marketplace.json"

# --- Generate changelog entry ---
PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
CHANGELOG_FILE="docs/CHANGELOG-v${NEW_VERSION}.md"

info "Generating changelog..."

{
  echo "# Olympus v${NEW_VERSION}"
  echo ""
  echo "Released: $(date +%Y-%m-%d)"
  echo ""
  echo "## Changes"
  echo ""
  if [[ -n "$PREV_TAG" ]]; then
    git log "${PREV_TAG}..HEAD" --pretty=format:"- %s" --no-merges
  else
    git log --pretty=format:"- %s" --no-merges
  fi
  echo ""
  echo ""
  echo "## Commits"
  echo ""
  if [[ -n "$PREV_TAG" ]]; then
    git log "${PREV_TAG}..HEAD" --pretty=format:"- [\`%h\`] %s" --no-merges
  else
    git log --pretty=format:"- [\`%h\`] %s" --no-merges
  fi
  echo ""
} > "$CHANGELOG_FILE"

ok "Changelog generated: ${CHANGELOG_FILE}"

# --- Create release commit and tag ---
info "Creating release commit..."

git add .claude-plugin/plugin.json .claude-plugin/marketplace.json "$CHANGELOG_FILE"
git add -u  # Stage any modified tracked files

git commit -m "$(cat <<EOF
릴리스 ${TAG}

- 버전 범프: ${CURRENT_VERSION} → ${NEW_VERSION}
- CHANGELOG 생성: ${CHANGELOG_FILE}
EOF
)"

ok "Release commit created"

info "Creating tag: ${TAG}"
git tag -a "$TAG" -m "Olympus ${TAG}"
ok "Tag created: ${TAG}"

# --- Summary ---
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Release ${TAG} ready!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "  Next steps:"
echo "    git push origin main --tags     # Push commit and tag"
echo "    gh release create ${TAG} \\      # Create GitHub Release"
echo "      --title 'Olympus ${TAG}' \\"
echo "      --notes-file ${CHANGELOG_FILE}"
echo ""
echo "  Or push and let GitHub Actions create the release automatically."
echo ""
