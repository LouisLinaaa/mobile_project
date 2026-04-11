# scripts/hooks

中文 / Chinese:
Git Hook 的实际实现脚本目录。`.githooks/` 只负责入口转发，这里才是 pre-commit 和 pre-push 的真实检查逻辑。

English:
Implementation directory for Git hooks. `.githooks/` only contains entrypoints; the actual pre-commit and pre-push logic lives here.
