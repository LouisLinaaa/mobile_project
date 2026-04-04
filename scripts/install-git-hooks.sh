#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

chmod +x .githooks/pre-commit .githooks/pre-push
chmod +x scripts/hooks/pre-commit-format-check.sh scripts/hooks/pre-push-build-check.sh

git config core.hooksPath .githooks

echo "Git hooks 已启用: $(git config --get core.hooksPath)"
