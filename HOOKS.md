# Git Hooks (Format + Build Check)

本项目已内置 Git Hook：

- `pre-commit`: 检查暂存的 `.swift` 文件格式
  - 必查: Tab 缩进、行尾空格
  - 可选增强: 若本机安装 `swiftformat`，自动执行 `swiftformat --lint`
- `pre-push`: 执行 iOS 构建检查（`xcodebuild build`）

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

## 手动验证

```bash
bash .githooks/pre-commit
bash .githooks/pre-push
```
