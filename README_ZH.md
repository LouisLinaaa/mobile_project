# COMP7506B 小组项目（2026）- Group 09

English Version: [README.md](README.md)

> 课程：`COMP7506B Smart Phone Apps Development`  
> 项目主题：`Developing a smart phone application from scratch`  
> 项目产品：`以隐私为核心的本地记账 iOS 应用`

## 小组信息

**Group 09**（`3 / 6 members`）

- Cao Kainan
- Li Ye
- Lin Ruiyi

## 项目简介

本项目开发一款轻量但实用的 iOS 记账应用，核心目标是 **隐私保护**、**本地优先** 和 **日常高频可用性**。

当前原型已经支持：

- 快速收入/支出记账
- 月度概览卡片
- 账本管理
- 资产账户管理
- 分类方案管理
- 图表统计（趋势、排行、分类构成）

## 作业要求映射（根据课程说明）

### 关键时间

- 组队截止：**2026-02-22（周日）**
- 课堂演示：**2026-04-30（周四）**
- 最终提交：**2026-05-03（周日）23:59（HKT）**

### 交付物清单

- [ ] 项目文档（不少于 2 页）：竞品调研、应用总结、成员贡献
- [x] 源代码（含编译与运行说明）
- [ ] 1-2 分钟功能演示视频

## 项目进度

| 模块 | 状态 | 进度 |
|---|---|---|
| 核心架构（SwiftUI + 状态管理） | 已完成 | 100% |
| 快速记账流程 | 已完成 | 90% |
| 图表统计模块 | 已完成 | 85% |
| 资产管理模块 | 已完成 | 85% |
| 账本管理模块 | 已完成 | 85% |
| 分类管理模块 | 已完成 | 85% |
| 本地持久化（SwiftData/CoreData） | 开发中 | 30% |
| 自动化能力 | 计划中 | 20% |
| AI 能力 | 计划中 | 20% |
| 文档与演示视频 | 计划中 | 15% |

## 背景调研（初版）

已调研至少 3 个相关产品：

1. **Money Manager**
2. **Spendee**
3. **Wallet by BudgetBakers**

### 共性优势

- 图表和预算能力成熟
- 支持多账户
- 支持周期性流水

### 共性不足

- 云同步和第三方统计带来隐私顾虑
- 功能较重，广告/订阅压力较大
- 本地 AI 辅助记账能力较弱

### 我们的差异化方向

- **本地优先的隐私模型**（可仅在设备端存储）
- **自动化优先的日常流程**（规则与定时记账）
- **AI 辅助交互**（自然语言记账与智能分析）

## 创新点

### 1）AI 功能（计划中）

- 自然语言记账  
  例：`今天午饭 48 港币，支付宝支付` -> 自动解析金额、分类与支付方式
- 基于历史记录的智能分类推荐
- 月度消费总结与建议（自然语言输出）

### 2）自动化功能（计划中）

- 周期性流水自动生成（房租、工资、订阅等）
- 规则引擎自动分类/打标签
- 周报/月报自动生成（趋势快照）

### 3）隐私设计

- 默认设备本地存储
- 可选应用锁 / Face ID
- 最小化外部依赖与数据暴露

## 技术栈

- `SwiftUI`（iOS 界面）
- `Charts`（数据可视化）
- `Xcode` / `xcodebuild`
- 计划：`SwiftData` 本地持久化

## 编译与运行

在项目根目录执行：

```bash
xcodebuild -project mobile_project.xcodeproj \
  -scheme mobile_project \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath ./DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

使用 Xcode 打开工程：

```bash
open mobile_project.xcodeproj
```

### 在 Xcode 中调试 Widget

- 日常运行/调试 App 请使用 scheme `mobile_project`。
- 仓库已提供共享 scheme `mobile_project_widgets`，并预置：
  - `_XCWidgetKind=com.github.louislinaa.ledgerlab.widget.today-expense`
- 如需切换调试其他 widget，进入：
  - `Product -> Scheme -> Edit Scheme -> Run -> Arguments -> Environment Variables`
  - 将 `_XCWidgetKind` 改成以下任一值：
    - `com.github.louislinaa.ledgerlab.widget.today-expense`
    - `com.github.louislinaa.ledgerlab.widget.budget-progress`
    - `com.github.louislinaa.ledgerlab.widget.quick-action`
    - `com.github.louislinaa.ledgerlab.widget.account-overview`
    - `com.github.louislinaa.ledgerlab.widget.auto-ledger-status`

## 下一阶段计划

- [ ] 接入本地持久化（SwiftData）
- [ ] 实现周期记账与自动化规则引擎
- [ ] 接入 AI 解析与 AI 助手入口
- [ ] 完成课程报告（含成员贡献表）
- [ ] 录制并提交 1-2 分钟演示视频

---

本 README 作为 Group 09 的项目进度与交付说明页面持续更新。
