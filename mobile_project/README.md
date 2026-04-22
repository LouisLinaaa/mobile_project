# mobile_project

Main iOS app target for `Monee`.

## Responsibility

This target owns:

- app lifecycle entry
- local bookkeeping flows
- budgets, statistics, assets, and settings
- backup and restore UI
- Auto Ledger review and orchestration
- widget snapshot publishing

## Key Areas

- [MobileProjectApp.swift](MobileProjectApp.swift): app entry point
- [Models](Models/README.md): shared business models
- [ViewModels](ViewModels/README.md): state, persistence, import/export, backup, Auto Ledger
- [Views](Views/README.md): SwiftUI screens and feature composition
- [WidgetSupport](WidgetSupport/README.md): snapshot bridge for widgets

## Notes

- `Assets.xcassets/AppIcon.appiconset` only keeps generated icon assets required by Xcode
- branding source files are stored under [../docs/assets/branding](../docs/assets/branding)
