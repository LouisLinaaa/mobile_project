#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.swift$' || true)
TMP_DIR="$(mktemp -d /tmp/mobile_project_pre_commit.XXXXXX)"
SWIFTFORMAT_CONFIG="$REPO_ROOT/.swiftformat"
SWIFT_VERSION_FILE="$REPO_ROOT/.swift-version"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

if [ -z "$STAGED_SWIFT_FILES" ]; then
  echo "[pre-commit] 没有暂存的 Swift 文件，跳过格式检查。"
  exit 0
fi

echo "[pre-commit] 开始检查 Swift 格式..."

should_run_swiftformat=0
swiftformat_args=()

if command -v swiftformat >/dev/null 2>&1; then
  if [ -f "$SWIFTFORMAT_CONFIG" ]; then
    should_run_swiftformat=1
    swiftformat_args+=(--config "$SWIFTFORMAT_CONFIG")

    if [ -f "$SWIFT_VERSION_FILE" ]; then
      swift_version="$(tr -d '[:space:]' < "$SWIFT_VERSION_FILE")"
      if [ -n "$swift_version" ]; then
        swiftformat_args+=(--swiftversion "$swift_version")
      fi
    fi
  else
    echo "[pre-commit] 检测到 swiftformat，但仓库未配置 .swiftformat，跳过默认规则 lint。"
    echo "[pre-commit] 这样可以避免历史文件因默认规则不一致而阻塞提交。"
  fi
fi

has_error=0

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

  if [ "$should_run_swiftformat" -eq 1 ]; then
    if ! swiftformat --lint "${swiftformat_args[@]}" "$staged_copy"; then
      has_error=1
    fi
  fi
done <<< "$STAGED_SWIFT_FILES"

if [ "$has_error" -ne 0 ]; then
  echo "[pre-commit] 格式检查失败。"
  if ! command -v swiftformat >/dev/null 2>&1; then
    echo "[pre-commit] 可选增强: 安装 swiftformat 后将启用更完整检查。"
    echo "[pre-commit] 安装命令: brew install swiftformat"
  elif [ ! -f "$SWIFTFORMAT_CONFIG" ]; then
    echo "[pre-commit] 当前失败来自基础空白字符检查，不是 SwiftFormat 默认规则。"
  fi
  exit 1
fi

echo "[pre-commit] 格式检查通过。"
