import Foundation

enum LedgerNotificationKind: String, CaseIterable, Hashable {
    case dailyLedger
    case budgetReminder
    case featureRecommendation
    case billReview
}

enum LedgerBudgetReminderStage: String, Equatable {
    case approaching
    case overspent
}

enum LedgerNotificationDelivery: Equatable {
    case immediate
    case daily(hour: Int, minute: Int)
    case weekly(weekday: Int, hour: Int, minute: Int)
    case monthly(day: Int, hour: Int, minute: Int)
}

struct LedgerNotificationPreferences: Equatable {
    var isEnabled: Bool
    var enabledKinds: Set<LedgerNotificationKind>
}

struct LedgerNotificationBudgetSnapshot: Equatable {
    var bookID: String
    var cycleID: String
    var progress: Double
    var remainingAmount: Double
    var overspentAmount: Double
}

struct LedgerNotificationPlanItem: Equatable {
    var identifier: String
    var kind: LedgerNotificationKind
    var title: String
    var body: String
    var delivery: LedgerNotificationDelivery
    var budgetStage: LedgerBudgetReminderStage?
}

enum LedgerNotificationPlanner {
    static let managedIdentifierPrefix = "ledger.notification."

    static func makePlan(
        preferences: LedgerNotificationPreferences,
        budget: LedgerNotificationBudgetSnapshot?,
        lastBudgetReminderStage: LedgerBudgetReminderStage?) -> [LedgerNotificationPlanItem] {
        guard preferences.isEnabled else { return [] }

        var plan: [LedgerNotificationPlanItem] = []
        if preferences.enabledKinds.contains(.dailyLedger) {
            plan.append(
                LedgerNotificationPlanItem(
                    identifier: "\(managedIdentifierPrefix)daily-ledger",
                    kind: .dailyLedger,
                    title: "今天记账了吗？",
                    body: "花一分钟补上今天的收支，月度预算会更准确。",
                    delivery: .daily(hour: 21, minute: 0),
                    budgetStage: nil))
        }

        if preferences.enabledKinds.contains(.budgetReminder),
           let budget,
           let stage = budgetStage(for: budget),
           stage != lastBudgetReminderStage {
            plan.append(
                LedgerNotificationPlanItem(
                    identifier: "\(managedIdentifierPrefix)budget-\(budget.bookID)-\(budget.cycleID)-\(stage.rawValue)",
                    kind: .budgetReminder,
                    title: budgetTitle(for: stage),
                    body: budgetBody(for: stage, budget: budget),
                    delivery: .immediate,
                    budgetStage: stage))
        }

        if preferences.enabledKinds.contains(.featureRecommendation) {
            plan.append(
                LedgerNotificationPlanItem(
                    identifier: "\(managedIdentifierPrefix)feature-recommendation",
                    kind: .featureRecommendation,
                    title: "试试自动记账",
                    body: "截图账单后可以用快捷指令识别并生成记录。",
                    delivery: .weekly(weekday: 2, hour: 10, minute: 0),
                    budgetStage: nil))
        }

        if preferences.enabledKinds.contains(.billReview) {
            plan.append(
                LedgerNotificationPlanItem(
                    identifier: "\(managedIdentifierPrefix)bill-review",
                    kind: .billReview,
                    title: "月度账单回顾",
                    body: "看看本周期的支出结构和预算进度。",
                    delivery: .monthly(day: 1, hour: 20, minute: 0),
                    budgetStage: nil))
        }

        return plan
    }

    static func budgetStage(for budget: LedgerNotificationBudgetSnapshot) -> LedgerBudgetReminderStage? {
        if budget.overspentAmount > 0 || budget.progress >= 1 {
            return .overspent
        }

        if budget.progress >= 0.8 {
            return .approaching
        }

        return nil
    }

    private static func budgetTitle(for stage: LedgerBudgetReminderStage) -> String {
        switch stage {
        case .approaching:
            "预算快到线了"
        case .overspent:
            "预算已超支"
        }
    }

    private static func budgetBody(
        for stage: LedgerBudgetReminderStage,
        budget: LedgerNotificationBudgetSnapshot) -> String {
        switch stage {
        case .approaching:
            let remaining = LedgerNotificationAmountFormatter.compactCurrency(budget.remainingAmount)
            return "本周期预算已使用超过 80%，剩余 \(remaining)。"
        case .overspent:
            let overspent = LedgerNotificationAmountFormatter.compactCurrency(budget.overspentAmount)
            return "本周期支出已经超过预算 \(overspent)，建议回顾近期消费。"
        }
    }
}

private enum LedgerNotificationAmountFormatter {
    static func compactCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = value.rounded() == value ? 0 : 2
        return formatter.string(from: NSNumber(value: max(value, 0))) ?? "¥0"
    }
}
