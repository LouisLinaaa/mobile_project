# Git Hooks (Format + Build Check)

本项目已内置 Git Hook：

- `pre-commit`: 检查暂存的 `.swift` 文件格式
  - 必查: staged 内容中的 Tab 缩进、行尾空格
  - 可选增强: 若本机安装 `swiftformat`，自动对 staged 内容执行 `swiftformat --lint`
- `pre-push`: 按改动范围执行 iOS 构建检查（`xcodebuild build`）
  - 仅当推送内容涉及 App、Widget 或 Xcode 工程文件时才会执行
  - 失败时会直接打印最近日志，并给出完整日志路径与复现命令

## 启用

```bash
./scripts/install-git-hooks.sh
```

启用后会写入：

```bash
git config core.hooksPath .githooks
```

## 可选增强（推荐）

```bash
brew install swiftformat
```

安装后，`pre-commit` 会自动启用更严格的 Swift 格式校验。

## 临时跳过

```bash
SKIP_XCODE_BUILD_HOOK=1 git push
```

仅建议在你明确知道失败原因、且只是临时绕过本地检查时使用。

## 手动验证

```bash
bash .githooks/pre-commit
bash .githooks/pre-push
```
