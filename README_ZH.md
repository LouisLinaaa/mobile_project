# Monee

English Version: [README.md](README.md)

`Monee` 是一个以隐私优先、本地优先为核心的 iPhone 记账应用，使用 `SwiftUI` 构建。

这个仓库同时也是 `COMP7506B Smart Phone Apps Development (2026)` Group 09 的课程项目仓库。

## 项目快照

- 产品名称：`Monee`
- 平台：`iPhone` + `WidgetKit`
- 技术栈：`SwiftUI` + `Charts`
- 数据策略：本地持久化优先，云备份结构已预埋但受签名限制
- 智能能力：账单 OCR、App Shortcuts 自动记账入口、可选 OpenAI 解析链路

## 当前进度

这个项目已经不只是一个记账 UI 原型，当前代码已经包含：

- 快速收入 / 支出记账
- 首页概览、趋势统计、排行和预算视图
- 账本、账户、分类、设置等管理模块
- CSV 导入 / 导出
- 本地备份与恢复
- 已接入状态层的 iCloud 备份快照逻辑，但受 Personal Team 签名限制
- 5 个 Widget 面板
- 基于截图 OCR、快捷指令和可选 LLM 的自动记账流程

更完整的阶段说明见 [docs/project-status.md](docs/project-status.md)。

## 仓库结构

```text
mobile_project/                主 iOS App Target
mobile_project/Models/         共享业务模型
mobile_project/ViewModels/     状态、持久化与业务编排
mobile_project/Views/          SwiftUI 页面与视图组合
mobile_project/WidgetSupport/  App 与 Widget 的快照桥接层
mobile_project_widgets/        Widget 扩展 Target
docs/                          项目文档、状态说明与实现笔记
scripts/                       本地脚本与辅助工具
.githooks/                     Git Hook 入口
```

目录说明入口：

- [mobile_project/README.md](mobile_project/README.md)
- [mobile_project_widgets/README.md](mobile_project_widgets/README.md)
- [docs/README.md](docs/README.md)

## 快速开始

使用 Xcode 打开：

```bash
open mobile_project.xcodeproj
```

在仓库根目录命令行构建：

```bash
xcodebuild -project mobile_project.xcodeproj \
  -scheme mobile_project \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ./.deriveddata \
  build
```

## Widget 与自动记账

当前 Widget 扩展包含以下面板：

- `today-expense`
- `budget-progress`
- `quick-action`
- `account-overview`
- `auto-ledger-status`

App 也已经暴露了自动记账相关的 App Shortcuts，可以直接接收截图、识别并保存，无需强制回跳主界面。

LLM 接入说明见 [docs/auto-ledger-llm.md](docs/auto-ledger-llm.md)。

## 签名限制

当前仓库可以在 Personal Team 下完成本地开发，但完整 iCloud 能力仍受签名限制。

已经完成：

- 本地备份快照模型
- 恢复流程
- 状态层中的 iCloud 快照读写逻辑

仍然受阻：

- 真正启用 iCloud entitlement
- 面向正式环境的云备份能力

## Git Hook

启用本地 Hook：

```bash
./scripts/install-git-hooks.sh
```

相关说明：

- [HOOKS.md](HOOKS.md)
- [scripts/README.md](scripts/README.md)

## 团队

Group 09：

- Cao Kainan
- Li Ye
- Lin Ruiyi
