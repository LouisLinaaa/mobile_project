# Project Status

Last updated: `2026-05-03`

## Product Position

`Monee` is a privacy-first, local-first personal bookkeeping app for iPhone.

The final course-report build focuses on three priorities:

- fast daily bookkeeping
- clear budget and asset visibility
- privacy-aware automation that does not require always-on cloud services

## Feature Status

### Core bookkeeping

- expense and income entry
- home dashboard with monthly summary and navigation shortcuts
- books, accounts, and category scheme management
- payment methods, notes, tags, and ledger history
- persistent local app state

### Analysis and planning

- monthly budget setup
- dynamic daily budget calculation
- category-level budget views
- saving plans with deposits, withdrawals, and progress display
- scheduled ledger entries with daily, weekly, monthly, and yearly recurrence
- calendar surface with recorded-entry markers, daily budget context, and scheduled-entry reminders
- statistics charts and ranking views

### Data movement

- CSV export
- CSV import with book-aware insertion
- local backup snapshot and restore
- optional iCloud key-value snapshot read and write paths in `LedgerStore`

### Widget support

- today expense widget
- budget progress widget
- quick action widget
- account overview widget
- auto-ledger status widget

### Auto Ledger

- local OCR-based receipt parsing foundation
- screenshot handoff through App Shortcuts
- direct save flow for shortcut-triggered automatic bookkeeping
- optional OpenAI-compatible LLM parsing via environment or `Info.plist` configuration
- shared local parser fallback for automatic bookkeeping and in-app AI bookkeeping
- voice bookkeeping tab with local `Speech.framework` transcription and the same local parser-backed review flow

### Search, localization, and system integration

- app-wide search over records, books, categories, and quick actions
- Chinese and English localization through `.strings`
- adaptive light/dark mode contrast improvements
- local notifications for budget warnings and scheduled ledger reminders
- App Shortcuts and AppIntents entry points for Auto Ledger automation

## Architecture Notes

- The app uses Swift 5.7, SwiftUI, Charts, WidgetKit, Vision, Speech, AppIntents, and local notifications.
- `LedgerStore` is the centralized `@MainActor` state manager and persistence boundary.
- Data models are `Codable` and persist through local snapshots, UserDefaults/App Group data, and optional iCloud key-value backup.
- Widgets consume explicit snapshot payloads from `WidgetSnapshotStore` instead of reading the full app state.
- Auto Ledger separates screenshot/LLM parsing from voice transcription and keeps a local parser fallback for offline use.

## Testing and Validation

- Feature work was developed on dedicated branches and merged through pull requests.
- Manual acceptance testing was done in Xcode Simulator after feature implementation.
- Persistence was checked by creating data, backgrounding the app, relaunching, and confirming state restoration.
- Calendar and planning layouts were checked across multiple simulated iPhone sizes.
- Git hooks support staged Swift formatting checks and scoped Xcode build checks before push.

## Known Constraints

### Signing

- the repository currently targets Personal Team local development
- production iCloud behavior requires a provisioning profile with the required iCloud entitlement

### Technical debt

- view files such as `HomeView.swift` and `ManagementViews.swift` are carrying multiple feature sections and still need further modularization
- focused automated regression coverage is still limited compared with the amount of UI and parser behavior

## Future Work

- continue splitting large SwiftUI files into smaller feature-focused components
- extend iCloud key-value backup toward full CloudKit synchronization when a production entitlement is available
- add focused parser regression coverage for common voice phrases and payment screenshots
- add lightweight tests around persistence, import/export, and snapshot generation
- explore an Apple Watch companion flow for lower-friction expense capture

## Repository Notes

- App icon source files are intentionally stored under `docs/assets/branding/` instead of `AppIcon.appiconset`
- `AppIcon.appiconset` now keeps only the files referenced by `Contents.json`, which avoids unassigned-child warnings from the asset catalog compiler
