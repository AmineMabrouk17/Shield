#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$REPO_DIR/.agents/skills/shield"
TARGET="${HOME}/.agents/skills/shield"

if [ ! -d "$SOURCE" ]; then
  echo "error: skill source not found at $SOURCE" >&2
  exit 1
fi

mkdir -p "${HOME}/.agents/skills"

if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
  echo "error: $TARGET already exists and is not a symlink (remove it first, or run with FORCE=1 to replace with a symlink)." >&2
  exit 1
fi

if [ -L "$TARGET" ] && [ "$(readlink "$TARGET")" = "$SOURCE" ]; then
  echo "shield already installed: $TARGET -> $SOURCE"
  exit 0
fi

if [ -L "$TARGET" ] && [ "${FORCE:-0}" != "1" ]; then
  echo "warning: $TARGET currently points at $(readlink "$TARGET"); run with FORCE=1 to re-point it." >&2
  exit 1
fi

ln -sfn "$SOURCE" "$TARGET"
echo "shield installed: $TARGET -> $SOURCE"
echo "Run /shield in any project to audit it."