# Models

Shared domain and transport models used across the app, widgets, persistence, and automation flows.

## Main Files

- [LedgerModels.swift](LedgerModels.swift): books, entries, accounts, categories, budgets, scheduled entries, saving plans, statistics-facing structures, and backup snapshots
- [AutoLedgerModels.swift](AutoLedgerModels.swift): receipt parsing requests, review drafts, debug snapshots, local parser outputs, and OpenAI-compatible payloads

## Rule of Thumb

Types here should stay:

- serializable
- UI-agnostic where practical
- safe to share across views, store logic, widgets, and shortcuts
