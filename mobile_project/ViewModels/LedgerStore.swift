import SwiftUI

@MainActor
final class LedgerStore: ObservableObject {
    @Published var isBalanceVisible = true
    @Published var isQuickAddPresented = false
    @Published private(set) var autoLedgerPendingLaunch: AutoLedgerLaunchPayload?
    @Published private(set) var autoLedgerShortcutStatus = AutoLedgerHandoffStore.loadStatus()
    @Published var appSettings: AppSettings {
        didSet {
            guard appSettings != oldValue else { return }
            schedulePersistAppSettings()
            schedulePersistLedgerState()
            if appSettings.monthStartDay != oldValue.monthStartDay {
                syncWidgetSnapshot()
            }
        }
    }
    @Published private(set) var bookBudgets: [LedgerBookBudget] {
        didSet {
            schedulePersistLedgerState()
            syncWidgetSnapshot()
        }
    }
    @Published private(set) var categoryBudgets: [LedgerCategoryBudget] {
        didSet {
            schedulePersistLedgerState()
            syncWidgetSnapshot()
        }
    }
    @Published private(set) var entries: [LedgerEntry] {
        didSet {
            schedulePersistLedgerState()
            syncWidgetSnapshot()
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
    @Published private(set) var lastBackupDate: Date?
    @Published private(set) var iCloudBackupSummary: CloudBackupSummary?

    private let calendar = Calendar.current
    private let appSettingsKey = "ledger.app.settings"
    private let persistedStateKey = "ledger.app.persisted.state"
    private let localBackupSnapshotKey = "ledger.local.backup.snapshot"
    private let localBackupDateKey = "ledger.local.backup.date"
    private let iCloudBackupSnapshotKey = "ledger.icloud.backup.snapshot"
    private var settingsPersistTask: Task<Void, Never>?
    private var statePersistTask: Task<Void, Never>?
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
        lastBackupDate = nil
        iCloudBackupSummary = nil
        appSettings = loadAppSettings()
        lastBackupDate = loadLastBackupDate()
        restorePersistedStateIfAvailable()
        configureICloudSync()
        refreshICloudBackupSummary()
        syncWidgetSnapshot()
        refreshAutoLedgerShortcutState()
    }

    deinit {
        settingsPersistTask?.cancel()
        statePersistTask?.cancel()
        if let iCloudObserver {
            NotificationCenter.default.removeObserver(iCloudObserver)
        }
    }

    var paymentMethods: [String] {
        uniqueStrings(
            accounts
                .filter { $0.group != .credit && $0.group != .loan }
                .map(\.name) + ["支付宝", "微信", "银行卡", "现金"])
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

    var budgetLimit: Double? {
        bookBudget(for: currentBook.id)?.monthlyLimit
    }

    var currentMonthExpense: Double {
        monthlyTotal(kind: .expense, for: currentBook.id)
    }

    var currentMonthIncome: Double {
        monthlyTotal(kind: .income, for: currentBook.id)
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
        return min(currentMonthExpense / budgetLimit, 1)
    }

    var currentBudgetRemaining: Double? {
        guard let budgetLimit else { return nil }
        return max(budgetLimit - currentMonthExpense, 0)
    }

    var currentBudgetOverspent: Double {
        guard let budgetLimit else { return 0 }
        return max(currentMonthExpense - budgetLimit, 0)
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
            "简洁模式：我会先给结论，再补充必要信息。"
        case .balanced:
            "平衡模式：结论和说明都会保留，阅读节奏更稳。"
        case .detailed:
            "详细模式：会补充更多上下文与步骤，适合慢慢看。"
        }
    }

    var hasPendingAutoLedgerLaunch: Bool {
        autoLedgerPendingLaunch != nil
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

    func makeDraft() -> QuickEntryDraft {
        QuickEntryDraft(
            kind: .expense,
            amountText: "",
            selectedCategory: categories(for: .expense).first ?? LedgerCategory.defaultCategory(for: .expense),
            paymentMethod: paymentMethods.first ?? "支付宝",
            note: "")
    }

    func addEntry(from draft: QuickEntryDraft) {
        guard let amount = draft.parsedAmount, amount > 0 else { return }

        let category = categories(for: draft.kind).first(where: { $0.id == draft.selectedCategory.id }) ?? draft
            .selectedCategory
        let title = draft.note.isEmpty ? category.name : draft.note

        addEntry(
            kind: draft.kind,
            amount: amount,
            category: category,
            paymentMethod: draft.paymentMethod,
            note: draft.note,
            title: title,
            date: Date())
    }

    func refreshAutoLedgerShortcutState() {
        autoLedgerPendingLaunch = AutoLedgerHandoffStore.peekPendingLaunch()
        autoLedgerShortcutStatus = AutoLedgerHandoffStore.loadStatus()
    }

    func consumeAutoLedgerPendingLaunch() -> AutoLedgerLaunchPayload? {
        let payload = AutoLedgerHandoffStore.consumePendingLaunch()
        autoLedgerPendingLaunch = nil
        autoLedgerShortcutStatus = AutoLedgerHandoffStore.loadStatus()
        return payload
    }

    func addEntry(
        kind: LedgerKind,
        amount: Double,
        category: LedgerCategory,
        paymentMethod: String,
        note: String,
        title: String,
        date: Date) {
        let entry = LedgerEntry(
            bookID: currentBook.id,
            title: title,
            amount: amount,
            kind: kind,
            category: category,
            paymentMethod: paymentMethod,
            note: note,
            date: date)

        entries.insert(entry, at: 0)
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
        monthlyTotal(kind: .expense, for: book.id)
    }

    func bookMonthlyIncome(_ book: LedgerBook) -> Double {
        monthlyTotal(kind: .income, for: book.id)
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

    private func monthlyTotal(kind: LedgerKind, for bookID: UUID) -> Double {
        let interval = currentStatisticsMonthInterval
        return entries
            .filter { entry in
                entry.bookID == bookID &&
                    entry.kind == kind &&
                    interval.contains(entry.date)
            }
            .reduce(0) { $0 + $1.amount }
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

    private func syncWidgetSnapshot() {
        LedgerWidgetSnapshotStore.save(makeWidgetSnapshot())
    }

    private func makeWidgetSnapshot() -> LedgerWidgetSnapshot {
        let todayExpenseEntries = todayEntries.filter { $0.kind == .expense }
        let grouped = Dictionary(grouping: todayExpenseEntries, by: { $0.category.id })

        let topCategories = grouped.compactMap { _, items -> LedgerWidgetCategorySnapshot? in
            guard let first = items.first else { return nil }
            let total = items.reduce(0) { $0 + $1.amount }
            return LedgerWidgetCategorySnapshot(
                id: first.category.id,
                name: first.category.name,
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
        guard let data = UserDefaults.standard.data(forKey: appSettingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }
        return settings
    }

    private func schedulePersistAppSettings() {
        settingsPersistTask?.cancel()

        let currentSettings = appSettings
        let key = appSettingsKey
        settingsPersistTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            guard let data = try? JSONEncoder().encode(currentSettings) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func schedulePersistLedgerState() {
        statePersistTask?.cancel()

        let snapshot = currentPersistedState
        let key = persistedStateKey
        statePersistTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func flushPendingSettingsPersistence() {
        settingsPersistTask?.cancel()
        settingsPersistTask = nil
        guard let data = try? JSONEncoder().encode(appSettings) else { return }
        UserDefaults.standard.set(data, forKey: appSettingsKey)
    }

    func flushPendingLedgerStatePersistence() {
        statePersistTask?.cancel()
        statePersistTask = nil
        guard let data = try? JSONEncoder().encode(currentPersistedState) else { return }
        UserDefaults.standard.set(data, forKey: persistedStateKey)
    }

    private func loadLastBackupDate() -> Date? {
        UserDefaults.standard.object(forKey: localBackupDateKey) as? Date
    }

    private func restorePersistedStateIfAvailable() {
        guard let data = UserDefaults.standard.data(forKey: persistedStateKey),
              let snapshot = try? JSONDecoder().decode(PersistedLedgerState.self, from: data)
        else {
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

    private var currentPersistedState: PersistedLedgerState {
        PersistedLedgerState(
            appSettings: appSettings,
            budgetLimit: budgetLimit,
            bookBudgets: bookBudgets,
            categoryBudgets: categoryBudgets,
            entries: entries,
            books: books,
            selectedBookID: selectedBookID,
            accounts: accounts,
            categorySchemes: categorySchemes,
            selectedCategorySchemeID: selectedCategorySchemeID)
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
                selectedCategorySchemeID: selectedCategorySchemeID))
    }

    private func applyBackupSnapshot(_ snapshot: BackupSnapshot) {
        applyPersistedState(
            PersistedLedgerState(
                appSettings: snapshot.appSettings,
                budgetLimit: snapshot.budgetLimit,
                bookBudgets: snapshot.bookBudgets,
                categoryBudgets: snapshot.categoryBudgets,
                entries: snapshot.entries,
                books: snapshot.books,
                selectedBookID: snapshot.selectedBookID,
                accounts: snapshot.accounts,
                categorySchemes: snapshot.categorySchemes,
                selectedCategorySchemeID: snapshot.selectedCategorySchemeID))
    }

    private func applyPersistedState(_ snapshot: PersistedLedgerState) {
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
        entries = snapshot.entries
        accounts = snapshot.accounts
        books = restoredBooks
        categorySchemes = restoredSchemes
        selectedBookID = resolvedBookID
        selectedCategorySchemeID = resolvedSchemeID
        bookBudgets = migratedBookBudgets(
            snapshot.bookBudgets,
            legacyBudgetLimit: snapshot.budgetLimit,
            books: restoredBooks,
            fallbackBookID: resolvedBookID)
        categoryBudgets = sanitizedCategoryBudgets(
            snapshot.categoryBudgets,
            books: restoredBooks)
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

    private struct PersistedLedgerState: Codable {
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
            selectedCategorySchemeID: UUID) {
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
            selectedCategorySchemeID = try container
                .decodeIfPresent(UUID.self, forKey: .selectedCategorySchemeID) ?? UUID()
        }
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
            selectedCategorySchemeID: UUID) {
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

    private static func makeSeedData() -> SeedState {
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
}
