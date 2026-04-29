import SwiftUI
import UserNotifications

struct LedgerPersistenceSnapshot: Codable {
    var appSettings: AppSettings
    var budgetLimit: Double?
    var bookBudgets: [LedgerBookBudget]
    var categoryBudgets: [LedgerCategoryBudget]
    var entries: [LedgerEntry]
    var books: [LedgerBook]
    var selectedBookID: UUID
    var accounts: [LedgerAccount]
    var categorySchemes: [LedgerCategoryScheme]
    var selectedCategorySchemeID: UUID
    var scheduledEntries: [ScheduledLedgerEntry]
    var savingPlans: [SavingPlan]

    private enum CodingKeys: String, CodingKey {
        case appSettings
        case budgetLimit
        case bookBudgets
        case categoryBudgets
        case entries
        case books
        case selectedBookID
        case accounts
        case categorySchemes
        case selectedCategorySchemeID
        case scheduledEntries
        case savingPlans
    }

    init(
        appSettings: AppSettings,
        budgetLimit: Double?,
        bookBudgets: [LedgerBookBudget],
        categoryBudgets: [LedgerCategoryBudget],
        entries: [LedgerEntry],
        books: [LedgerBook],
        selectedBookID: UUID,
        accounts: [LedgerAccount],
        categorySchemes: [LedgerCategoryScheme],
        selectedCategorySchemeID: UUID,
        scheduledEntries: [ScheduledLedgerEntry] = [],
        savingPlans: [SavingPlan] = []) {
        self.appSettings = appSettings
        self.budgetLimit = budgetLimit
        self.bookBudgets = bookBudgets
        self.categoryBudgets = categoryBudgets
        self.entries = entries
        self.books = books
        self.selectedBookID = selectedBookID
        self.accounts = accounts
        self.categorySchemes = categorySchemes
        self.selectedCategorySchemeID = selectedCategorySchemeID
        self.scheduledEntries = scheduledEntries
        self.savingPlans = savingPlans
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appSettings = try container.decode(AppSettings.self, forKey: .appSettings)
        budgetLimit = try container.decodeIfPresent(Double.self, forKey: .budgetLimit)
        bookBudgets = try container.decodeIfPresent([LedgerBookBudget].self, forKey: .bookBudgets) ?? []
        categoryBudgets = try container.decodeIfPresent([LedgerCategoryBudget].self, forKey: .categoryBudgets) ?? []
        entries = try container.decodeIfPresent([LedgerEntry].self, forKey: .entries) ?? []
        books = try container.decodeIfPresent([LedgerBook].self, forKey: .books) ?? []
        selectedBookID = try container.decodeIfPresent(UUID.self, forKey: .selectedBookID) ?? UUID()
        accounts = try container.decodeIfPresent([LedgerAccount].self, forKey: .accounts) ?? []
        categorySchemes = try container.decodeIfPresent([LedgerCategoryScheme].self, forKey: .categorySchemes) ?? []
        selectedCategorySchemeID = try container.decodeIfPresent(UUID.self, forKey: .selectedCategorySchemeID) ?? UUID()
        scheduledEntries = try container.decodeIfPresent([ScheduledLedgerEntry].self, forKey: .scheduledEntries) ?? []
        savingPlans = try container.decodeIfPresent([SavingPlan].self, forKey: .savingPlans) ?? []
    }
}

enum LedgerPersistenceStore {
    private static let appSettingsKey = "ledger.app.settings"
    private static let persistedStateKey = "ledger.app.persisted.state"

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: LedgerWidgetShared.appGroupID) ?? .standard
    }

    private static var fallbackDefaults: UserDefaults {
        .standard
    }

    static func loadAppSettings() -> AppSettings {
        loadValue(AppSettings.self, forKey: appSettingsKey) ?? AppSettings()
    }

    static func saveAppSettings(_ settings: AppSettings) {
        saveValue(settings, forKey: appSettingsKey)
    }

    static func loadPersistedState() -> LedgerPersistenceSnapshot? {
        loadValue(LedgerPersistenceSnapshot.self, forKey: persistedStateKey)
    }

    static func loadOrSeedPersistedState() -> LedgerPersistenceSnapshot {
        if let persistedState = loadPersistedState() {
            return persistedState
        }

        let seed = LedgerStore.makeSeedPersistedState(appSettings: loadAppSettings())
        savePersistedState(seed)
        return seed
    }

    static func savePersistedState(_ snapshot: LedgerPersistenceSnapshot) {
        saveValue(snapshot, forKey: persistedStateKey)
    }

    private static func loadValue<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        if let data = sharedDefaults.data(forKey: key),
           let decoded = try? decoder.decode(Value.self, from: data) {
            fallbackDefaults.set(data, forKey: key)
            return decoded
        }

        if let data = fallbackDefaults.data(forKey: key),
           let decoded = try? decoder.decode(Value.self, from: data) {
            sharedDefaults.set(data, forKey: key)
            return decoded
        }

        return nil
    }

    private static func saveValue(_ value: some Encodable, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        sharedDefaults.set(data, forKey: key)
        fallbackDefaults.set(data, forKey: key)
    }
}

@MainActor
final class LedgerStore: ObservableObject {
    @Published var isBalanceVisible = true
    @Published var isQuickAddPresented = false
    @Published private(set) var historyPresentation = LedgerHistoryPresentation()
    @Published var entryNavigationRequest: LedgerNavigationRequest?
    @Published private(set) var autoLedgerPendingLaunch: AutoLedgerLaunchPayload?
    @Published private(set) var autoLedgerShortcutStatus = AutoLedgerHandoffStore.loadStatus()
    @Published private(set) var notificationAuthorizationState: LedgerNotificationAuthorizationState = .unknown
    @Published var appSettings: AppSettings {
        didSet {
            guard appSettings != oldValue else { return }
            schedulePersistAppSettings()
            schedulePersistLedgerState()
            scheduleNotificationSync()
            if appSettings.monthStartDay != oldValue.monthStartDay {
                syncWidgetSnapshot()
            }
        }
    }
    @Published private(set) var bookBudgets: [LedgerBookBudget] {
        didSet {
            schedulePersistLedgerState()
            syncWidgetSnapshot()
            scheduleNotificationSync()
        }
    }
    @Published private(set) var categoryBudgets: [LedgerCategoryBudget] {
        didSet {
            schedulePersistLedgerState()
            syncWidgetSnapshot()
            scheduleNotificationSync()
        }
    }
    @Published private(set) var entries: [LedgerEntry] {
        didSet {
            schedulePersistLedgerState()
            syncWidgetSnapshot()
            scheduleNotificationSync()
        }
    }
    @Published private(set) var books: [LedgerBook] {
        didSet {
            schedulePersistLedgerState()
            syncWidgetSnapshot()
        }
    }
    @Published var selectedBookID: UUID {
        didSet {
            schedulePersistLedgerState()
            syncWidgetSnapshot()
            scheduleNotificationSync()
        }
    }
    @Published private(set) var accounts: [LedgerAccount] {
        didSet {
            schedulePersistLedgerState()
            syncWidgetSnapshot()
        }
    }
    @Published private(set) var categorySchemes: [LedgerCategoryScheme] {
        didSet { schedulePersistLedgerState() }
    }
    @Published var selectedCategorySchemeID: UUID {
        didSet { schedulePersistLedgerState() }
    }
    @Published private(set) var scheduledEntries: [ScheduledLedgerEntry] {
        didSet { schedulePersistLedgerState() }
    }
    @Published private(set) var savingPlans: [SavingPlan] {
        didSet { schedulePersistLedgerState() }
    }
    @Published private(set) var lastBackupDate: Date?
    @Published private(set) var iCloudBackupSummary: CloudBackupSummary?

    private let calendar = Calendar.current
    private let localBackupSnapshotKey = "ledger.local.backup.snapshot"
    private let localBackupDateKey = "ledger.local.backup.date"
    private let iCloudBackupSnapshotKey = "ledger.icloud.backup.snapshot"
    private let notificationService = LedgerNotificationService()
    private var settingsPersistTask: Task<Void, Never>?
    private var statePersistTask: Task<Void, Never>?
    private var notificationSyncTask: Task<Void, Never>?
    private var iCloudObserver: NSObjectProtocol?
    private let bookIcons = [
        "book.closed.fill",
        "star.square.fill",
        "tray.full.fill",
        "list.bullet.clipboard.fill"
    ]

    struct CloudBackupSummary: Equatable {
        let generatedAt: Date
        let totalEntryCount: Int
        let totalBookCount: Int
        let totalAccountCount: Int
        let totalCategorySchemeCount: Int
        let appVersion: String
        let backupVersion: String
        let fileSizeDescription: String
    }

    init() {
        let seed = LedgerStore.makeSeedData()
        appSettings = AppSettings()
        bookBudgets = seed.bookBudgets
        categoryBudgets = seed.categoryBudgets
        entries = seed.entries
        books = seed.books
        selectedBookID = seed.selectedBookID
        accounts = seed.accounts
        categorySchemes = seed.categorySchemes
        selectedCategorySchemeID = seed.selectedCategorySchemeID
        scheduledEntries = []
        savingPlans = []
        lastBackupDate = nil
        iCloudBackupSummary = nil
        appSettings = loadAppSettings()
        lastBackupDate = loadLastBackupDate()
        restorePersistedStateIfAvailable()
        configureICloudSync()
        refreshICloudBackupSummary()
        syncWidgetSnapshot()
        refreshAutoLedgerShortcutState()
        refreshNotificationAuthorizationStatus()
        scheduleNotificationSync(immediate: true)
    }

    deinit {
        settingsPersistTask?.cancel()
        statePersistTask?.cancel()
        notificationSyncTask?.cancel()
        if let iCloudObserver {
            NotificationCenter.default.removeObserver(iCloudObserver)
        }
    }

    var paymentAccounts: [LedgerAccount] {
        accounts.sorted { lhs, rhs in
            if lhs.group.affectsAssets != rhs.group.affectsAssets {
                return lhs.group.affectsAssets && !rhs.group.affectsAssets
            }
            return lhs.balance > rhs.balance
        }
    }

    var paymentMethods: [String] {
        uniqueStrings(accounts.map(\.name) + ["支付宝", "微信", "银行卡", "现金", "待确认"])
    }

    var currentBook: LedgerBook {
        books.first(where: { $0.id == selectedBookID }) ?? books[0]
    }

    var currentCategoryScheme: LedgerCategoryScheme {
        categorySchemes.first(where: { $0.id == selectedCategorySchemeID }) ?? categorySchemes[0]
    }

    var currentBookEntries: [LedgerEntry] {
        entries
            .filter { $0.bookID == currentBook.id }
            .sorted { $0.date > $1.date }
    }

    var currentBookStatisticEntries: [LedgerEntry] {
        currentBookEntries.filter(isIncludedInStatistics(_:))
    }

    var currentBookBudgetEntries: [LedgerEntry] {
        currentBookEntries.filter(isIncludedInBudget(_:))
    }

    var budgetLimit: Double? {
        bookBudget(for: currentBook.id)?.monthlyLimit
    }

    var currentMonthExpense: Double {
        statisticsMonthlyTotal(kind: .expense, for: currentBook.id)
    }

    var currentMonthIncome: Double {
        statisticsMonthlyTotal(kind: .income, for: currentBook.id)
    }

    var currentMonthBudgetExpense: Double {
        budgetMonthlyExpense(for: currentBook.id)
    }

    var currentStatisticsMonthInterval: DateInterval {
        makeStatisticsMonthInterval(for: Date())
    }

    var currentMonthBalance: Double {
        currentMonthIncome - currentMonthExpense
    }

    var totalAssets: Double {
        accounts
            .filter(\.group.affectsAssets)
            .reduce(0) { $0 + $1.balance }
    }

    var totalLiabilities: Double {
        accounts
            .filter { !$0.group.affectsAssets }
            .reduce(0) { $0 + $1.balance }
    }

    var netWorth: Double {
        totalAssets - totalLiabilities
    }

    var budgetProgress: Double {
        guard let budgetLimit, budgetLimit > 0 else { return 0 }
        return min(currentMonthBudgetExpense / budgetLimit, 1)
    }

    var currentBudgetRemaining: Double? {
        guard let budgetLimit else { return nil }
        return max(budgetLimit - currentMonthBudgetExpense, 0)
    }

    var currentBudgetOverspent: Double {
        guard let budgetLimit else { return 0 }
        return max(currentMonthBudgetExpense - budgetLimit, 0)
    }

    var currentStatisticsMonthDayCount: Int {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: currentStatisticsMonthInterval.start),
            to: currentStatisticsMonthInterval.end).day ?? 30
        return max(days, 1)
    }

    var remainingBudgetDaysIncludingToday: Int {
        let today = calendar.startOfDay(for: Date())
        let intervalStart = calendar.startOfDay(for: currentStatisticsMonthInterval.start)
        let intervalEnd = calendar
            .date(byAdding: .day, value: -1, to: currentStatisticsMonthInterval.end) ?? intervalStart

        if today < intervalStart {
            return currentStatisticsMonthDayCount
        }

        if today > intervalEnd {
            return 1
        }

        let days = calendar.dateComponents([.day], from: today, to: intervalEnd).day ?? 0
        return max(days + 1, 1)
    }

    var suggestedDailyBudget: Double? {
        guard let currentBudgetRemaining else { return nil }
        return currentBudgetRemaining / Double(remainingBudgetDaysIncludingToday)
    }

    var currentBookCategoryBudgetSummaries: [LedgerBudgetCategorySummary] {
        categoryBudgets
            .filter { $0.bookID == currentBook.id }
            .compactMap { budget in
                guard let category = category(withID: budget.categoryID) else { return nil }
                return LedgerBudgetCategorySummary(
                    budget: budget,
                    category: category,
                    spent: expenseTotal(for: budget.categoryID, in: budget.bookID))
            }
            .sorted { lhs, rhs in
                if lhs.progress == rhs.progress {
                    return lhs.spent > rhs.spent
                }
                return lhs.progress > rhs.progress
            }
    }

    var todayEntries: [LedgerEntry] {
        currentBookEntries
            .filter { calendar.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    var todayStatisticEntries: [LedgerEntry] {
        todayEntries.filter(isIncludedInStatistics(_:))
    }

    var monthRecordedDays: Set<Int> {
        Set(
            currentBookEntries.compactMap { entry in
                guard calendar.isDate(entry.date, equalTo: Date(), toGranularity: .month),
                      calendar.isDate(entry.date, equalTo: Date(), toGranularity: .year)
                else {
                    return nil
                }
                return calendar.component(.day, from: entry.date)
            })
    }

    var currentBookRecordDays: Int {
        Set(currentBookEntries.map { calendar.startOfDay(for: $0.date) }).count
    }

    var currentBookRecordCount: Int {
        currentBookEntries.count
    }

    var totalRecordDays: Int {
        Set(entries.map { calendar.startOfDay(for: $0.date) }).count
    }

    var totalRecords: Int {
        entries.count
    }

    var currentStreak: Int {
        guard !currentBookEntries.isEmpty else { return 0 }

        let recordedDays = Set(currentBookEntries.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: Date())
        var streak = 0

        while recordedDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return streak
    }

    var assistantCardHint: String {
        switch appSettings.assistantReplyStyle {
        case .concise:
            "简洁模式：我会先给结论，再补充必要信息。".localized
        case .balanced:
            "平衡模式：结论和说明都会保留，阅读节奏更稳。".localized
        case .detailed:
            "详细模式：会补充更多上下文与步骤，适合慢慢看。".localized
        }
    }

    var hasPendingAutoLedgerLaunch: Bool {
        autoLedgerPendingLaunch != nil
    }

    var recentTags: [String] {
        uniqueStrings(
            entries
                .sorted { $0.date > $1.date }
                .flatMap(\.tags)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
    }

    func categories(for kind: LedgerKind) -> [LedgerCategory] {
        switch kind {
        case .expense:
            currentCategoryScheme.expenseCategories
        case .income:
            currentCategoryScheme.incomeCategories
        }
    }

    func allCategories(for kind: LedgerKind) -> [LedgerCategory] {
        let source: [LedgerCategory]
        switch kind {
        case .expense:
            source = categorySchemes.flatMap(\.expenseCategories)
        case .income:
            source = categorySchemes.flatMap(\.incomeCategories)
        }

        var seen = Set<String>()
        return source.filter { category in
            seen.insert(category.id).inserted
        }
    }

    func category(withID id: String) -> LedgerCategory? {
        (allCategories(for: .expense) + allCategories(for: .income)).first { $0.id == id }
    }

    func accountTemplates(for group: LedgerAccountGroup) -> [LedgerAccountTemplate] {
        LedgerAccountTemplate.templates(for: group)
    }

    func accounts(for group: LedgerAccountGroup) -> [LedgerAccount] {
        accounts
            .filter { $0.group == group }
            .sorted { $0.balance > $1.balance }
    }

    func entries(scope: LedgerHistoryScope) -> [LedgerEntry] {
        let source: [LedgerEntry]

        switch scope {
        case .currentBook:
            source = currentBookEntries
        case .allBooks:
            source = entries
        }

        return source.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.id.uuidString > rhs.id.uuidString
            }
            return lhs.date > rhs.date
        }
    }

    func entry(withID id: UUID) -> LedgerEntry? {
        entries.first { $0.id == id }
    }

    func book(withID id: UUID) -> LedgerBook? {
        books.first { $0.id == id }
    }

    func account(withID id: UUID?) -> LedgerAccount? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }
    }

    func resolvedPaymentAccountName(for entry: LedgerEntry) -> String {
        if let account = account(withID: entry.accountID) {
            return account.name
        }

        let trimmed = entry.paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "待确认" : trimmed
    }

    func matchingAccountID(for paymentMethod: String, preferredAccountID: UUID? = nil) -> UUID? {
        resolvedAccountID(from: paymentMethod, preferredAccountID: preferredAccountID)
    }

    func makeDraft() -> QuickEntryDraft {
        let defaultAccount = paymentAccounts.first

        return QuickEntryDraft(
            bookID: currentBook.id,
            kind: .expense,
            titleText: "",
            amountText: "",
            selectedCategory: categories(for: .expense).first ?? LedgerCategory.defaultCategory(for: .expense),
            accountID: defaultAccount?.id,
            paymentMethod: defaultAccount?.name ?? (paymentMethods.first ?? "支付宝"),
            tags: [],
            note: "",
            date: Date(),
            isExcludedFromStatistics: false,
            isExcludedFromBudget: false)
    }

    func makeDraft(from entry: LedgerEntry) -> QuickEntryDraft {
        let availableCategories = categories(for: entry.kind)
        let category = availableCategories.first(where: { $0.id == entry.category.id }) ?? entry.category
        let resolvedAccountID = resolvedAccountID(from: entry.paymentMethod, preferredAccountID: entry.accountID)

        return QuickEntryDraft(
            bookID: entry.bookID,
            kind: entry.kind,
            titleText: entry.title,
            amountText: String(format: "%.2f", entry.amount),
            selectedCategory: category,
            accountID: resolvedAccountID,
            paymentMethod: resolvedPaymentMethod(
                accountID: resolvedAccountID,
                paymentMethod: entry.paymentMethod),
            tags: entry.tags,
            note: entry.note,
            date: entry.date,
            isExcludedFromStatistics: entry.isExcludedFromStatistics,
            isExcludedFromBudget: entry.isExcludedFromBudget)
    }

    @discardableResult
    func addEntry(from draft: QuickEntryDraft) -> LedgerEntry? {
        guard let amount = draft.parsedAmount, amount > 0 else { return nil }

        let category = categories(for: draft.kind).first(where: { $0.id == draft.selectedCategory.id }) ?? draft
            .selectedCategory
        let title = resolvedTitle(from: draft, category: category)

        return addEntry(
            bookID: draft.bookID ?? currentBook.id,
            title: title,
            amount: amount,
            kind: draft.kind,
            category: category,
            accountID: draft.accountID,
            paymentMethod: draft.paymentMethod,
            tags: draft.tags,
            note: draft.note,
            date: draft.date,
            isExcludedFromStatistics: draft.isExcludedFromStatistics,
            isExcludedFromBudget: draft.isExcludedFromBudget)
    }

    func refreshAutoLedgerShortcutState() {
        autoLedgerPendingLaunch = AutoLedgerHandoffStore.peekPendingLaunch()
        autoLedgerShortcutStatus = AutoLedgerHandoffStore.loadStatus()
    }

    func refreshNotificationAuthorizationStatus() {
        Task { [weak self] in
            guard let self else { return }
            let state = await notificationService.authorizationState()
            guard !Task.isCancelled else { return }
            notificationAuthorizationState = state
        }
    }

    func openNotificationSystemSettings() {
        notificationService.openSystemSettings()
    }

    func reloadPersistedStateIfAvailable() {
        restorePersistedStateIfAvailable()
        refreshAutoLedgerShortcutState()
        refreshNotificationAuthorizationStatus()
        scheduleNotificationSync(immediate: true)
        syncWidgetSnapshot()
    }

    func consumeAutoLedgerPendingLaunch() -> AutoLedgerLaunchPayload? {
        let payload = AutoLedgerHandoffStore.consumePendingLaunch()
        autoLedgerPendingLaunch = nil
        autoLedgerShortcutStatus = AutoLedgerHandoffStore.loadStatus()
        return payload
    }

    @discardableResult
    func addEntry(
        kind: LedgerKind,
        amount: Double,
        category: LedgerCategory,
        accountID: UUID? = nil,
        paymentMethod: String,
        tags: [String] = [],
        note: String,
        title: String,
        date: Date,
        isExcludedFromStatistics: Bool = false,
        isExcludedFromBudget: Bool = false,
        screenshotData: Data? = nil) -> LedgerEntry {
        addEntry(
            bookID: currentBook.id,
            title: title,
            amount: amount,
            kind: kind,
            category: category,
            accountID: accountID,
            paymentMethod: paymentMethod,
            tags: tags,
            note: note,
            date: date,
            isExcludedFromStatistics: isExcludedFromStatistics,
            isExcludedFromBudget: isExcludedFromBudget,
            screenshotData: screenshotData)
    }

    // MARK: - AI Draft Hand-off

    var pendingAIDraft: QuickEntryDraft?

    func makeDraftWithAI() -> QuickEntryDraft {
        if let ai = pendingAIDraft {
            pendingAIDraft = nil
            return ai
        }
        return makeDraft()
    }

    // MARK: - CSV Import (bookID-aware addEntry)

    @discardableResult
    func addEntry(
        bookID: UUID,
        title: String,
        amount: Double,
        kind: LedgerKind,
        category: LedgerCategory,
        accountID: UUID? = nil,
        paymentMethod: String,
        tags: [String] = [],
        note: String,
        date: Date,
        isExcludedFromStatistics: Bool = false,
        isExcludedFromBudget: Bool = false,
        screenshotData: Data? = nil) -> LedgerEntry {
        let entry = normalizedEntry(
            LedgerEntry(
                bookID: bookID,
                title: title,
                amount: amount,
                kind: kind,
                category: category,
                paymentMethod: paymentMethod,
                accountID: accountID,
                tags: tags,
                note: note,
                date: date,
                isExcludedFromStatistics: isExcludedFromStatistics,
                isExcludedFromBudget: isExcludedFromBudget,
                screenshotData: screenshotData),
            fallbackBookID: currentBook.id)
        entries.insert(entry, at: 0)
        return entry
    }

    func updateEntry(_ entryID: UUID, from draft: QuickEntryDraft) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }),
              let amount = draft.parsedAmount,
              amount > 0 else { return }

        let existingEntry = entries[index]
        let requestedBookID = draft.bookID
        let bookID = requestedBookID.flatMap { requestedID in
            books.contains(where: { $0.id == requestedID }) ? requestedID : nil
        } ?? currentBook.id
        let categoryOptions = categorySchemes
            .flatMap { draft.kind == .expense ? $0.expenseCategories : $0.incomeCategories }
        let category = categoryOptions.first(where: { $0.id == draft.selectedCategory.id })
            ?? categories(for: draft.kind).first
            ?? LedgerCategory.defaultCategory(for: draft.kind)
        let title = resolvedTitle(from: draft, category: category)
        let paymentMethod = resolvedPaymentMethod(accountID: draft.accountID, paymentMethod: draft.paymentMethod)

        entries[index] = normalizedEntry(
            LedgerEntry(
                id: existingEntry.id,
                bookID: bookID,
                title: title,
                amount: amount,
                kind: draft.kind,
                category: category,
                paymentMethod: paymentMethod,
                accountID: draft.accountID,
                tags: normalizedTags(draft.tags),
                note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines),
                date: draft.date,
                isExcludedFromStatistics: draft.isExcludedFromStatistics,
                isExcludedFromBudget: draft.isExcludedFromBudget,
                screenshotData: existingEntry.screenshotData),
            fallbackBookID: currentBook.id)
    }

    func updateEntry(_ entryID: UUID, mutate: (inout LedgerEntry) -> Void) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        var updatedEntry = entries[index]
        mutate(&updatedEntry)
        entries[index] = normalizedEntry(updatedEntry, fallbackBookID: currentBook.id)
    }

    func updateEntryScreenshot(_ entryID: UUID, data: Data?) {
        updateEntry(entryID) { entry in
            entry.screenshotData = data
        }
    }

    func deleteEntry(id entryID: UUID) {
        entries.removeAll { $0.id == entryID }
        historyPresentation.highlightedEntryIDs.removeAll { $0 == entryID }

        if case .detail(let selectedID) = entryNavigationRequest?.destination, selectedID == entryID {
            entryNavigationRequest = nil
        }
    }

    func presentHistory(
        scope: LedgerHistoryScope = .currentBook,
        highlightedEntryIDs: [UUID] = [],
        prefersFocusedBatch: Bool = false,
        filteredDate: Date? = nil,
        title: String? = nil) {
        let normalizedDate = filteredDate.map { calendar.startOfDay(for: $0) }
        historyPresentation = LedgerHistoryPresentation(
            scope: scope,
            highlightedEntryIDs: highlightedEntryIDs,
            prefersFocusedBatch: prefersFocusedBatch,
            filteredDate: normalizedDate,
            title: title)
        entryNavigationRequest = LedgerNavigationRequest(destination: .history(historyPresentation))
    }

    func presentEntryDetail(id entryID: UUID) {
        entryNavigationRequest = LedgerNavigationRequest(destination: .detail(entryID: entryID))
    }

    func clearEntryNavigationRequest() {
        entryNavigationRequest = nil
    }

    func clearHistoryPresentation() {
        historyPresentation = LedgerHistoryPresentation(scope: .currentBook)
    }

    func isInCurrentStatisticsMonth(_ date: Date) -> Bool {
        let interval = currentStatisticsMonthInterval
        return interval.contains(date)
    }

    func setCurrentBook(_ book: LedgerBook) {
        selectedBookID = book.id
    }

    func setCurrentCategoryScheme(_ scheme: LedgerCategoryScheme) {
        selectedCategorySchemeID = scheme.id
    }

    func setStarterBudgetIfNeeded() {
        if budgetLimit == nil {
            setBudgetLimit(3600)
        }
    }

    func setBudgetLimit(_ limit: Double?, for bookID: UUID? = nil) {
        let resolvedBookID = bookID ?? currentBook.id
        bookBudgets.removeAll { $0.bookID == resolvedBookID }

        guard let limit, limit > 0 else { return }

        bookBudgets.append(
            LedgerBookBudget(
                bookID: resolvedBookID,
                monthlyLimit: limit))
    }

    func upsertCategoryBudget(categoryID: String, monthlyLimit: Double, for bookID: UUID? = nil) {
        let resolvedBookID = bookID ?? currentBook.id
        categoryBudgets.removeAll {
            $0.bookID == resolvedBookID && $0.categoryID == categoryID
        }

        guard monthlyLimit > 0 else { return }

        categoryBudgets.append(
            LedgerCategoryBudget(
                bookID: resolvedBookID,
                categoryID: categoryID,
                monthlyLimit: monthlyLimit))
    }

    func removeCategoryBudget(_ budget: LedgerCategoryBudget) {
        categoryBudgets.removeAll { $0.id == budget.id }
    }

    func addSavingPlan(_ plan: SavingPlan) {
        savingPlans.append(plan)
    }

    func updateSavingPlan(_ plan: SavingPlan) {
        guard let index = savingPlans.firstIndex(where: { $0.id == plan.id }) else { return }
        savingPlans[index] = plan
    }

    func deleteSavingPlan(_ plan: SavingPlan) {
        savingPlans.removeAll { $0.id == plan.id }
    }

    func depositToSavingPlan(_ plan: SavingPlan, amount: Double) {
        guard amount > 0, let index = savingPlans.firstIndex(where: { $0.id == plan.id }) else { return }
        savingPlans[index].savedAmount += amount
    }

    func withdrawFromSavingPlan(_ plan: SavingPlan, amount: Double) {
        guard amount > 0, let index = savingPlans.firstIndex(where: { $0.id == plan.id }) else { return }
        savingPlans[index].savedAmount = max(savingPlans[index].savedAmount - amount, 0)
    }

    func bookBudget(for bookID: UUID) -> LedgerBookBudget? {
        bookBudgets.first { $0.bookID == bookID }
    }

    func categoryBudget(for categoryID: String, in bookID: UUID? = nil) -> LedgerCategoryBudget? {
        let resolvedBookID = bookID ?? currentBook.id
        return categoryBudgets.first {
            $0.bookID == resolvedBookID && $0.categoryID == categoryID
        }
    }

    func expenseTotal(for categoryID: String, in bookID: UUID) -> Double {
        let interval = currentStatisticsMonthInterval
        return entries
            .filter { entry in
                entry.bookID == bookID &&
                    entry.kind == .expense &&
                    isIncludedInBudget(entry) &&
                    entry.category.id == categoryID &&
                    interval.contains(entry.date)
            }
            .reduce(0) { $0 + $1.amount }
    }

    func dayExpenseTotal(for date: Date, in bookID: UUID) -> Double {
        let dayStart = calendar.startOfDay(for: date)
        return entries
            .filter { entry in
                entry.bookID == bookID &&
                    entry.kind == .expense &&
                    isIncludedInBudget(entry) &&
                    calendar.startOfDay(for: entry.date) == dayStart
            }
            .reduce(0) { $0 + $1.amount }
    }

    func setMonthStartDay(_ day: Int) {
        updateSettings { settings in
            settings.monthStartDay = min(max(day, 1), 28)
        }
    }

    func setAssistantReplyStyle(_ style: AssistantReplyStyle) {
        updateSettings { settings in
            settings.assistantReplyStyle = style
        }
    }

    func updateUserDisplayName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updateSettings { settings in
            settings.userProfile.displayName = trimmedName.isEmpty ? "我的账本" : String(trimmedName.prefix(20))
        }
    }

    func updateUserGender(_ gender: String) {
        let trimmedGender = gender.trimmingCharacters(in: .whitespacesAndNewlines)
        updateSettings { settings in
            settings.userProfile.gender = String(trimmedGender.prefix(12))
        }
    }

    func updateUserAvatar(data: Data?) {
        updateSettings { settings in
            settings.userProfile.avatarData = data
        }
    }

    func setPushEnabled(_ enabled: Bool) {
        updateSettings { settings in
            settings.pushEnabled = enabled
            if !enabled {
                settings.pushDailyLedger = false
                settings.pushBudgetReminder = false
                settings.pushFeatureRecommendation = false
                settings.pushBillReview = false
            } else if !settings.pushDailyLedger &&
                !settings.pushBudgetReminder &&
                !settings.pushFeatureRecommendation &&
                !settings.pushBillReview {
                settings.pushDailyLedger = true
                settings.pushBudgetReminder = true
                settings.pushFeatureRecommendation = true
                settings.pushBillReview = true
            }
        }
        scheduleNotificationSync(immediate: true, requestAuthorizationIfNeeded: enabled)
    }

    func setPushSubItem(
        dailyLedger: Bool? = nil,
        budgetReminder: Bool? = nil,
        featureRecommendation: Bool? = nil,
        billReview: Bool? = nil) {
        updateSettings { settings in
            if let dailyLedger {
                settings.pushDailyLedger = dailyLedger
            }
            if let budgetReminder {
                settings.pushBudgetReminder = budgetReminder
            }
            if let featureRecommendation {
                settings.pushFeatureRecommendation = featureRecommendation
            }
            if let billReview {
                settings.pushBillReview = billReview
            }

            settings.pushEnabled =
                settings.pushDailyLedger ||
                settings.pushBudgetReminder ||
                settings.pushFeatureRecommendation ||
                settings.pushBillReview
        }
        scheduleNotificationSync(immediate: true, requestAuthorizationIfNeeded: appSettings.pushEnabled)
    }

    var isICloudBackupAvailable: Bool {
        false
    }

    var hasLocalBackupSnapshot: Bool {
        UserDefaults.standard.data(forKey: localBackupSnapshotKey) != nil
    }

    @discardableResult
    func createLocalBackupSnapshot() -> Bool {
        guard let data = encodedBackupSnapshot() else {
            return false
        }

        let now = Date()
        UserDefaults.standard.set(data, forKey: localBackupSnapshotKey)
        UserDefaults.standard.set(now, forKey: localBackupDateKey)
        lastBackupDate = now
        return true
    }

    @discardableResult
    func createICloudBackupSnapshot() -> Bool {
        guard let data = encodedBackupSnapshot() else {
            return false
        }

        let cloudStore = NSUbiquitousKeyValueStore.default
        cloudStore.set(data, forKey: iCloudBackupSnapshotKey)
        _ = cloudStore.synchronize()

        UserDefaults.standard.set(data, forKey: localBackupSnapshotKey)
        let now = Date()
        UserDefaults.standard.set(now, forKey: localBackupDateKey)
        lastBackupDate = now
        refreshICloudBackupSummary()
        return true
    }

    @discardableResult
    func restoreFromICloudBackupSnapshot() -> Bool {
        let cloudStore = NSUbiquitousKeyValueStore.default
        guard let data = cloudStore.data(forKey: iCloudBackupSnapshotKey),
              let snapshot = try? JSONDecoder().decode(BackupSnapshot.self, from: data)
        else {
            return false
        }

        applyBackupSnapshot(snapshot)
        UserDefaults.standard.set(data, forKey: localBackupSnapshotKey)
        UserDefaults.standard.set(snapshot.generatedAt, forKey: localBackupDateKey)
        lastBackupDate = snapshot.generatedAt
        refreshICloudBackupSummary()
        return true
    }

    func clearLocalBackupSnapshot() {
        UserDefaults.standard.removeObject(forKey: localBackupSnapshotKey)
        UserDefaults.standard.removeObject(forKey: localBackupDateKey)
        lastBackupDate = nil
    }

    func clearAllHistoryEntries() {
        entries.removeAll()
        clearHistoryPresentation()
        clearEntryNavigationRequest()
    }

    func addBook(name: String, note: String) {
        let book = LedgerBook(
            name: name,
            note: note.isEmpty ? "自定义账本" : note,
            createdAt: Date(),
            icon: bookIcons[books.count % bookIcons.count],
            tintStyle: LedgerTintStyle.allCases[books.count % LedgerTintStyle.allCases.count])

        books.append(book)
        selectedBookID = book.id
    }

    func bookEntryCount(_ book: LedgerBook) -> Int {
        entries.filter { $0.bookID == book.id }.count
    }

    func bookMonthlyExpense(_ book: LedgerBook) -> Double {
        statisticsMonthlyTotal(kind: .expense, for: book.id)
    }

    func bookMonthlyIncome(_ book: LedgerBook) -> Double {
        statisticsMonthlyTotal(kind: .income, for: book.id)
    }

    func addAccount(template: LedgerAccountTemplate, customName: String, balance: Double) {
        let account = LedgerAccount(
            templateID: template.id,
            name: customName.isEmpty ? template.name : customName,
            icon: template.icon,
            tintStyle: template.tintStyle,
            group: template.group,
            balance: balance)

        accounts.append(account)
    }

    func updateAccount(_ account: LedgerAccount, template: LedgerAccountTemplate, customName: String, balance: Double) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }

        accounts[index] = LedgerAccount(
            id: account.id,
            templateID: template.id,
            name: customName.isEmpty ? template.name : customName,
            icon: template.icon,
            tintStyle: template.tintStyle,
            group: template.group,
            balance: balance)
    }

    func deleteAccount(_ account: LedgerAccount) {
        accounts.removeAll { $0.id == account.id }
        entries = entries.map { entry in
            guard entry.accountID == account.id else { return entry }
            var updatedEntry = entry
            updatedEntry.accountID = nil
            if updatedEntry.paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updatedEntry.paymentMethod = account.name
            }
            return updatedEntry
        }
    }

    func addCategoryScheme(name: String, note: String) {
        let base = currentCategoryScheme
        let scheme = LedgerCategoryScheme(
            name: name,
            note: note.isEmpty ? "自定义分类方案" : note,
            expenseCategories: base.expenseCategories,
            incomeCategories: base.incomeCategories)

        categorySchemes.append(scheme)
        selectedCategorySchemeID = scheme.id
    }

    func addCategory(
        to schemeID: UUID,
        kind: LedgerKind,
        name: String,
        icon: String,
        tintStyle: LedgerTintStyle) {
        guard let index = categorySchemes.firstIndex(where: { $0.id == schemeID }) else { return }

        var scheme = categorySchemes[index]
        let safeName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeName.isEmpty else { return }

        let slug = safeName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")

        let category = LedgerCategory(
            id: "\(kind.storageKey).\(slug).\(UUID().uuidString.prefix(4))",
            name: safeName,
            icon: icon,
            tintStyle: tintStyle,
            kind: kind)

        switch kind {
        case .expense:
            scheme = LedgerCategoryScheme(
                id: scheme.id,
                name: scheme.name,
                note: scheme.note,
                expenseCategories: scheme.expenseCategories + [category],
                incomeCategories: scheme.incomeCategories)
        case .income:
            scheme = LedgerCategoryScheme(
                id: scheme.id,
                name: scheme.name,
                note: scheme.note,
                expenseCategories: scheme.expenseCategories,
                incomeCategories: scheme.incomeCategories + [category])
        }

        categorySchemes[index] = scheme
    }

    func removeCategory(from schemeID: UUID, categoryID: String, kind: LedgerKind) {
        guard let index = categorySchemes.firstIndex(where: { $0.id == schemeID }) else { return }
        let scheme = categorySchemes[index]

        switch kind {
        case .expense:
            let filtered = scheme.expenseCategories.filter { $0.id != categoryID }
            categorySchemes[index] = LedgerCategoryScheme(
                id: scheme.id,
                name: scheme.name,
                note: scheme.note,
                expenseCategories: filtered,
                incomeCategories: scheme.incomeCategories)
        case .income:
            let filtered = scheme.incomeCategories.filter { $0.id != categoryID }
            categorySchemes[index] = LedgerCategoryScheme(
                id: scheme.id,
                name: scheme.name,
                note: scheme.note,
                expenseCategories: scheme.expenseCategories,
                incomeCategories: filtered)
        }

        let categoryStillExists = categorySchemes.contains { scheme in
            switch kind {
            case .expense:
                scheme.expenseCategories.contains { $0.id == categoryID }
            case .income:
                scheme.incomeCategories.contains { $0.id == categoryID }
            }
        }

        guard !categoryStillExists else { return }

        categoryBudgets.removeAll { $0.categoryID == categoryID }
    }

    // MARK: - Scheduled Ledger

    func addScheduledEntry(_ entry: ScheduledLedgerEntry) {
        scheduledEntries.append(entry)
        scheduleNotificationForEntry(entry)
    }

    func updateScheduledEntry(_ entry: ScheduledLedgerEntry) {
        guard let index = scheduledEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        cancelNotificationForEntry(scheduledEntries[index])
        scheduledEntries[index] = entry
        if entry.isEnabled {
            scheduleNotificationForEntry(entry)
        }
    }

    func deleteScheduledEntry(_ entry: ScheduledLedgerEntry) {
        cancelNotificationForEntry(entry)
        scheduledEntries.removeAll { $0.id == entry.id }
    }

    func toggleScheduledEntry(_ entry: ScheduledLedgerEntry) {
        guard let index = scheduledEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        scheduledEntries[index].isEnabled.toggle()
        if scheduledEntries[index].isEnabled {
            scheduleNotificationForEntry(scheduledEntries[index])
        } else {
            cancelNotificationForEntry(entry)
        }
    }

    func executeScheduledEntry(_ entry: ScheduledLedgerEntry) {
        addEntry(
            bookID: entry.bookID,
            title: entry.title,
            amount: entry.amount,
            kind: entry.kind,
            category: entry.category,
            paymentMethod: entry.paymentMethod,
            tags: [],
            note: entry.note,
            date: Date())

        guard let index = scheduledEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        let now = Date()
        var next = entry.nextDate
        repeat {
            next = entry.recurrence.nextDate(after: next)
        } while next <= now
        if let endDate = entry.endDate, next > endDate {
            scheduledEntries[index].isEnabled = false
        } else {
            scheduledEntries[index].nextDate = next
        }
        cancelNotificationForEntry(entry)
        if scheduledEntries[index].isEnabled {
            scheduleNotificationForEntry(scheduledEntries[index])
        }
    }

    var pendingScheduledEntries: [ScheduledLedgerEntry] {
        scheduledEntries
            .filter { $0.isEnabled && !$0.isExpired }
            .sorted { $0.nextDate < $1.nextDate }
    }

    var overdueScheduledEntries: [ScheduledLedgerEntry] {
        let now = Date()
        return pendingScheduledEntries.filter { $0.nextDate <= now }
    }

    private func canScheduleLedgerNotifications(_ completion: @escaping (Bool) -> Void) {
        guard appSettings.pushEnabled else {
            completion(false)
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            default:
                completion(false)
            }
        }
    }

    private func scheduleNotificationForEntry(_ entry: ScheduledLedgerEntry) {
        guard entry.isEnabled, appSettings.pushEnabled else { return }

        canScheduleLedgerNotifications { canSchedule in
            guard canSchedule else { return }

            let content = UNMutableNotificationContent()
            content.title = "定时记账提醒".localized
            content.body = L10n.format(
                "scheduled_ledger_notification_body",
                entry.title,
                LedgerFormatters.currency(entry.amount))
            content.sound = .default
            content.userInfo = ["scheduledEntryID": entry.id.uuidString]

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: entry.nextDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "ledger.scheduled.\(entry.id.uuidString)",
                content: content,
                trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func cancelNotificationForEntry(_ entry: ScheduledLedgerEntry) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["ledger.scheduled.\(entry.id.uuidString)"])
    }

    private func isIncludedInStatistics(_ entry: LedgerEntry) -> Bool {
        !entry.isExcludedFromStatistics
    }

    private func isIncludedInBudget(_ entry: LedgerEntry) -> Bool {
        !entry.isExcludedFromStatistics && !entry.isExcludedFromBudget
    }

    private func statisticsMonthlyTotal(kind: LedgerKind, for bookID: UUID) -> Double {
        let interval = currentStatisticsMonthInterval
        return entries
            .filter { entry in
                entry.bookID == bookID &&
                    entry.kind == kind &&
                    isIncludedInStatistics(entry) &&
                    interval.contains(entry.date)
            }
            .reduce(0) { $0 + $1.amount }
    }

    private func budgetMonthlyExpense(for bookID: UUID) -> Double {
        let interval = currentStatisticsMonthInterval
        return entries
            .filter { entry in
                entry.bookID == bookID &&
                    entry.kind == .expense &&
                    isIncludedInBudget(entry) &&
                    interval.contains(entry.date)
            }
            .reduce(0) { $0 + $1.amount }
    }

    private func resolvedAccountID(from paymentMethod: String, preferredAccountID: UUID?) -> UUID? {
        if let preferredAccountID,
           accounts.contains(where: { $0.id == preferredAccountID }) {
            return preferredAccountID
        }

        let trimmed = paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let exactMatch = accounts.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return exactMatch.id
        }

        let normalized = normalizedLookupText(trimmed)

        func firstAccount(matching candidates: [String], groups: [LedgerAccountGroup]? = nil) -> UUID? {
            accounts.first { account in
                let sameGroup = groups.map { $0.contains(account.group) } ?? true
                guard sameGroup else { return false }
                let accountText = normalizedLookupText(account.name)
                return candidates.contains(where: { keyword in
                    let normalizedKeyword = normalizedLookupText(keyword)
                    return accountText.contains(normalizedKeyword)
                })
            }?.id
        }

        if normalized.contains("wechat") || normalized.contains("微信") {
            return firstAccount(matching: ["微信", "wechat"])
        }

        if normalized.contains("alipay") || normalized.contains("支付宝") {
            return firstAccount(matching: ["支付宝", "alipay"])
        }

        if normalized.contains("cash") || normalized.contains("现金") {
            return firstAccount(matching: ["现金", "cash"])
        }

        if normalized.contains("credit") || normalized.contains("信用卡") {
            return firstAccount(matching: ["信用卡", "credit", "visa", "mastercard"], groups: [.credit])
        }

        if normalized.contains("card") || normalized.contains("银行卡") || normalized.contains("储蓄卡") {
            return firstAccount(matching: ["银行卡", "储蓄卡", "借记卡", "card"], groups: [.asset, .credit])
        }

        return nil
    }

    private func resolvedPaymentMethod(accountID: UUID?, paymentMethod: String) -> String {
        if let account = account(withID: accountID) {
            return account.name
        }

        let trimmed = paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "待确认" : trimmed
    }

    private func normalizedTags(_ tags: [String]) -> [String] {
        uniqueStrings(
            tags
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
    }

    private func normalizedLookupText(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "余额", with: "")
            .replacingOccurrences(of: "账户", with: "")
    }

    private func normalizedEntry(_ entry: LedgerEntry, fallbackBookID: UUID) -> LedgerEntry {
        var normalized = entry
        normalized.bookID = books.contains(where: { $0.id == normalized.bookID }) ? normalized.bookID : fallbackBookID
        normalized.accountID = resolvedAccountID(
            from: normalized.paymentMethod,
            preferredAccountID: normalized.accountID)
        normalized.paymentMethod = resolvedPaymentMethod(
            accountID: normalized.accountID,
            paymentMethod: normalized.paymentMethod)
        normalized.title = normalized.title.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.note = normalized.note.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.tags = normalizedTags(normalized.tags)
        normalized.isExcludedFromBudget = normalized.isExcludedFromStatistics ? true : normalized.isExcludedFromBudget

        if normalized.title.isEmpty {
            normalized.title = normalized.note.isEmpty ? normalized.category.name : normalized.note
        }

        return normalized
    }

    private func migratedBookBudgets(
        _ budgets: [LedgerBookBudget],
        legacyBudgetLimit: Double?,
        books: [LedgerBook],
        fallbackBookID: UUID) -> [LedgerBookBudget] {
        let validBookIDs = Set(books.map(\.id))
        let sanitized = budgets
            .filter { validBookIDs.contains($0.bookID) && $0.monthlyLimit > 0 }

        guard !sanitized.isEmpty else {
            guard let legacyBudgetLimit, legacyBudgetLimit > 0 else { return [] }
            return [
                LedgerBookBudget(
                    bookID: validBookIDs
                        .contains(fallbackBookID) ? fallbackBookID : (books.first?.id ?? fallbackBookID),
                    monthlyLimit: legacyBudgetLimit)
            ]
        }

        return sanitized
    }

    private func sanitizedCategoryBudgets(
        _ budgets: [LedgerCategoryBudget],
        books: [LedgerBook]) -> [LedgerCategoryBudget] {
        let validBookIDs = Set(books.map(\.id))
        let validCategoryIDs = Set((allCategories(for: .expense) + allCategories(for: .income)).map(\.id))

        return budgets.filter {
            validBookIDs.contains($0.bookID) &&
                validCategoryIDs.contains($0.categoryID) &&
                $0.monthlyLimit > 0
        }
    }

    private func makeStatisticsMonthInterval(for date: Date) -> DateInterval {
        let startDay = min(max(appSettings.monthStartDay, 1), 28)
        let day = calendar.component(.day, from: date)

        let anchorDate: Date = if day < startDay {
            calendar.date(byAdding: .month, value: -1, to: date) ?? date
        } else {
            date
        }

        var components = calendar.dateComponents([.year, .month], from: anchorDate)
        components.day = startDay
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? date

        return DateInterval(start: start, end: end)
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var result: [String] = []

        for value in values where !result.contains(value) {
            result.append(value)
        }

        return result
    }

    private func resolvedTitle(from draft: QuickEntryDraft, category: LedgerCategory) -> String {
        let trimmedTitle = draft.titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        let trimmedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedNote.isEmpty ? category.name.localized : trimmedNote
    }

    private func scheduleNotificationSync(
        immediate: Bool = false,
        requestAuthorizationIfNeeded: Bool = false) {
        notificationSyncTask?.cancel()

        let delay: UInt64 = immediate ? 0 : 350_000_000
        notificationSyncTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled, let self else { return }
            await self.synchronizeNotifications(requestAuthorizationIfNeeded: requestAuthorizationIfNeeded)
        }
    }

    private func synchronizeNotifications(requestAuthorizationIfNeeded: Bool) async {
        let state = await notificationService.synchronize(
            preferences: notificationPreferences,
            budget: notificationBudgetSnapshot,
            requestAuthorizationIfNeeded: requestAuthorizationIfNeeded)
        guard !Task.isCancelled else { return }
        notificationAuthorizationState = state
    }

    private var notificationPreferences: LedgerNotificationPreferences {
        var enabledKinds = Set<LedgerNotificationKind>()
        if appSettings.pushDailyLedger {
            enabledKinds.insert(.dailyLedger)
        }
        if appSettings.pushBudgetReminder {
            enabledKinds.insert(.budgetReminder)
        }
        if appSettings.pushFeatureRecommendation {
            enabledKinds.insert(.featureRecommendation)
        }
        if appSettings.pushBillReview {
            enabledKinds.insert(.billReview)
        }

        return LedgerNotificationPreferences(
            isEnabled: appSettings.pushEnabled,
            enabledKinds: enabledKinds)
    }

    private var notificationBudgetSnapshot: LedgerNotificationBudgetSnapshot? {
        guard let budgetLimit, budgetLimit > 0 else { return nil }
        let progress = currentMonthBudgetExpense / budgetLimit
        return LedgerNotificationBudgetSnapshot(
            bookID: currentBook.id.uuidString,
            cycleID: notificationCycleID,
            progress: progress,
            remainingAmount: currentBudgetRemaining ?? 0,
            overspentAmount: currentBudgetOverspent)
    }

    private var notificationCycleID: String {
        let start = currentStatisticsMonthInterval.start
        let components = calendar.dateComponents([.year, .month, .day], from: start)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0)
    }

    private func syncWidgetSnapshot() {
        LedgerWidgetSnapshotStore.save(makeWidgetSnapshot())
    }

    private func makeWidgetSnapshot() -> LedgerWidgetSnapshot {
        let todayExpenseEntries = todayStatisticEntries.filter { $0.kind == .expense }
        let grouped = Dictionary(grouping: todayExpenseEntries, by: { $0.category.id })

        let topCategories = grouped.compactMap { _, items -> LedgerWidgetCategorySnapshot? in
            guard let first = items.first else { return nil }
            let total = items.reduce(0) { $0 + $1.amount }
            return LedgerWidgetCategorySnapshot(
                id: first.category.id,
                name: first.category.name.localized,
                amount: total,
                tintHex: hexColor(for: first.category.tintStyle))
        }
        .sorted { $0.amount > $1.amount }
        .prefix(4)

        return LedgerWidgetSnapshot(
            generatedAt: Date(),
            todayExpenseTotal: todayExpenseEntries.reduce(0) { $0 + $1.amount },
            todayExpenseItems: Array(topCategories),
            budgetLimit: budgetLimit,
            currentMonthExpense: currentMonthExpense,
            budgetProgress: budgetProgress,
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities,
            netWorth: netWorth,
            autoLedgerPendingCount: 0,
            autoLedgerPostedCount: 0,
            autoLedgerFailedCount: 0,
            autoLedgerUpdatedAt: Date())
    }

    private func hexColor(for style: LedgerTintStyle) -> String {
        switch style {
        case .accent:
            "#4F81FA"
        case .gold:
            "#F5C35A"
        case .mint:
            "#75CAC2"
        case .lavender:
            "#AAA1F7"
        case .coral:
            "#F2A193"
        case .expense:
            "#F57A61"
        case .income:
            "#4AAC84"
        }
    }

    private func updateSettings(_ transform: (inout AppSettings) -> Void) {
        var settings = appSettings
        transform(&settings)
        guard settings != appSettings else { return }
        appSettings = settings
    }

    private func loadAppSettings() -> AppSettings {
        LedgerPersistenceStore.loadAppSettings()
    }

    private func schedulePersistAppSettings() {
        settingsPersistTask?.cancel()

        let currentSettings = appSettings
        settingsPersistTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            LedgerPersistenceStore.saveAppSettings(currentSettings)
        }
    }

    private func schedulePersistLedgerState() {
        statePersistTask?.cancel()

        let snapshot = currentPersistedState
        statePersistTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            LedgerPersistenceStore.savePersistedState(snapshot)
        }
    }

    func flushPendingSettingsPersistence() {
        settingsPersistTask?.cancel()
        settingsPersistTask = nil
        LedgerPersistenceStore.saveAppSettings(appSettings)
    }

    func flushPendingLedgerStatePersistence() {
        statePersistTask?.cancel()
        statePersistTask = nil
        LedgerPersistenceStore.savePersistedState(currentPersistedState)
    }

    private func loadLastBackupDate() -> Date? {
        UserDefaults.standard.object(forKey: localBackupDateKey) as? Date
    }

    private func restorePersistedStateIfAvailable() {
        guard let snapshot = LedgerPersistenceStore.loadPersistedState() else {
            return
        }
        applyPersistedState(snapshot)
    }

    private func configureICloudSync() {
        iCloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshICloudBackupSummary()
                }
            }
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func refreshICloudBackupSummary() {
        let cloudStore = NSUbiquitousKeyValueStore.default
        cloudStore.synchronize()

        guard let data = cloudStore.data(forKey: iCloudBackupSnapshotKey),
              let snapshot = try? JSONDecoder().decode(BackupSnapshot.self, from: data)
        else {
            iCloudBackupSummary = nil
            return
        }

        iCloudBackupSummary = CloudBackupSummary(
            generatedAt: snapshot.generatedAt,
            totalEntryCount: snapshot.entries.count,
            totalBookCount: snapshot.books.count,
            totalAccountCount: snapshot.accounts.count,
            totalCategorySchemeCount: snapshot.categorySchemes.count,
            appVersion: snapshot.appVersion,
            backupVersion: snapshot.backupVersion,
            fileSizeDescription: ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))
    }

    private var currentPersistedState: LedgerPersistenceSnapshot {
        LedgerPersistenceSnapshot(
            appSettings: appSettings,
            budgetLimit: budgetLimit,
            bookBudgets: bookBudgets,
            categoryBudgets: categoryBudgets,
            entries: entries,
            books: books,
            selectedBookID: selectedBookID,
            accounts: accounts,
            categorySchemes: categorySchemes,
            selectedCategorySchemeID: selectedCategorySchemeID,
            scheduledEntries: scheduledEntries,
            savingPlans: savingPlans)
    }

    private func encodedBackupSnapshot() -> Data? {
        flushPendingSettingsPersistence()
        flushPendingLedgerStatePersistence()

        return try? JSONEncoder().encode(
            BackupSnapshot(
                generatedAt: Date(),
                backupVersion: "v1.0",
                appVersion: appVersionString,
                appSettings: appSettings,
                budgetLimit: budgetLimit,
                bookBudgets: bookBudgets,
                categoryBudgets: categoryBudgets,
                entries: entries,
                books: books,
                selectedBookID: selectedBookID,
                accounts: accounts,
                categorySchemes: categorySchemes,
                selectedCategorySchemeID: selectedCategorySchemeID,
                scheduledEntries: scheduledEntries,
                savingPlans: savingPlans))
    }

    private func applyBackupSnapshot(_ snapshot: BackupSnapshot) {
        applyPersistedState(
            LedgerPersistenceSnapshot(
                appSettings: snapshot.appSettings,
                budgetLimit: snapshot.budgetLimit,
                bookBudgets: snapshot.bookBudgets,
                categoryBudgets: snapshot.categoryBudgets,
                entries: snapshot.entries,
                books: snapshot.books,
                selectedBookID: snapshot.selectedBookID,
                accounts: snapshot.accounts,
                categorySchemes: snapshot.categorySchemes,
                selectedCategorySchemeID: snapshot.selectedCategorySchemeID,
                scheduledEntries: snapshot.scheduledEntries,
                savingPlans: snapshot.savingPlans))
    }

    private func applyPersistedState(_ snapshot: LedgerPersistenceSnapshot) {
        let fallbackSeed = LedgerStore.makeSeedData()
        let restoredBooks = snapshot.books.isEmpty ? fallbackSeed.books : snapshot.books
        let restoredSchemes = snapshot.categorySchemes.isEmpty ? LedgerCategoryScheme.defaultSchemes : snapshot
            .categorySchemes
        let resolvedBookID = restoredBooks.contains(where: { $0.id == snapshot.selectedBookID }) ? snapshot
            .selectedBookID : restoredBooks[0].id
        let resolvedSchemeID = restoredSchemes
            .contains(where: { $0.id == snapshot.selectedCategorySchemeID }) ? snapshot
            .selectedCategorySchemeID : restoredSchemes[0].id

        appSettings = snapshot.appSettings
        books = restoredBooks
        accounts = snapshot.accounts
        categorySchemes = restoredSchemes
        selectedBookID = resolvedBookID
        selectedCategorySchemeID = resolvedSchemeID
        entries = snapshot.entries
            .map { normalizedEntry($0, fallbackBookID: resolvedBookID) }
            .sorted { $0.date > $1.date }
        bookBudgets = migratedBookBudgets(
            snapshot.bookBudgets,
            legacyBudgetLimit: snapshot.budgetLimit,
            books: restoredBooks,
            fallbackBookID: resolvedBookID)
        categoryBudgets = sanitizedCategoryBudgets(
            snapshot.categoryBudgets,
            books: restoredBooks)
        for entry in scheduledEntries {
            cancelNotificationForEntry(entry)
        }
        scheduledEntries = snapshot.scheduledEntries
        for entry in scheduledEntries where entry.isEnabled {
            scheduleNotificationForEntry(entry)
        }
        savingPlans = snapshot.savingPlans
        clearHistoryPresentation()
        clearEntryNavigationRequest()
        flushPendingSettingsPersistence()
        flushPendingLedgerStatePersistence()
        syncWidgetSnapshot()
    }

    private var appVersionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private struct LocalBackupSnapshot: Codable {
        let generatedAt: Date
        let appSettings: AppSettings
        let budgetLimit: Double?
        let selectedBookName: String
        let totalEntryCount: Int
        let totalBookCount: Int
        let totalAccountCount: Int
        let totalCategorySchemeCount: Int
    }

    private struct BackupSnapshot: Codable {
        let generatedAt: Date
        let backupVersion: String
        let appVersion: String
        let appSettings: AppSettings
        let budgetLimit: Double?
        let bookBudgets: [LedgerBookBudget]
        let categoryBudgets: [LedgerCategoryBudget]
        let entries: [LedgerEntry]
        let books: [LedgerBook]
        let selectedBookID: UUID
        let accounts: [LedgerAccount]
        let categorySchemes: [LedgerCategoryScheme]
        let selectedCategorySchemeID: UUID
        let scheduledEntries: [ScheduledLedgerEntry]
        let savingPlans: [SavingPlan]

        private enum CodingKeys: String, CodingKey {
            case generatedAt
            case backupVersion
            case appVersion
            case appSettings
            case budgetLimit
            case bookBudgets
            case categoryBudgets
            case entries
            case books
            case selectedBookID
            case accounts
            case categorySchemes
            case selectedCategorySchemeID
            case scheduledEntries
            case savingPlans
        }

        init(
            generatedAt: Date,
            backupVersion: String,
            appVersion: String,
            appSettings: AppSettings,
            budgetLimit: Double?,
            bookBudgets: [LedgerBookBudget],
            categoryBudgets: [LedgerCategoryBudget],
            entries: [LedgerEntry],
            books: [LedgerBook],
            selectedBookID: UUID,
            accounts: [LedgerAccount],
            categorySchemes: [LedgerCategoryScheme],
            selectedCategorySchemeID: UUID,
            scheduledEntries: [ScheduledLedgerEntry] = [],
            savingPlans: [SavingPlan] = []) {
            self.generatedAt = generatedAt
            self.backupVersion = backupVersion
            self.appVersion = appVersion
            self.appSettings = appSettings
            self.budgetLimit = budgetLimit
            self.bookBudgets = bookBudgets
            self.categoryBudgets = categoryBudgets
            self.entries = entries
            self.books = books
            self.selectedBookID = selectedBookID
            self.accounts = accounts
            self.categorySchemes = categorySchemes
            self.selectedCategorySchemeID = selectedCategorySchemeID
            self.scheduledEntries = scheduledEntries
            self.savingPlans = savingPlans
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            generatedAt = try container.decode(Date.self, forKey: .generatedAt)
            backupVersion = try container.decode(String.self, forKey: .backupVersion)
            appVersion = try container.decode(String.self, forKey: .appVersion)
            appSettings = try container.decode(AppSettings.self, forKey: .appSettings)
            budgetLimit = try container.decodeIfPresent(Double.self, forKey: .budgetLimit)
            bookBudgets = try container.decodeIfPresent([LedgerBookBudget].self, forKey: .bookBudgets) ?? []
            categoryBudgets = try container.decodeIfPresent([LedgerCategoryBudget].self, forKey: .categoryBudgets) ?? []
            entries = try container.decodeIfPresent([LedgerEntry].self, forKey: .entries) ?? []
            books = try container.decodeIfPresent([LedgerBook].self, forKey: .books) ?? []
            selectedBookID = try container.decodeIfPresent(UUID.self, forKey: .selectedBookID) ?? UUID()
            accounts = try container.decodeIfPresent([LedgerAccount].self, forKey: .accounts) ?? []
            categorySchemes = try container.decodeIfPresent([LedgerCategoryScheme].self, forKey: .categorySchemes) ?? []
            selectedCategorySchemeID = try container
                .decodeIfPresent(UUID.self, forKey: .selectedCategorySchemeID) ?? UUID()
            scheduledEntries = try container
                .decodeIfPresent([ScheduledLedgerEntry].self, forKey: .scheduledEntries) ?? []
            savingPlans = try container.decodeIfPresent([SavingPlan].self, forKey: .savingPlans) ?? []
        }
    }

    private struct SeedState {
        let bookBudgets: [LedgerBookBudget]
        let categoryBudgets: [LedgerCategoryBudget]
        let books: [LedgerBook]
        let selectedBookID: UUID
        let accounts: [LedgerAccount]
        let categorySchemes: [LedgerCategoryScheme]
        let selectedCategorySchemeID: UUID
        let entries: [LedgerEntry]
    }

    private nonisolated static func makeSeedData() -> SeedState {
        let now = Date()
        let calendar = Calendar.current

        let totalBook = LedgerBook(
            name: "总账本",
            note: "全部生活收支",
            createdAt: calendar.date(byAdding: .day, value: -20, to: now) ?? now,
            icon: "star.square.fill",
            tintStyle: .gold)

        let workBook = LedgerBook(
            name: "工作账本",
            note: "差旅和项目收支",
            createdAt: calendar.date(byAdding: .day, value: -8, to: now) ?? now,
            icon: "briefcase.fill",
            tintStyle: .accent)

        let schemes = LedgerCategoryScheme.defaultSchemes
        let defaultScheme = schemes[0]
        let workScheme = schemes[1]

        let accounts = [
            LedgerAccount(
                templateID: "wechat",
                name: "微信余额",
                icon: "message.fill",
                tintStyle: .mint,
                group: .asset,
                balance: 1480),
            LedgerAccount(
                templateID: "bank",
                name: "招商储蓄卡",
                icon: "creditcard.fill",
                tintStyle: .accent,
                group: .asset,
                balance: 8650),
            LedgerAccount(
                templateID: "yuebao",
                name: "余额宝",
                icon: "wallet.pass.fill",
                tintStyle: .gold,
                group: .investment,
                balance: 3600),
            LedgerAccount(
                templateID: "credit-card",
                name: "信用卡",
                icon: "creditcard.trianglebadge.exclamationmark",
                tintStyle: .coral,
                group: .credit,
                balance: 920)
        ]

        let meal = defaultScheme.expenseCategories.first(where: { $0.id == "expense.meal" }) ?? LedgerCategory
            .defaultCategory(for: .expense)
        let shopping = defaultScheme.expenseCategories.first(where: { $0.id == "expense.shopping" }) ?? LedgerCategory
            .defaultCategory(for: .expense)
        let transit = defaultScheme.expenseCategories.first(where: { $0.id == "expense.transit" }) ?? LedgerCategory
            .defaultCategory(for: .expense)
        let health = defaultScheme.expenseCategories.first(where: { $0.id == "expense.health" }) ?? LedgerCategory
            .defaultCategory(for: .expense)
        let salary = defaultScheme.incomeCategories.first(where: { $0.id == "income.salary" }) ?? LedgerCategory
            .defaultCategory(for: .income)
        let refund = defaultScheme.incomeCategories.first(where: { $0.id == "income.refund" }) ?? LedgerCategory
            .defaultCategory(for: .income)
        let trip = workScheme.expenseCategories.first(where: { $0.id == "work.trip" }) ?? LedgerCategory
            .defaultCategory(for: .expense)
        let software = workScheme.expenseCategories.first(where: { $0.id == "work.software" }) ?? LedgerCategory
            .defaultCategory(for: .expense)
        let project = workScheme.incomeCategories.first(where: { $0.id == "work.project" }) ?? LedgerCategory
            .defaultCategory(for: .income)

        let bookBudgets = [
            LedgerBookBudget(bookID: totalBook.id, monthlyLimit: 3600),
            LedgerBookBudget(bookID: workBook.id, monthlyLimit: 2400)
        ]

        let categoryBudgets = [
            LedgerCategoryBudget(bookID: totalBook.id, categoryID: meal.id, monthlyLimit: 900),
            LedgerCategoryBudget(bookID: totalBook.id, categoryID: shopping.id, monthlyLimit: 1100),
            LedgerCategoryBudget(bookID: totalBook.id, categoryID: transit.id, monthlyLimit: 480),
            LedgerCategoryBudget(bookID: workBook.id, categoryID: trip.id, monthlyLimit: 1400),
            LedgerCategoryBudget(bookID: workBook.id, categoryID: software.id, monthlyLimit: 500)
        ]

        let entries = [
            LedgerEntry(
                bookID: totalBook.id,
                title: "工作日午餐",
                amount: 32,
                kind: .expense,
                category: meal,
                paymentMethod: "微信余额",
                note: "楼下面馆",
                date: calendar.date(byAdding: .day, value: -1, to: now) ?? now),
            LedgerEntry(
                bookID: totalBook.id,
                title: "地铁通勤",
                amount: 18,
                kind: .expense,
                category: transit,
                paymentMethod: "支付宝",
                note: "",
                date: calendar.date(byAdding: .day, value: -2, to: now) ?? now),
            LedgerEntry(
                bookID: totalBook.id,
                title: "买菜补货",
                amount: 128,
                kind: .expense,
                category: shopping,
                paymentMethod: "招商储蓄卡",
                note: "",
                date: calendar.date(byAdding: .day, value: -3, to: now) ?? now),
            LedgerEntry(
                bookID: totalBook.id,
                title: "体检报销差额",
                amount: 89,
                kind: .expense,
                category: health,
                paymentMethod: "信用卡",
                note: "",
                date: calendar.date(byAdding: .day, value: -6, to: now) ?? now),
            LedgerEntry(
                bookID: totalBook.id,
                title: "四月工资",
                amount: 9800,
                kind: .income,
                category: salary,
                paymentMethod: "招商储蓄卡",
                note: "",
                date: calendar.date(byAdding: .day, value: -4, to: now) ?? now),
            LedgerEntry(
                bookID: totalBook.id,
                title: "退货退款",
                amount: 66,
                kind: .income,
                category: refund,
                paymentMethod: "支付宝",
                note: "",
                date: calendar.date(byAdding: .day, value: -7, to: now) ?? now),
            LedgerEntry(
                bookID: workBook.id,
                title: "上海差旅",
                amount: 560,
                kind: .expense,
                category: trip,
                paymentMethod: "信用卡",
                note: "来回高铁",
                date: calendar.date(byAdding: .day, value: -5, to: now) ?? now),
            LedgerEntry(
                bookID: workBook.id,
                title: "设计工具订阅",
                amount: 88,
                kind: .expense,
                category: software,
                paymentMethod: "支付宝",
                note: "",
                date: calendar.date(byAdding: .day, value: -9, to: now) ?? now),
            LedgerEntry(
                bookID: workBook.id,
                title: "项目首款",
                amount: 12000,
                kind: .income,
                category: project,
                paymentMethod: "招商储蓄卡",
                note: "",
                date: calendar.date(byAdding: .day, value: -10, to: now) ?? now)
        ]

        return SeedState(
            bookBudgets: bookBudgets,
            categoryBudgets: categoryBudgets,
            books: [totalBook, workBook],
            selectedBookID: totalBook.id,
            accounts: accounts,
            categorySchemes: schemes,
            selectedCategorySchemeID: defaultScheme.id,
            entries: entries)
    }

    nonisolated static func makeSeedPersistedState(appSettings: AppSettings = AppSettings())
        -> LedgerPersistenceSnapshot {
        let seed = makeSeedData()
        let selectedBookBudget = seed.bookBudgets.first(where: { $0.bookID == seed.selectedBookID })?.monthlyLimit

        return LedgerPersistenceSnapshot(
            appSettings: appSettings,
            budgetLimit: selectedBookBudget,
            bookBudgets: seed.bookBudgets,
            categoryBudgets: seed.categoryBudgets,
            entries: seed.entries,
            books: seed.books,
            selectedBookID: seed.selectedBookID,
            accounts: seed.accounts,
            categorySchemes: seed.categorySchemes,
            selectedCategorySchemeID: seed.selectedCategorySchemeID)
    }
}
