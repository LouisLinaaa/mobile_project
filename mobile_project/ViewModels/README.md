# ViewModels

State and orchestration layer for `Monee`.

## Main Files

- [LedgerStore.swift](LedgerStore.swift): central app state, persistence, CSV import/export, backup, restore, widget snapshot publishing
- [AutoLedgerFlow.swift](AutoLedgerFlow.swift): Auto Ledger pipeline, OCR/LLM parsing orchestration, review flow, shortcut handoff
- [AutoLedgerLLM.swift](AutoLedgerLLM.swift): OpenAI request configuration and prompt rendering

## Scope

This layer should absorb:

- state mutation
- persistence and restore
- cross-screen coordination
- external integration boundaries

It should avoid burying heavy view layout decisions.
