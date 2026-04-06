# COMP7506B Group Project (2026) - Group 09

中文版本: [README_ZH.md](README_ZH.md)

> Course: `COMP7506B Smart Phone Apps Development`  
> Project theme: `Developing a smart phone application from scratch`  
> Product: `Privacy-first local bookkeeping app for iPhone`

## Team

**Group 09** (`3 / 6 members`)

- Cao Kainan
- Li Ye
- Lin Ruiyi

## Overview

This repository contains an iOS bookkeeping prototype built with `SwiftUI`.

The product direction is:

- privacy-first and local-first
- fast daily bookkeeping with low interaction cost
- modular management screens for books, assets, categories, settings, widgets, and automation
- a backup foundation that can later be upgraded to real cloud sync

The current prototype already includes:

- quick expense and income entry
- home dashboard with monthly overview
- statistics dashboard with charts and rankings
- asset account management
- book management
- category scheme management
- widget center and widget target
- settings, privacy, and backup entry
- local persisted app state

## Current Product Status

| Area | Status | Notes |
|---|---|---|
| Core app architecture | Done | SwiftUI + centralized state store |
| Quick bookkeeping flow | Done | Expense and income entry available |
| Statistics dashboard | Done | Trend, ranking, and category composition |
| Book / asset / category management | Done | Core CRUD-style flows available |
| Widget support | Done | Shared widget target and debug scheme included |
| Local persistence foundation | Done | State is persisted locally |
| Backup and restore entry | In progress | UI and data snapshot flow are in place |
| iCloud backup capability | Blocked by signing | Personal Team cannot enable iCloud entitlement |
| Automation and AI features | Planned | Product direction retained for later iteration |

## What Makes This Project Different

### Privacy by default

- User data is designed to stay local by default.
- Sensitive display options can be controlled in settings.
- External services are not required for the core bookkeeping flow.

### Daily usability first

- The prototype focuses on quick entry, clear summaries, and lightweight management flows.
- Widgets and management panels are organized around common daily finance tasks instead of heavy enterprise-style workflows.

### Backup-aware design

- The app now includes a backup and restore entry in settings.
- Full iCloud capability is not enabled in the current signing environment, but the backup UI and snapshot model are already prepared for future activation.

## Background Research

At least three related products were reviewed during early exploration:

1. Money Manager
2. Spendee
3. Wallet by BudgetBakers

Common strengths:

- mature charts and budgeting patterns
- multi-account support
- recurring transaction support

Common gaps we want to avoid:

- privacy concerns caused by mandatory cloud sync
- heavy UI and subscription pressure
- weak local intelligence for personal bookkeeping workflows

## Tech Stack

- `SwiftUI` for app UI
- `Charts` for statistics visualization
- `WidgetKit` for widgets
- `xcodebuild` for command-line build validation
- local persistence via the app state store and on-device storage

## Repository Structure

```text
mobile_project/              Main iOS app target
mobile_project_widgets/      Widget extension target
scripts/hooks/               Hook implementation scripts
.githooks/                   Git hook entrypoints
HOOKS.md                     Hook-specific notes
README.md                    English README
README_ZH.md                 Chinese README
```

## Build and Run

### Open in Xcode

```bash
open mobile_project.xcodeproj
```

### Build from command line

From the project root:

```bash
xcodebuild -project mobile_project.xcodeproj \
  -scheme mobile_project \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ./DerivedData \
  build
```

### Widget debugging in Xcode

- Use scheme `mobile_project` for the main app.
- A shared scheme `mobile_project_widgets` is included for widget debugging.
- To switch widget type:
  - open `Product -> Scheme -> Edit Scheme -> Run -> Arguments -> Environment Variables`
  - update `_XCWidgetKind`

Supported widget kinds currently include:

- `com.github.louislinaa.ledgerlab.widget.today-expense`
- `com.github.louislinaa.ledgerlab.widget.budget-progress`
- `com.github.louislinaa.ledgerlab.widget.quick-action`
- `com.github.louislinaa.ledgerlab.widget.account-overview`
- `com.github.louislinaa.ledgerlab.widget.auto-ledger-status`

## Signing and iCloud Note

The current repository can build and run under a Personal Team for local development.

However:

- Personal Team provisioning does **not** support the iCloud capability.
- Because of that, the backup screen currently acts as a prepared entry and local snapshot flow, not as a fully enabled iCloud sync feature.
- If the project is moved to a paid Apple Developer team later, the iCloud entitlement and capability can be re-enabled for real cloud backup.

## Git Hooks

This repository includes built-in Git hooks for safer daily collaboration.

### Install hooks

```bash
./scripts/install-git-hooks.sh
```

This sets:

```bash
git config core.hooksPath .githooks
```

### What the hooks do

`pre-commit`

- checks only the **staged** `.swift` content
- blocks tab indentation and trailing whitespace
- optionally runs `swiftformat --lint` when `swiftformat` is installed

`pre-push`

- runs an iOS build check only when pushed commits touch app or Xcode project files
- skips the build for docs-only or non-iOS changes
- prints recent build log output directly when the build fails

### Optional tool

```bash
brew install swiftformat
```

### Manual verification

```bash
bash .githooks/pre-commit
bash .githooks/pre-push
```

### Temporary skip for pre-push build

```bash
SKIP_XCODE_BUILD_HOOK=1 git push
```

Use this only when you already understand the risk and intentionally want to bypass the local build gate.

## Course Deliverables Checklist

- [ ] Project document (>= 2 pages): background research, app summary, member contribution
- [x] Source code with build and run instructions
- [ ] Introductory video (1-2 minutes)

## Upcoming Work

- [ ] polish backup and restore UX under the current signing limitation
- [ ] enable real iCloud backup after moving to a supported Apple Developer team
- [ ] add recurring transaction / automation engine
- [ ] add AI parsing and assistant-related flows
- [ ] finish project report and contribution breakdown
- [ ] record and submit the demo video

---

This README is maintained as the main project landing page for the current prototype state.
