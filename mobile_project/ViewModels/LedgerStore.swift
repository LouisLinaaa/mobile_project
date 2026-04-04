import SwiftUI

@MainActor
final class LedgerStore: ObservableObject {
    @Published var isBalanceVisible = true
    @Published var isQuickAddPresented = false
    @Published var budgetLimit: Double? = nil
    @Published private(set) var entries: [LedgerEntry] = []

    let paymentMethods = ["支付宝", "微信", "银行卡", "现金"]

    private let calendar = Calendar.current

    var currentMonthExpense: Double {
        sumForCurrentMonth(kind: .expense)
    }

    var currentMonthIncome: Double {
        sumForCurrentMonth(kind: .income)
    }

    var currentMonthBalance: Double {
        currentMonthIncome - currentMonthExpense
    }

    var budgetProgress: Double {
        guard let budgetLimit, budgetLimit > 0 else { return 0 }
        return min(currentMonthExpense / budgetLimit, 1)
    }

    var todayEntries: [LedgerEntry] {
        entries
            .filter { calendar.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    var recentEntries: [LedgerEntry] {
        entries.sorted { $0.date > $1.date }
    }

    var monthRecordedDays: Set<Int> {
        Set(
            entries.compactMap { entry in
                guard calendar.isDate(entry.date, equalTo: Date(), toGranularity: .month),
                      calendar.isDate(entry.date, equalTo: Date(), toGranularity: .year) else {
                    return nil
                }
                return calendar.component(.day, from: entry.date)
            }
        )
    }

    var totalRecordDays: Int {
        Set(entries.map { calendar.startOfDay(for: $0.date) }).count
    }

    var totalRecords: Int {
        entries.count
    }

    var currentStreak: Int {
        guard !entries.isEmpty else { return 0 }

        let recordedDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: Date())
        var streak = 0

        while recordedDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return streak
    }

    func makeDraft() -> QuickEntryDraft {
        QuickEntryDraft(
            kind: .expense,
            amountText: "",
            selectedCategory: .defaultCategory(for: .expense),
            paymentMethod: paymentMethods.first ?? "支付宝",
            note: ""
        )
    }

    func addEntry(from draft: QuickEntryDraft) {
        guard let amount = draft.parsedAmount, amount > 0 else { return }

        let title = draft.note.isEmpty ? draft.selectedCategory.name : draft.note
        let entry = LedgerEntry(
            title: title,
            amount: amount,
            kind: draft.kind,
            category: draft.selectedCategory,
            paymentMethod: draft.paymentMethod,
            note: draft.note,
            date: Date()
        )

        entries.insert(entry, at: 0)
    }

    func setStarterBudgetIfNeeded() {
        guard budgetLimit == nil else { return }
        budgetLimit = 3000
    }

    private func sumForCurrentMonth(kind: LedgerKind) -> Double {
        entries
            .filter { entry in
                entry.kind == kind &&
                calendar.isDate(entry.date, equalTo: Date(), toGranularity: .month) &&
                calendar.isDate(entry.date, equalTo: Date(), toGranularity: .year)
            }
            .reduce(0) { $0 + $1.amount }
    }
}
