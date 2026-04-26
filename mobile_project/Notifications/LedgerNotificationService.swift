import Foundation
import UserNotifications

#if canImport(UIKit)
    import UIKit
#endif

enum LedgerNotificationAuthorizationState: Equatable {
    case unknown
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    var canScheduleNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .unknown, .notDetermined, .denied:
            false
        }
    }

    var title: String {
        switch self {
        case .unknown:
            "检查中"
        case .notDetermined:
            "未授权"
        case .denied:
            "系统已关闭"
        case .authorized:
            "已开启"
        case .provisional:
            "临时开启"
        case .ephemeral:
            "临时会话"
        }
    }

    var subtitle: String {
        switch self {
        case .unknown:
            "正在读取系统通知权限"
        case .notDetermined:
            "打开推送服务时会请求系统通知权限"
        case .denied:
            "需要在系统设置里允许通知后，提醒才会生效"
        case .authorized:
            "本地提醒会按你的开关自动安排"
        case .provisional:
            "通知会先安静送达，可在系统设置中调整"
        case .ephemeral:
            "当前会话允许通知，之后可能需要重新授权"
        }
    }
}

final class LedgerNotificationService {
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let budgetStageKeyPrefix = "ledger.notification.budget.stage"

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
        self.center.delegate = LedgerNotificationCenterDelegate.shared
    }

    func authorizationState() async -> LedgerNotificationAuthorizationState {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: LedgerNotificationAuthorizationState(settings.authorizationStatus))
            }
        }
    }

    func requestAuthorization() async -> LedgerNotificationAuthorizationState {
        _ = await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        return await authorizationState()
    }

    @discardableResult
    func synchronize(
        preferences: LedgerNotificationPreferences,
        budget: LedgerNotificationBudgetSnapshot?,
        requestAuthorizationIfNeeded: Bool = false) async -> LedgerNotificationAuthorizationState {
        guard preferences.isEnabled else {
            if let budget {
                clearLastBudgetReminderStage(for: budget)
            }
            await cancelManagedNotifications()
            return await authorizationState()
        }

        var state = await authorizationState()
        if state == .notDetermined && requestAuthorizationIfNeeded {
            state = await requestAuthorization()
        }

        guard state.canScheduleNotifications else {
            await cancelManagedNotifications()
            return state
        }

        let currentStage = budget.flatMap(LedgerNotificationPlanner.budgetStage(for:))
        let lastStage = budget.flatMap(lastBudgetReminderStage(for:))
        if let budget, currentStage == nil {
            clearLastBudgetReminderStage(for: budget)
        }

        let plan = LedgerNotificationPlanner.makePlan(
            preferences: preferences,
            budget: budget,
            lastBudgetReminderStage: lastStage)
        await rescheduleRecurringNotifications(from: plan)
        await scheduleImmediateNotifications(from: plan)

        if let budget,
           let budgetReminder = plan.first(where: { $0.kind == .budgetReminder }),
           let stage = budgetReminder.budgetStage {
            setLastBudgetReminderStage(stage, for: budget)
        }

        return state
    }

    func cancelManagedNotifications() async {
        let pendingIdentifiers = await pendingManagedNotificationIdentifiers()
        guard !pendingIdentifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
    }

    #if canImport(UIKit)
        @MainActor
        func openSystemSettings() {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }
    #endif

    private func rescheduleRecurringNotifications(from plan: [LedgerNotificationPlanItem]) async {
        center.removePendingNotificationRequests(withIdentifiers: recurringNotificationIdentifiers)

        for item in plan where item.delivery != .immediate {
            await schedule(item)
        }
    }

    private func scheduleImmediateNotifications(from plan: [LedgerNotificationPlanItem]) async {
        if plan.contains(where: { $0.kind == .budgetReminder && $0.delivery == .immediate }) {
            await cancelPendingBudgetReminderNotifications()
        }

        for item in plan where item.delivery == .immediate {
            await schedule(item)
        }
    }

    private func schedule(_ item: LedgerNotificationPlanItem) async {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.sound = .default
        content.categoryIdentifier = item.kind.rawValue
        content.userInfo = [
            "ledgerNotificationKind": item.kind.rawValue
        ]

        let request = UNNotificationRequest(
            identifier: item.identifier,
            content: content,
            trigger: trigger(for: item.delivery))

        await withCheckedContinuation { continuation in
            center.add(request) { _ in
                continuation.resume()
            }
        }
    }

    private func trigger(for delivery: LedgerNotificationDelivery) -> UNNotificationTrigger {
        switch delivery {
        case .immediate:
            return UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        case let .daily(hour, minute):
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case let .weekly(weekday, hour, minute):
            var components = DateComponents()
            components.weekday = weekday
            components.hour = hour
            components.minute = minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case let .monthly(day, hour, minute):
            var components = DateComponents()
            components.day = day
            components.hour = hour
            components.minute = minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }
    }

    private var recurringNotificationIdentifiers: [String] {
        [
            "\(LedgerNotificationPlanner.managedIdentifierPrefix)daily-ledger",
            "\(LedgerNotificationPlanner.managedIdentifierPrefix)feature-recommendation",
            "\(LedgerNotificationPlanner.managedIdentifierPrefix)bill-review"
        ]
    }

    private func pendingManagedNotificationIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(
                    returning: requests
                        .map(\.identifier)
                        .filter { $0.hasPrefix(LedgerNotificationPlanner.managedIdentifierPrefix) })
            }
        }
    }

    private func cancelPendingBudgetReminderNotifications() async {
        let pendingIdentifiers = await pendingManagedNotificationIdentifiers()
            .filter { $0.hasPrefix("\(LedgerNotificationPlanner.managedIdentifierPrefix)budget-") }
        guard !pendingIdentifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
    }

    private func lastBudgetReminderStage(for budget: LedgerNotificationBudgetSnapshot) -> LedgerBudgetReminderStage? {
        defaults.string(forKey: budgetStageKey(for: budget)).flatMap(LedgerBudgetReminderStage.init(rawValue:))
    }

    private func setLastBudgetReminderStage(
        _ stage: LedgerBudgetReminderStage,
        for budget: LedgerNotificationBudgetSnapshot) {
        defaults.set(stage.rawValue, forKey: budgetStageKey(for: budget))
    }

    private func clearLastBudgetReminderStage(for budget: LedgerNotificationBudgetSnapshot) {
        defaults.removeObject(forKey: budgetStageKey(for: budget))
    }

    private func budgetStageKey(for budget: LedgerNotificationBudgetSnapshot) -> String {
        "\(budgetStageKeyPrefix).\(budget.bookID).\(budget.cycleID)"
    }
}

private final class LedgerNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LedgerNotificationCenterDelegate()

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

private extension LedgerNotificationAuthorizationState {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .provisional
        case .ephemeral:
            self = .ephemeral
        @unknown default:
            self = .unknown
        }
    }
}
