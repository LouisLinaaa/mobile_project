func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fatalError(message)
    }
}

@main
struct NotificationPlannerCheck {
    static func main() {
        let enabledPreferences = LedgerNotificationPreferences(
            isEnabled: true,
            enabledKinds: [.dailyLedger, .budgetReminder, .featureRecommendation, .billReview])

        let budgetSnapshot = LedgerNotificationBudgetSnapshot(
            bookID: "book-main",
            cycleID: "2026-04",
            progress: 0.82,
            remainingAmount: 360,
            overspentAmount: 0)

        let plan = LedgerNotificationPlanner.makePlan(
            preferences: enabledPreferences,
            budget: budgetSnapshot,
            lastBudgetReminderStage: nil)

        expect(
            plan.contains { $0.kind == .dailyLedger && $0.delivery == .daily(hour: 21, minute: 0) },
            "Expected a daily ledger notification plan")
        expect(plan.contains { $0.kind == .featureRecommendation && $0.delivery == .weekly(
            weekday: 2,
            hour: 10,
            minute: 0) }, "Expected a weekly feature recommendation notification plan")
        expect(
            plan.contains { $0.kind == .billReview && $0.delivery == .monthly(day: 1, hour: 20, minute: 0) },
            "Expected a monthly bill review notification plan")
        expect(
            plan
                .contains { $0.kind == .budgetReminder && $0.delivery == .immediate && $0.budgetStage == .approaching },
            "Expected an immediate approaching-budget notification plan")

        let dedupedBudgetPlan = LedgerNotificationPlanner.makePlan(
            preferences: enabledPreferences,
            budget: budgetSnapshot,
            lastBudgetReminderStage: .approaching)

        expect(
            !dedupedBudgetPlan.contains { $0.kind == .budgetReminder && $0.delivery == .immediate },
            "Expected budget reminders to be deduped after approaching stage was already sent")

        let disabledPlan = LedgerNotificationPlanner.makePlan(
            preferences: LedgerNotificationPreferences(
                isEnabled: false,
                enabledKinds: Set(LedgerNotificationKind.allCases)),
            budget: budgetSnapshot,
            lastBudgetReminderStage: nil)

        expect(disabledPlan.isEmpty, "Expected disabled notification preferences to produce no plans")

        print("notification planner checks passed")
    }
}
