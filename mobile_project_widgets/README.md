# mobile_project_widgets

Widget extension target for `Monee`.

## Responsibility

This target renders the WidgetKit surfaces backed by the shared snapshot payload from the main app.

## Supported Widgets

- today expense
- budget progress
- quick action
- account overview
- auto-ledger status

## Key File

- [LedgerWidgetsBundle.swift](LedgerWidgetsBundle.swift): widget bundle, timeline provider, styling, and per-widget views

## Data Flow

The widgets read compact serialized snapshots written by the main app through the App Group bridge. They do not access the full `LedgerStore` directly.
