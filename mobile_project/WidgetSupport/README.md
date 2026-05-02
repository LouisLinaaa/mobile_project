# WidgetSupport

Bridge layer shared by the main app and the widget extension.

## Main File

- [WidgetSnapshotStore.swift](WidgetSnapshotStore.swift): converts app state into the serialized snapshot consumed by `mobile_project_widgets`

## Purpose

This folder exists so widget-facing data for the five report widgets stays:

- explicit
- serializable
- decoupled from large in-memory app objects

Current widget snapshots cover today spending, budget progress, quick actions, account overview, and Auto Ledger status.
