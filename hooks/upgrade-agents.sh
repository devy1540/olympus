#!/usr/bin/env bash
# upgrade-agents.sh — Batch upgrade all agent definitions
# Adds: Context_Protocol section, CC-pattern frontmatter fields, dynamic threshold references
# Run: bash hooks/upgrade-agents.sh

set -euo pipefail

AGENTS_DIR="$(dirname "$0")/../agents"
CHANGED=0

for agent_file in "$AGENTS_DIR"/*.md; do
  name=$(basename "$agent_file" .md)

  # --- 1. Add CC-pattern frontmatter fields (isReadOnly, isConcurrencySafe) ---
  # Determine isReadOnly from disallowedTools
  HAS_WRITE=$(grep -c '^\s*-\s*Write' "$agent_file" || echo "0")
  HAS_EDIT=$(grep -c '^\s*-\s*Edit' "$agent_file" || echo "0")
  if [[ "$HAS_WRITE" -gt 0 && "$HAS_EDIT" -gt 0 ]]; then
    IS_READONLY="true"
  else
    IS_READONLY="false"
  fi

  # All agents are concurrency safe (they operate in isolated contexts)
  IS_CONCURRENCY_SAFE="true"

  # Check if already upgraded
  if grep -q 'isReadOnly' "$agent_file"; then
    echo "  SKIP $name (already has isReadOnly)"
    continue
  fi

  # Add fields before the closing ---
  # Find the line number of the second ---
  SECOND_DASH=$(grep -n '^---$' "$agent_file" | sed -n '2p' | cut -d: -f1)
  if [[ -z "$SECOND_DASH" ]]; then
    echo "  SKIP $name (no closing --- found)"
    continue
  fi

  # Insert CC-pattern fields before closing ---
  sed -i '' "${SECOND_DASH}i\\
isReadOnly: ${IS_READONLY}\\
isConcurrencySafe: ${IS_CONCURRENCY_SAFE}
" "$agent_file"

  # --- 2. Add <Context_Protocol> section after <Constraints> ---
  if ! grep -q '<Context_Protocol>' "$agent_file"; then
    # Find </Constraints> closing tag
    CONSTRAINTS_END=$(grep -n '</Constraints>' "$agent_file" | head -1 | cut -d: -f1)
    if [[ -n "$CONSTRAINTS_END" ]]; then
      INSERT_LINE=$((CONSTRAINTS_END + 1))
      sed -i '' "${INSERT_LINE}i\\
\\
  <Context_Protocol>\\
    When your task provides an artifact directory path (.olympus/{id}/), use Read to load\\
    artifacts directly. Do NOT expect full artifact content in your task prompt.\\
    - Read artifacts by path: Read .olympus/{id}/spec.md\\
    - Reference by path in SendMessage: \"Based on spec.md (.olympus/{id}/spec.md)...\"\\
    - For large artifacts, use Grep first to find the relevant section, then Read that range\\
    - gate-thresholds.json is the single source of truth for all threshold values\\
    - Never hardcode threshold values; always Read gate-thresholds.json if you need to check a gate\\
  </Context_Protocol>
" "$agent_file"
    fi
  fi

  CHANGED=$((CHANGED + 1))
  echo "  DONE $name (isReadOnly=$IS_READONLY)"
done

echo ""
echo "Upgraded $CHANGED agents."
