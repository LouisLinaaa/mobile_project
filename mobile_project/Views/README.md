# Views

SwiftUI screens and feature composition for `Monee`.

## Major Screens

- [HomeView.swift](HomeView.swift): dashboard and primary navigation
- [ManagementViews.swift](ManagementViews.swift): management panels, settings, import/export, backup, about
- [BudgetManagementView.swift](BudgetManagementView.swift): budget configuration and tracking
- [AutoLedgerCenterView.swift](AutoLedgerCenterView.swift): automation and shortcut education flow
- [WidgetCenterView.swift](WidgetCenterView.swift): widget discovery and setup guidance
- [QuickAddSheet.swift](QuickAddSheet.swift): fast transaction entry

## Current Refactor Direction

This folder is functional, but some files are still oversized.

The next cleanup pass should keep splitting feature-heavy files into smaller, dedicated view units without moving business logic back into the view layer.
