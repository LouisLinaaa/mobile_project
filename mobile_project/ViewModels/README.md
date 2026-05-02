# ViewModels

State and orchestration layer for `Monee`.

## Main Files

- [LedgerStore.swift](LedgerStore.swift): central app state, persistence, CSV import/export, backup, restore, budgets, scheduled entries, saving plans, notifications, and widget snapshot publishing
- [AutoLedgerFlow.swift](AutoLedgerFlow.swift): Auto Ledger pipeline, OCR/LLM parsing orchestration, local parser fallback, review flow, voice bookkeeping handoff, and shortcut direct-save path
- [AutoLedgerLLM.swift](AutoLedgerLLM.swift): OpenAI-compatible request configuration and prompt rendering

## Scope

This layer should absorb:

- state mutation
- persistence and restore
- notification scheduling coordination
- cross-screen coordination
- external integration boundaries

It should avoid burying heavy view layout decisions.
