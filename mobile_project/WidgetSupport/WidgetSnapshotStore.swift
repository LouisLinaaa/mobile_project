import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum LedgerWidgetShared {
    static let appGroupID = "group.com.example.mobileproject"
    static let snapshotDefaultsKey = "ledger.widget.snapshot.v1"
    static let deepLinkScheme = "ledgerapp"
}

struct LedgerWidgetCategorySnapshot: Codable {
    let id: String
    let name: String
    let amount: Double
    let tintHex: String
}

struct LedgerWidgetSnapshot: Codable {
    let generatedAt: Date
    let todayExpenseTotal: Double
    let todayExpenseItems: [LedgerWidgetCategorySnapshot]
    let budgetLimit: Double?
    let currentMonthExpense: Double
    let budgetProgress: Double
    let totalAssets: Double
    let totalLiabilities: Double
    let netWorth: Double
    let autoLedgerPendingCount: Int
    let autoLedgerPostedCount: Int
    let autoLedgerFailedCount: Int
    let autoLedgerUpdatedAt: Date

    static let fallback = LedgerWidgetSnapshot(
        generatedAt: Date(),
        todayExpenseTotal: 0,
        todayExpenseItems: [],
        budgetLimit: nil,
        currentMonthExpense: 0,
        budgetProgress: 0,
        totalAssets: 0,
        totalLiabilities: 0,
        netWorth: 0,
        autoLedgerPendingCount: 1,
        autoLedgerPostedCount: 0,
        autoLedgerFailedCount: 0,
        autoLedgerUpdatedAt: Date()
    )
}

enum LedgerWidgetSnapshotStore {
    private static var pendingReload: DispatchWorkItem?
    private static let reloadQueue = DispatchQueue(label: "ledger.widget.reload", qos: .utility)
    private static let widgetKinds = [
        "com.example.mobileproject.widget.today-expense",
        "com.example.mobileproject.widget.budget-progress",
        "com.example.mobileproject.widget.quick-action",
        "com.example.mobileproject.widget.account-overview",
        "com.example.mobileproject.widget.auto-ledger-status"
    ]

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: LedgerWidgetShared.appGroupID) ?? .standard
    }

    static func save(_ snapshot: LedgerWidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: LedgerWidgetShared.snapshotDefaultsKey)
#if canImport(WidgetKit)
        scheduleReload()
#endif
    }

    static func load() -> LedgerWidgetSnapshot {
        guard let data = defaults.data(forKey: LedgerWidgetShared.snapshotDefaultsKey),
              let snapshot = try? decoder.decode(LedgerWidgetSnapshot.self, from: data) else {
            return .fallback
        }
        return snapshot
    }

#if canImport(WidgetKit)
    private static func scheduleReload() {
        pendingReload?.cancel()
        let workItem = DispatchWorkItem {
            widgetKinds.forEach { kind in
                WidgetCenter.shared.reloadTimelines(ofKind: kind)
            }
        }
        pendingReload = workItem
        reloadQueue.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }
#endif
}
