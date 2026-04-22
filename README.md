# Monee

中文版本: [README_ZH.md](README_ZH.md)

`Monee` is a privacy-first, local-first iPhone bookkeeping app built with `SwiftUI`.

This repository is also the course project repo for `COMP7506B Smart Phone Apps Development (2026)` by Group 09.

## Snapshot

- App name: `Monee`
- Platform: `iPhone` + `WidgetKit`
- UI stack: `SwiftUI` + `Charts`
- Storage model: local persistence first, cloud backup prepared but signing-limited
- Smart features: receipt OCR, App Shortcuts handoff, optional OpenAI-backed auto-ledger flow

## Current Status

The project is no longer just a bookkeeping shell. The current branch already includes:

- quick expense and income entry
- dashboard, trend, ranking, and budget views
- books, accounts, categories, and settings management
- CSV import and export flows
- local backup and restore
- iCloud backup snapshot plumbing, currently limited by Personal Team signing
- five widget surfaces
- Auto Ledger flows based on screenshot OCR, App Shortcuts, and optional LLM parsing

Detailed progress and known gaps live in [docs/project-status.md](docs/project-status.md).

## Repository Map

```text
mobile_project/                Main iOS app target
mobile_project/Models/         Shared business models
mobile_project/ViewModels/     State, persistence, and feature orchestration
mobile_project/Views/          SwiftUI screens and view-level composition
mobile_project/WidgetSupport/  App-to-widget snapshot bridge
mobile_project_widgets/        Widget extension target
docs/                          Project notes, status, and implementation docs
scripts/                       Local automation and helper scripts
.githooks/                     Git hook entrypoints
```

Directory-level notes:

- [mobile_project/README.md](mobile_project/README.md)
- [mobile_project_widgets/README.md](mobile_project_widgets/README.md)
- [docs/README.md](docs/README.md)

## Quick Start

Open in Xcode:

```bash
open mobile_project.xcodeproj
```

Build from the repo root:

```bash
xcodebuild -project mobile_project.xcodeproj \
  -scheme mobile_project \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ./.deriveddata \
  build
```

## Widget and Shortcut Notes

The widget extension currently ships these surfaces:

- `today-expense`
- `budget-progress`
- `quick-action`
- `account-overview`
- `auto-ledger-status`

The app also exposes App Shortcuts for Auto Ledger so screenshots can be parsed and saved without reopening the app manually.

LLM configuration details are documented in [docs/auto-ledger-llm.md](docs/auto-ledger-llm.md).

## Signing Limitation

The repo can build locally under a Personal Team, but full iCloud capability is still blocked by provisioning limits.

What is already done:

- local backup snapshot model
- restore flow
- iCloud-backed snapshot plumbing in the store

What is still blocked:

- enabling real iCloud entitlement and production-grade cloud backup

## Git Hooks

Install local hooks:

```bash
./scripts/install-git-hooks.sh
```

Hook details:

- [HOOKS.md](HOOKS.md)
- [scripts/README.md](scripts/README.md)

## Team

Group 09:

- Cao Kainan
- Li Ye
- Lin Ruiyi
