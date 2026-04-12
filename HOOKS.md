# Git Hooks (Format + Build Check)

本项目已内置 Git Hook：

- `pre-commit`: 检查暂存的 `.swift` 文件格式
  - 必查: staged 内容中的 Tab 缩进、行尾空格
  - 可选增强: 若本机安装 `swiftformat`，自动按仓库根目录的 `.swiftformat` 对 staged 内容执行 `swiftformat --lint`
  - 若未配置 `.swiftformat`，Hook 会明确提示并跳过默认规则 lint，避免历史风格差异阻塞提交
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

安装后，再补充项目级 `.swiftformat`，`pre-commit` 才会启用更严格的 Swift 格式校验。

建议同时添加：

```bash
echo "5.7" > .swift-version
```

这样 SwiftFormat 会按工程声明的 Swift 版本工作，避免默认版本推断带来的噪音。

项目已补充：

- `.swift-version`: 统一 Swift 版本提示，避免 `swiftformat` 使用默认猜测
- `.swiftformat`: 固定本仓库使用的格式规则，避免误用默认规则导致无关拦截

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
