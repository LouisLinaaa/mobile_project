# Project Status

Last updated: `2026-04-29`

## Product Position

`Monee` is a local-first personal bookkeeping app for iPhone.

The current codebase focuses on three priorities:

- fast daily bookkeeping
- clear budget and asset visibility
- privacy-aware automation that does not require always-on cloud services

## What Is Working

### Core bookkeeping

- expense and income entry
- home dashboard with monthly summary and navigation shortcuts
- books, accounts, and category scheme management
- persistent local app state

### Analysis and planning

- monthly budget setup
- dynamic daily budget calculation
- category-level budget views
- statistics charts and ranking views

### Data movement

- CSV export
- CSV import with book-aware insertion
- local backup snapshot and restore
- iCloud snapshot read and write paths in `LedgerStore`

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
- optional OpenAI-backed parsing via environment or `Info.plist` configuration
- shared local parser fallback for automatic bookkeeping and in-app AI bookkeeping
- voice bookkeeping tab with local `Speech.framework` transcription and the same local parser-backed review flow

## Known Constraints

### Signing

- the repository currently targets Personal Team local development
- real iCloud entitlement cannot be enabled in this signing setup

### Technical debt

- view files such as `HomeView.swift` and `ManagementViews.swift` are carrying multiple feature sections and still need further modularization
- documentation had drifted behind the current code and has now been refreshed, but should be kept updated together with feature changes

## Immediate Next Steps

- continue splitting large SwiftUI files into smaller feature-focused components
- polish backup and restore UX around the current signing limitation
- add focused parser regression coverage for common voice phrases and payment screenshots
- add lightweight tests around persistence, import/export, and snapshot generation

## Repository Notes

- App icon source files are intentionally stored under `docs/assets/branding/` instead of `AppIcon.appiconset`
- `AppIcon.appiconset` now keeps only the files referenced by `Contents.json`, which avoids unassigned-child warnings from the asset catalog compiler
