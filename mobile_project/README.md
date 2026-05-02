# mobile_project

Main iOS app target for `Monee`.

## Responsibility

This target owns:

- app lifecycle entry
- local bookkeeping flows
- budgets, statistics, assets, saving plans, scheduled entries, and settings
- backup and restore UI
- Auto Ledger review, screenshot parsing, local fallback, and shortcut orchestration
- local notifications and bilingual localization support
- widget snapshot publishing

## Key Areas

- [MobileProjectApp.swift](MobileProjectApp.swift): app entry point
- [Models](Models/README.md): shared business models
- [ViewModels](ViewModels/README.md): state, persistence, import/export, backup, Auto Ledger
- [Views](Views/README.md): SwiftUI screens, management flows, search, calendar, saving plans, scheduled ledger, and feature composition
- [WidgetSupport](WidgetSupport/README.md): snapshot bridge for widgets

## Notes

- `Assets.xcassets/AppIcon.appiconset` only keeps generated icon assets required by Xcode
- branding source files are stored under [../docs/assets/branding](../docs/assets/branding)
- production iCloud behavior depends on using signing with the required iCloud entitlement
