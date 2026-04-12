#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.swift$' || true)
TMP_DIR="$(mktemp -d /tmp/mobile_project_pre_commit.XXXXXX)"
SWIFTFORMAT_CONFIG="$REPO_ROOT/.swiftformat"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

if [ -z "$STAGED_SWIFT_FILES" ]; then
  echo "[pre-commit] 没有暂存的 Swift 文件，跳过格式检查。"
  exit 0
fi

echo "[pre-commit] 开始检查 Swift 格式..."

has_error=0
swiftformat_available=0

if command -v swiftformat >/dev/null 2>&1; then
  swiftformat_available=1
fi

while IFS= read -r file; do
  [ -n "$file" ] || continue

  safe_name="$(printf '%s' "$file" | tr '/ ' '__')"
  staged_copy="$TMP_DIR/$safe_name"
  git show ":$file" >"$staged_copy"

  tab_log="$TMP_DIR/$safe_name.tab.log"
  ws_log="$TMP_DIR/$safe_name.ws.log"

  if grep -n $'\t' "$staged_copy" >"$tab_log"; then
    echo "[pre-commit] 检测到 Tab 缩进，请改为空格: $file"
    cat "$tab_log"
    has_error=1
  fi

  if grep -nE ' +$' "$staged_copy" >"$ws_log"; then
    echo "[pre-commit] 检测到行尾空格，请清理: $file"
    cat "$ws_log"
    has_error=1
  fi

  if [ "$swiftformat_available" -eq 1 ]; then
    swiftformat_args=(--lint --cache ignore "$staged_copy")
    if [ -f "$SWIFTFORMAT_CONFIG" ]; then
      swiftformat_args+=(--config "$SWIFTFORMAT_CONFIG")
    fi

    if ! swiftformat "${swiftformat_args[@]}"; then
      has_error=1
    fi
  fi
done <<< "$STAGED_SWIFT_FILES"

if [ "$has_error" -ne 0 ]; then
  echo "[pre-commit] 格式检查失败。"
  if [ "$swiftformat_available" -ne 1 ]; then
    echo "[pre-commit] 可选增强: 安装 swiftformat 后将启用更完整检查。"
    echo "[pre-commit] 安装命令: brew install swiftformat"
  fi
  exit 1
fi

echo "[pre-commit] 格式检查通过。"
