# Models

Shared domain and transport models used across the app and automation flows.

## Main Files

- [LedgerModels.swift](LedgerModels.swift): books, entries, accounts, categories, budgets, statistics-facing structures
- [AutoLedgerModels.swift](AutoLedgerModels.swift): receipt parsing requests, review drafts, debug snapshots, and OpenAI payloads

## Rule of Thumb

Types here should stay:

- serializable
- UI-agnostic where practical
- safe to share across views, store logic, widgets, and shortcuts
