#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

PROJECT_PATH="mobile_project.xcodeproj"
SCHEME="mobile_project"
DERIVED_DATA_PATH="/tmp/mobile_project_hook_derived"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "[pre-push] 未找到 xcodebuild，无法执行构建检查。"
  exit 1
fi

if [ ! -d "$PROJECT_PATH" ]; then
  echo "[pre-push] 找不到项目文件: $PROJECT_PATH"
  exit 1
fi

echo "[pre-push] 开始执行构建检查..."

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build >/tmp/mobile_project_pre_push_build.log 2>&1

echo "[pre-push] 构建检查通过。"
