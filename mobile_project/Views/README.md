# Views

SwiftUI screens and feature composition for `Monee`.

## Major Screens

- [HomeView.swift](HomeView.swift): dashboard, custom tab surface, calendar/planning surface, drawer routing, and primary navigation
- [ManagementViews.swift](ManagementViews.swift): management panels, settings, import/export, backup, profile, about, and Auto Ledger review surfaces
- [BudgetManagementView.swift](BudgetManagementView.swift): budget configuration and tracking
- [AutoLedgerCenterView.swift](AutoLedgerCenterView.swift): automation and shortcut education flow
- [SavingPlanView.swift](SavingPlanView.swift): goal-based saving plans with deposits, withdrawals, and progress
- [ScheduledLedgerView.swift](ScheduledLedgerView.swift): recurring transaction templates and upcoming schedule state
- [SearchView.swift](SearchView.swift): app-wide search across records, books, categories, and quick actions
- [WidgetCenterView.swift](WidgetCenterView.swift): widget discovery and setup guidance
- [QuickAddSheet.swift](QuickAddSheet.swift): fast transaction entry

## Current Refactor Direction

This folder is functional, but some files are still oversized.

The next cleanup pass should keep splitting feature-heavy files into smaller, dedicated view units without moving business logic back into the view layer.
