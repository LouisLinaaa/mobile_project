import Foundation

func makeDate(_ text: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    guard let date = formatter.date(from: text) else {
        fatalError("Invalid date fixture: \(text)")
    }
    return date
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
            lastBudgetReminderStage: nil,
            now: makeDate("2026-04-25T12:00:00Z"))

        assert(plan.contains { $0.kind == .dailyLedger && $0.delivery == .daily(hour: 21, minute: 0) })
        assert(plan.contains { $0.kind == .featureRecommendation && $0.delivery == .weekly(
            weekday: 2,
            hour: 10,
            minute: 0) })
        assert(plan.contains { $0.kind == .billReview && $0.delivery == .monthly(day: 1, hour: 20, minute: 0) })
        assert(plan
            .contains { $0.kind == .budgetReminder && $0.delivery == .immediate && $0.budgetStage == .approaching })

        let dedupedBudgetPlan = LedgerNotificationPlanner.makePlan(
            preferences: enabledPreferences,
            budget: budgetSnapshot,
            lastBudgetReminderStage: .approaching,
            now: makeDate("2026-04-25T12:00:00Z"))

        assert(!dedupedBudgetPlan.contains { $0.kind == .budgetReminder && $0.delivery == .immediate })

        let disabledPlan = LedgerNotificationPlanner.makePlan(
            preferences: LedgerNotificationPreferences(
                isEnabled: false,
                enabledKinds: Set(LedgerNotificationKind.allCases)),
            budget: budgetSnapshot,
            lastBudgetReminderStage: nil,
            now: makeDate("2026-04-25T12:00:00Z"))

        assert(disabledPlan.isEmpty)

        print("notification planner checks passed")
    }
}
