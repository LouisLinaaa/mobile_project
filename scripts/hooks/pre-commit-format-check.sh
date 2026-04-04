#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.swift$' || true)

if [ -z "$STAGED_SWIFT_FILES" ]; then
  echo "[pre-commit] 没有暂存的 Swift 文件，跳过格式检查。"
  exit 0
fi

echo "[pre-commit] 开始检查 Swift 格式..."

has_error=0

while IFS= read -r file; do
  if [ -f "$file" ]; then
    if grep -n $'\t' "$file" >/tmp/pre_commit_tab_check.log; then
      echo "[pre-commit] 检测到 Tab 缩进，请改为空格: $file"
      cat /tmp/pre_commit_tab_check.log
      has_error=1
    fi

    if grep -nE ' +$' "$file" >/tmp/pre_commit_ws_check.log; then
      echo "[pre-commit] 检测到行尾空格，请清理: $file"
      cat /tmp/pre_commit_ws_check.log
      has_error=1
    fi

    if command -v swiftformat >/dev/null 2>&1; then
      if ! swiftformat --lint "$file"; then
        has_error=1
      fi
    fi
  fi
done <<< "$STAGED_SWIFT_FILES"

if [ "$has_error" -ne 0 ]; then
  echo "[pre-commit] 格式检查失败。"
  if ! command -v swiftformat >/dev/null 2>&1; then
    echo "[pre-commit] 可选增强: 安装 swiftformat 后将启用更完整检查。"
    echo "[pre-commit] 安装命令: brew install swiftformat"
  fi
  exit 1
fi

echo "[pre-commit] 格式检查通过。"
