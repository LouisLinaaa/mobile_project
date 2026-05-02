# Monee

English Version: [README.md](README.md)

`Monee` 是一个以隐私优先、本地优先为核心的 iPhone 原生记账应用，使用 `SwiftUI` 构建。

这个仓库同时也是 `COMP7506B Smart Phone Apps Development (2026)` Group 09 的课程项目仓库。

## 项目快照

- 产品名称：`Monee`
- 平台：`iPhone` + `WidgetKit`
- 技术栈：`Swift 5.7`、`SwiftUI`、`Charts`
- 架构：MVVM 风格视图层 + 集中的 `LedgerStore` 状态管理
- 数据策略：本地 JSON / UserDefaults 持久化，预留可选 iCloud key-value 备份链路
- 智能能力：截图 OCR、App Shortcuts 自动记账入口、本地解析兜底、可选 OpenAI 兼容 LLM 解析
- 系统集成：`WidgetKit`、`Vision`、`Speech`、`AppIntents`、本地通知

## 当前进度

这个项目已经完成课程报告范围内的主要功能，当前代码包含：

- 快速收入 / 支出记账
- 首页概览、趋势统计、排行和预算视图
- 账本、账户、分类、设置等管理模块
- 定期账单模板与提醒
- 储蓄计划与进度展示
- 面向记录、账本、分类和快捷入口的全局搜索
- CSV 导入 / 导出
- 本地备份与恢复
- 可选 iCloud key-value 备份快照逻辑
- 中英文双语本地化
- 5 个 Widget 面板
- 基于截图 OCR、快捷指令、本地兜底解析和可选 LLM 的自动记账流程
- 用于预算和定期账单的本地通知

更完整的阶段说明见 [docs/project-status.md](docs/project-status.md)。

## 仓库结构

```text
mobile_project/                主 iOS App Target
mobile_project/Models/         共享业务模型
mobile_project/ViewModels/     状态、持久化与业务编排
mobile_project/Views/          SwiftUI 页面与视图组合
mobile_project/WidgetSupport/  App 与 Widget 的快照桥接层
mobile_project_widgets/        Widget 扩展 Target
docs/                          与报告对齐的项目文档、状态说明与实现笔记
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

## 核心功能

- 多账本、账户、分类、预算、定期账单和储蓄计划的本地优先记账体系
- 日历规划界面，整合预算状态、记账日期标记、定期账单到期日和提醒
- 通过 App Shortcuts、Vision OCR、本地解析和可选 LLM 实现截图自动记账
- 搜索、CSV 导入 / 导出、备份 / 恢复、双语本地化和自适应明暗模式 UI

## Widget 与自动记账

当前 Widget 扩展包含以下面板：

- `today-expense`
- `budget-progress`
- `quick-action`
- `account-overview`
- `auto-ledger-status`

App 也已经暴露了自动记账相关的 App Shortcuts，可以直接接收截图、识别并保存，无需强制回跳主界面。

LLM 接入说明见 [docs/auto-ledger-llm.md](docs/auto-ledger-llm.md)。

## 构建与签名说明

当前仓库可以在 Personal Team 下完成本地开发。本地持久化、本地备份 / 恢复、Widget、快捷指令和本地通知都已经在代码中实现。正式 iCloud 行为仍取决于是否使用带有 iCloud entitlement 的 provisioning profile。

## 测试与验证

项目验证方式与报告保持一致：

- 主要功能通过 feature branch 和 pull request 开发
- 使用 Xcode Simulator 构建并进行手动验收
- 通过后台 / 重启验证本地持久化
- 在多个 iPhone 模拟器上检查布局适配
- 通过 Git hook 执行格式检查和按改动范围触发的 pre-push 构建

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

Lin Ruiyi 的报告贡献摘要：

- 整体系统架构和核心 App 基础
- 初始 UI 与管理流程
- Widget 扩展、快照同步、签名和构建修复
- 设置、个人资料、备份 / 恢复、预算、Auto Ledger、本地通知、双语本地化、品牌、文档和构建工具
