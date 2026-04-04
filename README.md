# COMP7506B Group Project (2026) - Group 09

中文版本: [README_ZH.md](README_ZH.md)

> Course: `COMP7506B Smart Phone Apps Development`  
> Project theme: `Developing a smart phone application from scratch`  
> Product: `Privacy-first local bookkeeping app (iOS)`

## Team

**Group 09** (`3 / 6 members`)

- Cao Kainan
- Li Ye
- Lin Ruiyi

## Project Summary

This project builds a lightweight but practical iOS bookkeeping app focused on **privacy**, **local-first data**, and **clean daily-use workflows**.

Current prototype already supports:

- Quick expense/income entry
- Monthly summary cards
- Book management
- Asset account management
- Category scheme management
- Statistics dashboard (trend + ranking + category composition)

## Course Requirements Mapping (from Project Brief)

### Key dates

- Group formation deadline: **22 February 2026 (Sunday)**
- In-class app demo: **30 April 2026 (Thursday)**
- Final submission: **3 May 2026 (Sunday), 11:59 PM (HKT)**

### Deliverables checklist

- [ ] Project document (>= 2 pages): background research, app summary, member contribution
- [x] Source code with build/run instructions
- [ ] Introductory video (1-2 minutes)

## Progress Board

| Area | Status | Progress |
|---|---|---|
| Core app architecture (SwiftUI + state store) | Done | 100% |
| Quick bookkeeping flow | Done | 90% |
| Chart/statistics module | Done | 85% |
| Asset management module | Done | 85% |
| Book management module | Done | 85% |
| Category management module | Done | 85% |
| Local persistence (SwiftData/CoreData) | In progress | 30% |
| Automation features | Planned | 20% |
| AI features | Planned | 20% |
| Final doc + demo video | Planned | 15% |

## Background Research (initial)

At least 3 related products were reviewed:

1. **Money Manager**
2. **Spendee**
3. **Wallet by BudgetBakers**

### Common strengths

- Mature charts and budgeting
- Multi-account support
- Recurring transaction handling

### Common pain points / gaps

- Privacy concerns with cloud sync and third-party analytics
- Heavy UI and ad/premium pressure
- Weak local AI assistance for natural-language entry

### Our differentiation

- **Local-first privacy model** (data can stay on device)
- **Automation-first daily flow** (scheduled or rule-based bookkeeping tasks)
- **AI-assisted interaction** designed for personal finance scenarios

## Innovation Highlights

### 1) AI-assisted features (planned)

- Natural language bookkeeping  
  Example: `"Lunch 48 HKD via Alipay"` -> auto parse amount/category/payment method
- Smart category suggestion from recent behavior
- Monthly insight summary with plain-language suggestions

### 2) Automation features (planned)

- Scheduled recurring transactions (rent, salary, subscription)
- Rule engine for auto-tagging/categorization
- Period-end auto reports (weekly/monthly) with trend snapshots

### 3) Privacy-by-design

- On-device storage by default
- Optional app lock / Face ID gate
- Minimized external dependency and telemetry

## Tech Stack

- `SwiftUI` (iOS UI)
- `Charts` (statistics visualization)
- `Xcode` / `xcodebuild`
- Planned: `SwiftData` for local persistence

## Build & Run

From project root:

```bash
xcodebuild -project mobile_project.xcodeproj \
  -scheme mobile_project \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath ./DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

Open in Xcode:

```bash
open mobile_project.xcodeproj
```

### Widget debugging in Xcode

- Use scheme `mobile_project` for normal app run/debug.
- A shared scheme `mobile_project_widgets` is included and pre-configured with:
  - `_XCWidgetKind=com.github.louislinaa.ledgerlab.widget.today-expense`
- To debug another widget kind, edit:
  - `Product -> Scheme -> Edit Scheme -> Run -> Arguments -> Environment Variables`
  - Change `_XCWidgetKind` to one of:
    - `com.github.louislinaa.ledgerlab.widget.today-expense`
    - `com.github.louislinaa.ledgerlab.widget.budget-progress`
    - `com.github.louislinaa.ledgerlab.widget.quick-action`
    - `com.github.louislinaa.ledgerlab.widget.account-overview`
    - `com.github.louislinaa.ledgerlab.widget.auto-ledger-status`

## Upcoming Milestones

- [ ] Add persistent local storage (SwiftData)
- [ ] Add recurring/automation transaction engine
- [ ] Add AI parsing + AI assistant panel
- [ ] Finish project report (research + architecture + contribution table)
- [ ] Record and submit 1-2 minute feature demo video

---

If you are a course assessor/reviewer, this README is maintained as a live status page for Group 09.
