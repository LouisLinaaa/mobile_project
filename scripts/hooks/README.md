# scripts/hooks

中文 / Chinese:
Git Hook 的实际实现脚本目录。`.githooks/` 只负责入口转发，这里才是 pre-commit 格式检查和 pre-push Xcode 构建检查的真实逻辑。

English:
Implementation directory for Git hooks. `.githooks/` only contains entrypoints; the actual pre-commit format check and pre-push Xcode build check logic lives here.
