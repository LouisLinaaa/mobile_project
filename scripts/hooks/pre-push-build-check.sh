#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

PROJECT_PATH="mobile_project.xcodeproj"
SCHEME="mobile_project"
DERIVED_DATA_PATH="${HOOK_DERIVED_DATA_PATH:-/tmp/mobile_project_hook_derived}"
BUILD_LOG_PATH="${HOOK_BUILD_LOG_PATH:-/tmp/mobile_project_pre_push_build.log}"
DEFAULT_BASE_REF="${HOOK_DEFAULT_BASE_REF:-origin/main}"

if [ "${SKIP_XCODE_BUILD_HOOK:-0}" = "1" ]; then
  echo "[pre-push] 已通过 SKIP_XCODE_BUILD_HOOK=1 跳过构建检查。"
  exit 0
fi

should_check_build_for_file() {
  case "$1" in
    mobile_project/*|mobile_project_widgets/*|mobile_project.xcodeproj/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

collect_changed_files_for_range() {
  local range="$1"
  git diff --name-only "$range" -- || true
}

collect_push_changed_files() {
  local files=""
  local local_ref local_sha remote_ref remote_sha zero_sha base_sha
  zero_sha="0000000000000000000000000000000000000000"

  while read -r local_ref local_sha remote_ref remote_sha; do
    [ -n "${local_sha:-}" ] || continue

    if [ "$local_sha" = "$zero_sha" ]; then
      continue
    fi

    if [ "$remote_sha" = "$zero_sha" ]; then
      if git show-ref --verify --quiet "refs/remotes/$DEFAULT_BASE_REF"; then
        base_sha="$(git merge-base "$local_sha" "$DEFAULT_BASE_REF")"
        files+=$'\n'"$(collect_changed_files_for_range "$base_sha..$local_sha")"
      elif git rev-parse --verify "${local_sha}^" >/dev/null 2>&1; then
        files+=$'\n'"$(collect_changed_files_for_range "${local_sha}^..$local_sha")"
      else
        files+=$'\n'"$(git diff-tree --no-commit-id --name-only -r "$local_sha" -- || true)"
      fi
    else
      files+=$'\n'"$(collect_changed_files_for_range "$remote_sha..$local_sha")"
    fi
  done

  if [ -z "${files//$'\n'/}" ]; then
    if git rev-parse --verify "@{upstream}" >/dev/null 2>&1; then
      collect_changed_files_for_range "@{upstream}...HEAD"
      return
    fi
    if git show-ref --verify --quiet "refs/remotes/$DEFAULT_BASE_REF"; then
      base_sha="$(git merge-base HEAD "$DEFAULT_BASE_REF")"
      collect_changed_files_for_range "$base_sha..HEAD"
      return
    fi
  fi

  printf '%s\n' "$files" | sed '/^$/d' | sort -u
}

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "[pre-push] 未找到 xcodebuild，无法执行构建检查。"
  exit 1
fi

if [ ! -d "$PROJECT_PATH" ]; then
  echo "[pre-push] 找不到项目文件: $PROJECT_PATH"
  exit 1
fi

CHANGED_FILES="$(collect_push_changed_files)"
NEEDS_BUILD=0

while IFS= read -r file; do
  [ -n "$file" ] || continue
  if should_check_build_for_file "$file"; then
    NEEDS_BUILD=1
    break
  fi
done <<< "$CHANGED_FILES"

if [ "$NEEDS_BUILD" -ne 1 ]; then
  echo "[pre-push] 本次推送未涉及 iOS 工程代码，跳过构建检查。"
  exit 0
fi

echo "[pre-push] 开始执行构建检查..."

if ! xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build >"$BUILD_LOG_PATH" 2>&1; then
  echo "[pre-push] 构建检查失败。最近日志如下："
  tail -n 80 "$BUILD_LOG_PATH" || true
  echo "[pre-push] 完整日志: $BUILD_LOG_PATH"
  echo "[pre-push] 可手动复现:"
  echo "xcodebuild -project \"$PROJECT_PATH\" -scheme \"$SCHEME\" -destination 'generic/platform=iOS Simulator' -derivedDataPath \"$DERIVED_DATA_PATH\" build"
  exit 1
fi

echo "[pre-push] 构建检查通过。"
