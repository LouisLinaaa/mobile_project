# COMP7506B 小组项目（2026）- Group 09

English Version: [README.md](README.md)

> 课程：`COMP7506B Smart Phone Apps Development`  
> 项目主题：`Developing a smart phone application from scratch`  
> 项目产品：`以隐私和本地优先为核心的 iPhone 记账应用`

## 小组信息

**Group 09**（`3 / 6 members`）

- Cao Kainan
- Li Ye
- Lin Ruiyi

## 项目概览

本仓库是一个使用 `SwiftUI` 构建的 iOS 记账原型项目。

当前产品方向聚焦在：

- 隐私优先、本地优先
- 降低日常记账操作成本
- 围绕账本、资产、分类、设置、组件、自动化等模块化管理
- 先完成备份基础能力，再为后续真实云同步预留接口

当前原型已经支持：

- 快速收入 / 支出记账
- 首页月度概览
- 图表统计与排行
- 资产账户管理
- 账本管理
- 分类方案管理
- Widget 中心与 Widget Target
- 设置、隐私、安全与备份入口
- 本地状态持久化

## 当前项目状态

| 模块 | 状态 | 说明 |
|---|---|---|
| 核心架构 | 已完成 | SwiftUI + 集中式状态管理 |
| 快速记账流程 | 已完成 | 已支持收入与支出录入 |
| 图表统计模块 | 已完成 | 趋势、排行、分类构成已具备 |
| 账本 / 资产 / 分类管理 | 已完成 | 核心管理流程可用 |
| Widget 支持 | 已完成 | 已包含独立 Widget target 与调试 scheme |
| 本地持久化基础 | 已完成 | 当前状态可本地保存 |
| 备份与恢复入口 | 开发中 | 页面与快照模型已经具备 |
| iCloud 备份能力 | 被签名环境阻塞 | Personal Team 无法启用 iCloud entitlement |
| 自动化与 AI 能力 | 计划中 | 作为后续迭代方向保留 |

## 项目差异化方向

### 1. 隐私优先

- 用户数据默认尽量保留在本地。
- 敏感信息展示可以在设置中控制。
- 核心记账流程不依赖外部服务。

### 2. 日常可用性优先

- 原型优先解决“快速记一笔”和“快速看清状态”。
- Widget 和管理面板围绕高频个人财务场景设计，而不是做成复杂的重型流程。

### 3. 备份意识前置

- 设置页里已经加入备份与恢复入口。
- 当前签名环境还不能真正启用 iCloud，但 UI、文案与快照模型已经为后续接入做好准备。

## 背景调研

前期至少调研了三个相关产品：

1. Money Manager
2. Spendee
3. Wallet by BudgetBakers

这些产品的共性优势：

- 图表和预算能力成熟
- 多账户支持较完整
- 周期性交易能力较强

我们希望避免的共性问题：

- 强制云同步带来的隐私顾虑
- 过重的界面和订阅压力
- 对本地记账场景支持不够自然

## 技术栈

- `SwiftUI`：主应用界面
- `Charts`：图表统计
- `WidgetKit`：桌面组件
- `xcodebuild`：命令行构建验证
- 本地状态存储：通过状态仓库与设备侧持久化实现

## 仓库结构

```text
mobile_project/              主 iOS App Target
mobile_project_widgets/      Widget 扩展 Target
scripts/hooks/               Hook 实现脚本
.githooks/                   Git Hook 入口
HOOKS.md                     Hook 说明文档
README.md                    英文 README
README_ZH.md                 中文 README
```

## 编译与运行

### 使用 Xcode 打开

```bash
open mobile_project.xcodeproj
```

### 命令行构建

在项目根目录执行：

```bash
xcodebuild -project mobile_project.xcodeproj \
  -scheme mobile_project \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ./DerivedData \
  build
```

### 在 Xcode 中调试 Widget

- 主应用请使用 scheme `mobile_project`
- 仓库已提供共享 scheme `mobile_project_widgets`
- 如需切换 Widget 类型：
  - 打开 `Product -> Scheme -> Edit Scheme -> Run -> Arguments -> Environment Variables`
  - 修改 `_XCWidgetKind`

当前支持的 Widget Kind 包括：

- `com.github.louislinaa.ledgerlab.widget.today-expense`
- `com.github.louislinaa.ledgerlab.widget.budget-progress`
- `com.github.louislinaa.ledgerlab.widget.quick-action`
- `com.github.louislinaa.ledgerlab.widget.account-overview`
- `com.github.louislinaa.ledgerlab.widget.auto-ledger-status`

## 签名与 iCloud 说明

当前仓库可以在 Personal Team 下完成本地开发和运行。

但需要注意：

- Personal Team **不支持** iCloud capability
- 因此当前备份页面主要是“入口与快照基础能力”，不是真正已启用的 iCloud 云备份
- 如果后续切换到付费 Apple Developer 团队，可以重新打开 iCloud entitlement，把真实云备份接回

## Git Hook 使用说明

仓库内已经内置 Git Hook，用于提升协作过程中的稳定性。

### 启用 Hook

```bash
./scripts/install-git-hooks.sh
```

脚本会写入：

```bash
git config core.hooksPath .githooks
```

### Hook 行为

`pre-commit`

- 只检查 **已暂存** 的 `.swift` 内容
- 拦截 Tab 缩进和行尾空格
- 如果本机安装了 `swiftformat`，会额外执行 `swiftformat --lint`

`pre-push`

- 仅当本次推送涉及 App / Widget / Xcode 工程文件时才执行构建检查
- 文档类改动不会强制跑一轮 iOS 构建
- 构建失败时会直接打印最近日志，并给出完整日志路径

### 推荐安装

```bash
brew install swiftformat
```

### 手动验证

```bash
bash .githooks/pre-commit
bash .githooks/pre-push
```

### 临时跳过 pre-push 构建检查

```bash
SKIP_XCODE_BUILD_HOOK=1 git push
```

仅建议在你已经明确知道风险，并且只是临时绕过本地构建门禁时使用。

## 课程交付物清单

- [ ] 项目文档（不少于 2 页）：竞品调研、应用总结、成员贡献
- [x] 源代码（含编译和运行说明）
- [ ] 1-2 分钟功能演示视频

## 下一阶段计划

- [ ] 在当前签名限制下继续打磨备份与恢复体验
- [ ] 切换到支持 iCloud 的开发者团队后接入真实云备份
- [ ] 实现周期记账与自动化规则引擎
- [ ] 增加 AI 解析与助手相关流程
- [ ] 完成课程报告与成员贡献说明
- [ ] 录制并提交演示视频

---

本 README 作为当前原型状态的主入口文档持续维护。
