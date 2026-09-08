#!/usr/bin/env bash
set -euo pipefail

: "${HOME:?HOME is not set}"

SKILL_URL="https://raw.githubusercontent.com/AmineMabrouk17/Shield/main/.agents/skills/shield/SKILL.md"
TARGET="${HOME}/.agents/skills/shield/SKILL.md"

mkdir -p "${HOME}/.agents/skills/shield"

UPDATED=0
if [ -f "$TARGET" ]; then
  UPDATED=1
fi

if ! curl -fsSL "$SKILL_URL" -o "$TARGET"; then
  echo "failed to download shield (is the repo reachable?)" >&2
  exit 1
fi

if [ "$UPDATED" = "1" ]; then
  echo "shield updated: $TARGET"
else
  echo "shield installed: $TARGET"
fi
echo "Run /shield in any project to audit it."