# Documentation

This directory keeps report-aligned project notes that are too detailed for the root README.

## Files

- [project-status.md](project-status.md): final course-report feature status, validation notes, known limits, and future work
- [auto-ledger-llm.md](auto-ledger-llm.md): screenshot / OCR Auto Ledger request, fallback behavior, and prompt contract
- [assets/branding/monee-app-icon-source.png](assets/branding/monee-app-icon-source.png): source image kept outside the asset catalog to avoid AppIcon warnings

## Report Alignment

The root READMEs describe the app at a product level. Files in this directory provide the implementation context behind the report sections:

- technical architecture and local-first persistence
- Auto Ledger screenshot recognition and optional LLM parsing
- WidgetKit, App Shortcuts, notifications, localization, and backup behavior
- testing, validation, constraints, and future work
