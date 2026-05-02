# Monee

中文版本: [README_ZH.md](README_ZH.md)

`Monee` is a privacy-first, local-first iPhone bookkeeping app built natively with `SwiftUI`.

This repository is also the course project repo for `COMP7506B Smart Phone Apps Development (2026)` by Group 09.

## Snapshot

- App name: `Monee`
- Platform: `iPhone` + `WidgetKit`
- Language and UI stack: `Swift 5.7`, `SwiftUI`, `Charts`
- Architecture: MVVM-style views with a centralized `LedgerStore`
- Storage model: local JSON/UserDefaults persistence with optional iCloud key-value backup plumbing
- Smart features: screenshot OCR, App Shortcuts handoff, local parser fallback, optional OpenAI-compatible LLM parsing
- System integrations: `WidgetKit`, `Vision`, `Speech`, `AppIntents`, local notifications

## Current Status

The project is feature-complete for the course report scope. The current branch includes:

- quick expense and income entry
- dashboard, trend, ranking, and budget views
- books, accounts, categories, and settings management
- scheduled ledger templates and reminders
- saving plans with progress tracking
- app-wide search across records, books, categories, and quick actions
- CSV import and export flows
- local backup and restore
- optional iCloud key-value backup snapshot plumbing
- bilingual Chinese and English localization
- five widget surfaces
- Auto Ledger flows based on screenshot OCR, App Shortcuts, local fallback parsing, and optional LLM parsing
- local notifications for budgets and scheduled ledger entries

Detailed progress and known gaps live in [docs/project-status.md](docs/project-status.md).

## Repository Map

```text
mobile_project/                Main iOS app target
mobile_project/Models/         Shared business models
mobile_project/ViewModels/     State, persistence, and feature orchestration
mobile_project/Views/          SwiftUI screens and view-level composition
mobile_project/WidgetSupport/  App-to-widget snapshot bridge
mobile_project_widgets/        Widget extension target
docs/                          Report-aligned notes, status, and implementation docs
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

## Core Features

- Local-first bookkeeping with multiple books, accounts, categories, budgets, scheduled entries, and saving plans
- Calendar planning surface with budget context, recorded-entry markers, scheduled-ledger due dates, and reminders
- Auto Ledger screenshot recognition using App Shortcuts, Vision OCR, local parsing, and optional LLM parsing
- Search, CSV import/export, backup/restore, bilingual localization, and adaptive light/dark UI

## Widget and Shortcut Notes

The widget extension currently ships these surfaces:

- `today-expense`
- `budget-progress`
- `quick-action`
- `account-overview`
- `auto-ledger-status`

The app also exposes App Shortcuts for Auto Ledger so screenshots can be parsed and saved without reopening the app manually.

LLM configuration details are documented in [docs/auto-ledger-llm.md](docs/auto-ledger-llm.md).

## Build and Signing Notes

The repo can build locally under a Personal Team. Local persistence, local backup/restore, widgets, shortcuts, and notifications are implemented in code. Production iCloud behavior still depends on using a provisioning profile with the required iCloud entitlement.

## Testing and Validation

Project validation followed the report process:

- feature branches and pull requests for major work
- Xcode Simulator builds and manual acceptance checks
- persistence checks after app background/relaunch
- cross-device layout checks on multiple iPhone simulators
- Git hooks for formatting and scoped pre-push builds

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
