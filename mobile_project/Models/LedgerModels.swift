import SwiftUI

enum LedgerKind: String, CaseIterable, Identifiable, Codable {
    case expense = "支出"
    case income = "收入"

    var id: String { rawValue }

    // Stable identifier for storage IDs; avoid localized display text.
    var storageKey: String {
        switch self {
        case .expense:
            "expense"
        case .income:
            "income"
        }
    }
}

enum LedgerTintStyle: String, CaseIterable, Identifiable, Codable {
    case accent
    case gold
    case mint
    case lavender
    case coral
    case expense
    case income

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .accent:
            .ledgerAccent
        case .gold:
            .ledgerGold
        case .mint:
            .ledgerMint
        case .lavender:
            .ledgerLavender
        case .coral:
            .ledgerCoral
        case .expense:
            .ledgerExpense
        case .income:
            .ledgerIncome
        }
    }

    var title: String {
        switch self {
        case .accent:
            "蓝"
        case .gold:
            "金"
        case .mint:
            "青"
        case .lavender:
            "紫"
        case .coral:
            "橙"
        case .expense:
            "红"
        case .income:
            "绿"
        }
    }
}

struct LedgerCategory: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let icon: String
    let tintStyle: LedgerTintStyle
    let kind: LedgerKind

    var tint: Color { tintStyle.color }

    static func == (lhs: LedgerCategory, rhs: LedgerCategory) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct LedgerBook: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let note: String
    let createdAt: Date
    let icon: String
    let tintStyle: LedgerTintStyle

    init(
        id: UUID = UUID(),
        name: String,
        note: String,
        createdAt: Date,
        icon: String,
        tintStyle: LedgerTintStyle) {
        self.id = id
        self.name = name
        self.note = note
        self.createdAt = createdAt
        self.icon = icon
        self.tintStyle = tintStyle
    }
}

enum LedgerAccountGroup: String, CaseIterable, Identifiable, Codable {
    case asset
    case credit
    case recharge
    case investment
    case loan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .asset:
            "资金账户"
        case .credit:
            "信用账户"
        case .recharge:
            "充值账户"
        case .investment:
            "理财账户"
        case .loan:
            "借贷账户"
        }
    }

    var subtitle: String {
        switch self {
        case .asset:
            "资产"
        case .credit:
            "负债"
        case .recharge:
            "资产"
        case .investment:
            "资产"
        case .loan:
            "往来"
        }
    }

    var affectsAssets: Bool {
        switch self {
        case .asset, .recharge, .investment:
            true
        case .credit, .loan:
            false
        }
    }

    var accent: Color {
        switch self {
        case .asset:
            .ledgerMint
        case .credit:
            .ledgerCoral
        case .recharge:
            .ledgerGold
        case .investment:
            .ledgerAccent
        case .loan:
            .ledgerLavender
        }
    }
}

struct LedgerAccountTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let tintStyle: LedgerTintStyle
    let group: LedgerAccountGroup
}

struct LedgerAccount: Identifiable, Hashable, Codable {
    let id: UUID
    let templateID: String
    let name: String
    let icon: String
    let tintStyle: LedgerTintStyle
    let group: LedgerAccountGroup
    let balance: Double

    init(
        id: UUID = UUID(),
        templateID: String,
        name: String,
        icon: String,
        tintStyle: LedgerTintStyle,
        group: LedgerAccountGroup,
        balance: Double) {
        self.id = id
        self.templateID = templateID
        self.name = name
        self.icon = icon
        self.tintStyle = tintStyle
        self.group = group
        self.balance = balance
    }

    var tint: Color { tintStyle.color }
}

struct LedgerCategoryScheme: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let note: String
    let expenseCategories: [LedgerCategory]
    let incomeCategories: [LedgerCategory]

    init(
        id: UUID = UUID(),
        name: String,
        note: String,
        expenseCategories: [LedgerCategory],
        incomeCategories: [LedgerCategory]) {
        self.id = id
        self.name = name
        self.note = note
        self.expenseCategories = expenseCategories
        self.incomeCategories = incomeCategories
    }
}

struct LedgerEntry: Identifiable, Codable {
    var id: UUID
    var bookID: UUID
    var title: String
    var amount: Double
    var kind: LedgerKind
    var category: LedgerCategory
    var paymentMethod: String
    var accountID: UUID?
    var tags: [String]
    var note: String
    var date: Date
    var isExcludedFromStatistics: Bool
    var isExcludedFromBudget: Bool
    var screenshotData: Data?

    private enum CodingKeys: String, CodingKey {
        case id
        case bookID
        case title
        case amount
        case kind
        case category
        case paymentMethod
        case accountID
        case tags
        case note
        case date
        case isExcludedFromStatistics
        case isExcludedFromBudget
        case screenshotData
    }

    init(
        id: UUID = UUID(),
        bookID: UUID,
        title: String,
        amount: Double,
        kind: LedgerKind,
        category: LedgerCategory,
        paymentMethod: String,
        accountID: UUID? = nil,
        tags: [String] = [],
        note: String,
        date: Date,
        isExcludedFromStatistics: Bool = false,
        isExcludedFromBudget: Bool = false,
        screenshotData: Data? = nil) {
        self.id = id
        self.bookID = bookID
        self.title = title
        self.amount = amount
        self.kind = kind
        self.category = category
        self.paymentMethod = paymentMethod
        self.accountID = accountID
        self.tags = tags
        self.note = note
        self.date = date
        self.isExcludedFromStatistics = isExcludedFromStatistics
        self.isExcludedFromBudget = isExcludedFromStatistics ? true : isExcludedFromBudget
        self.screenshotData = screenshotData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        bookID = try container.decode(UUID.self, forKey: .bookID)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        amount = try container.decodeIfPresent(Double.self, forKey: .amount) ?? 0
        kind = try container.decodeIfPresent(LedgerKind.self, forKey: .kind) ?? .expense
        category = try container.decodeIfPresent(LedgerCategory.self, forKey: .category)
            ?? LedgerCategory.defaultCategory(for: kind)
        paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod) ?? ""
        accountID = try container.decodeIfPresent(UUID.self, forKey: .accountID)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        isExcludedFromStatistics = try container.decodeIfPresent(Bool.self, forKey: .isExcludedFromStatistics) ?? false
        let decodedBudgetExclusion = try container.decodeIfPresent(Bool.self, forKey: .isExcludedFromBudget) ?? false
        isExcludedFromBudget = isExcludedFromStatistics ? true : decodedBudgetExclusion
        screenshotData = try container.decodeIfPresent(Data.self, forKey: .screenshotData)
    }
}

struct LedgerBookBudget: Identifiable, Hashable, Codable {
    let id: UUID
    let bookID: UUID
    let monthlyLimit: Double
    let createdAt: Date

    init(
        id: UUID = UUID(),
        bookID: UUID,
        monthlyLimit: Double,
        createdAt: Date = Date()) {
        self.id = id
        self.bookID = bookID
        self.monthlyLimit = monthlyLimit
        self.createdAt = createdAt
    }
}

struct LedgerCategoryBudget: Identifiable, Hashable, Codable {
    let id: UUID
    let bookID: UUID
    let categoryID: String
    let monthlyLimit: Double
    let createdAt: Date

    init(
        id: UUID = UUID(),
        bookID: UUID,
        categoryID: String,
        monthlyLimit: Double,
        createdAt: Date = Date()) {
        self.id = id
        self.bookID = bookID
        self.categoryID = categoryID
        self.monthlyLimit = monthlyLimit
        self.createdAt = createdAt
    }
}

struct LedgerBudgetCategorySummary: Identifiable {
    let budget: LedgerCategoryBudget
    let category: LedgerCategory
    let spent: Double

    var id: UUID { budget.id }

    var remaining: Double {
        max(budget.monthlyLimit - spent, 0)
    }

    var overspent: Double {
        max(spent - budget.monthlyLimit, 0)
    }

    var progress: Double {
        guard budget.monthlyLimit > 0 else { return 0 }
        return min(spent / budget.monthlyLimit, 1)
    }
}

struct QuickEntryDraft {
    var bookID: UUID?
    var kind: LedgerKind = .expense
    var titleText = ""
    var amountText = ""
    var selectedCategory = LedgerCategory.defaultCategory(for: .expense)
    var accountID: UUID?
    var paymentMethod = "支付宝"
    var tags: [String] = []
    var note = ""
    var date = Date()
    var isExcludedFromStatistics = false
    var isExcludedFromBudget = false

    var parsedAmount: Double? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}

enum LedgerHistoryScope: String, CaseIterable, Identifiable, Codable {
    case currentBook = "当前账本"
    case allBooks = "全部账本"

    var id: String { rawValue }
}

struct LedgerHistoryPresentation: Equatable {
    var scope: LedgerHistoryScope = .currentBook
    var highlightedEntryIDs: [UUID] = []
    var prefersFocusedBatch = false
    var title: String?
}

enum LedgerNavigationDestination: Equatable {
    case detail(entryID: UUID)
    case history(LedgerHistoryPresentation)
}

struct LedgerNavigationRequest: Identifiable, Equatable {
    let id = UUID()
    let destination: LedgerNavigationDestination
}

enum DrawerDestination: Hashable {
    case screen(ManagementScreen)
    case placeholder(String)
}

struct DrawerShortcut: Identifiable {
    let id: String
    let title: String
    let icon: String
    let accent: Color
    let destination: DrawerDestination
}

struct DrawerLinkItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let accent: Color
    let showsBadge: Bool
    let destination: DrawerDestination
}

enum AssistantReplyStyle: String, CaseIterable, Identifiable, Codable {
    case concise
    case balanced
    case detailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .concise:
            "简洁"
        case .balanced:
            "平衡"
        case .detailed:
            "详细"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var monthStartDay: Int = 1
    var assistantReplyStyle: AssistantReplyStyle = .balanced
    var showRecordImages = true
    var showLocation = true
    var showOfferRecommendations = true
    var hideSensitiveInfo = true
    var pushEnabled = true
    var pushDailyLedger = true
    var pushBudgetReminder = true
    var pushFeatureRecommendation = true
    var pushBillReview = true
    var hasSeenShortcutInstallGuide = false
    var hasAcknowledgedShortcutInstall = false
    var preferredTriggerMode: AutoLedgerPreferredTriggerMode = .assistiveTouch
    var lastShortcutEducationState: AutoLedgerShortcutEducationState = .install

    init() {}

    var monthStartDayLabel: String {
        "每月\(monthStartDay)日"
    }

    private enum CodingKeys: String, CodingKey {
        case monthStartDay
        case assistantReplyStyle
        case showRecordImages
        case showLocation
        case showOfferRecommendations
        case hideSensitiveInfo
        case pushEnabled
        case pushDailyLedger
        case pushBudgetReminder
        case pushFeatureRecommendation
        case pushBillReview
        case hasSeenShortcutInstallGuide
        case hasAcknowledgedShortcutInstall
        case preferredTriggerMode
        case lastShortcutEducationState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedMonthStartDay = try container.decodeIfPresent(Int.self, forKey: .monthStartDay) ?? 1
        monthStartDay = min(max(decodedMonthStartDay, 1), 28)
        assistantReplyStyle = try container
            .decodeIfPresent(AssistantReplyStyle.self, forKey: .assistantReplyStyle) ?? .balanced
        showRecordImages = try container.decodeIfPresent(Bool.self, forKey: .showRecordImages) ?? true
        showLocation = try container.decodeIfPresent(Bool.self, forKey: .showLocation) ?? true
        showOfferRecommendations = try container.decodeIfPresent(Bool.self, forKey: .showOfferRecommendations) ?? true
        hideSensitiveInfo = try container.decodeIfPresent(Bool.self, forKey: .hideSensitiveInfo) ?? true
        pushEnabled = try container.decodeIfPresent(Bool.self, forKey: .pushEnabled) ?? true
        pushDailyLedger = try container.decodeIfPresent(Bool.self, forKey: .pushDailyLedger) ?? true
        pushBudgetReminder = try container.decodeIfPresent(Bool.self, forKey: .pushBudgetReminder) ?? true
        pushFeatureRecommendation = try container.decodeIfPresent(Bool.self, forKey: .pushFeatureRecommendation) ?? true
        pushBillReview = try container.decodeIfPresent(Bool.self, forKey: .pushBillReview) ?? true
        hasSeenShortcutInstallGuide = try container
            .decodeIfPresent(Bool.self, forKey: .hasSeenShortcutInstallGuide) ?? false
        hasAcknowledgedShortcutInstall = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasAcknowledgedShortcutInstall) ?? false
        preferredTriggerMode = try container
            .decodeIfPresent(AutoLedgerPreferredTriggerMode.self, forKey: .preferredTriggerMode) ?? .assistiveTouch
        lastShortcutEducationState = try container
            .decodeIfPresent(AutoLedgerShortcutEducationState.self, forKey: .lastShortcutEducationState) ?? .install
    }
}

extension LedgerCategory {
    static let expenseCategories: [LedgerCategory] = [
        LedgerCategory(
            id: "expense.meal",
            name: "餐饮",
            icon: "fork.knife.circle.fill",
            tintStyle: .expense,
            kind: .expense),
        LedgerCategory(id: "expense.shopping", name: "购物", icon: "bag.fill", tintStyle: .gold, kind: .expense),
        LedgerCategory(id: "expense.transit", name: "交通", icon: "car.fill", tintStyle: .accent, kind: .expense),
        LedgerCategory(id: "expense.housing", name: "住房", icon: "house.fill", tintStyle: .coral, kind: .expense),
        LedgerCategory(
            id: "expense.entertainment",
            name: "休闲娱乐",
            icon: "gamecontroller.fill",
            tintStyle: .lavender,
            kind: .expense),
        LedgerCategory(id: "expense.health", name: "医疗健康", icon: "cross.case.fill", tintStyle: .mint, kind: .expense),
        LedgerCategory(id: "expense.study", name: "学习办公", icon: "book.fill", tintStyle: .accent, kind: .expense),
        LedgerCategory(id: "expense.pet", name: "宠物", icon: "pawprint.fill", tintStyle: .gold, kind: .expense),
        LedgerCategory(
            id: "expense.family",
            name: "母婴家庭",
            icon: "figure.and.child.holdinghands",
            tintStyle: .mint,
            kind: .expense),
        LedgerCategory(
            id: "expense.transfer",
            name: "资金往来",
            icon: "arrow.left.arrow.right.circle.fill",
            tintStyle: .lavender,
            kind: .expense),
        LedgerCategory(id: "expense.insurance", name: "保险理财", icon: "shield.fill", tintStyle: .coral, kind: .expense),
        LedgerCategory(id: "expense.other", name: "其他支出", icon: "shippingbox.fill", tintStyle: .expense, kind: .expense)
    ]

    static let incomeCategories: [LedgerCategory] = [
        LedgerCategory(id: "income.salary", name: "工资", icon: "banknote.fill", tintStyle: .income, kind: .income),
        LedgerCategory(id: "income.side", name: "副业", icon: "briefcase.fill", tintStyle: .accent, kind: .income),
        LedgerCategory(id: "income.bonus", name: "奖金", icon: "sparkles", tintStyle: .gold, kind: .income),
        LedgerCategory(
            id: "income.investment",
            name: "理财收益",
            icon: "chart.line.uptrend.xyaxis",
            tintStyle: .mint,
            kind: .income),
        LedgerCategory(
            id: "income.refund",
            name: "退款",
            icon: "arrow.uturn.backward.circle.fill",
            tintStyle: .lavender,
            kind: .income),
        LedgerCategory(id: "income.gift", name: "礼金", icon: "gift.fill", tintStyle: .coral, kind: .income)
    ]

    static let workExpenseCategories: [LedgerCategory] = [
        LedgerCategory(id: "work.trip", name: "差旅", icon: "airplane.circle.fill", tintStyle: .accent, kind: .expense),
        LedgerCategory(id: "work.office", name: "办公", icon: "desktopcomputer", tintStyle: .mint, kind: .expense),
        LedgerCategory(id: "work.software", name: "软件订阅", icon: "app.badge.fill", tintStyle: .lavender, kind: .expense),
        LedgerCategory(id: "work.meal", name: "商务餐饮", icon: "fork.knife.circle.fill", tintStyle: .gold, kind: .expense),
        LedgerCategory(id: "work.hardware", name: "设备采购", icon: "ipad.and.iphone", tintStyle: .coral, kind: .expense)
    ]

    static let workIncomeCategories: [LedgerCategory] = [
        LedgerCategory(
            id: "work.project",
            name: "项目回款",
            icon: "shippingbox.circle.fill",
            tintStyle: .income,
            kind: .income),
        LedgerCategory(id: "work.consult", name: "咨询费", icon: "person.wave.2.fill", tintStyle: .accent, kind: .income),
        LedgerCategory(id: "work.reimburse", name: "报销", icon: "doc.text.fill", tintStyle: .gold, kind: .income)
    ]

    static func defaultCategory(for kind: LedgerKind) -> LedgerCategory {
        switch kind {
        case .expense:
            expenseCategories.first ?? LedgerCategory(
                id: "expense.fallback",
                name: "支出",
                icon: "minus.circle.fill",
                tintStyle: .expense,
                kind: .expense)
        case .income:
            incomeCategories.first ?? LedgerCategory(
                id: "income.fallback",
                name: "收入",
                icon: "plus.circle.fill",
                tintStyle: .income,
                kind: .income)
        }
    }
}

extension LedgerCategoryScheme {
    static let defaultSchemes: [LedgerCategoryScheme] = [
        LedgerCategoryScheme(
            name: "日常生活",
            note: "适合个人日常记账",
            expenseCategories: LedgerCategory.expenseCategories,
            incomeCategories: LedgerCategory.incomeCategories),
        LedgerCategoryScheme(
            name: "项目工作",
            note: "适合差旅、项目和办公支出",
            expenseCategories: LedgerCategory.workExpenseCategories,
            incomeCategories: LedgerCategory.workIncomeCategories)
    ]
}

extension LedgerAccountTemplate {
    static let all: [LedgerAccountTemplate] = [
        LedgerAccountTemplate(id: "bank", name: "储蓄卡", icon: "creditcard.fill", tintStyle: .accent, group: .asset),
        LedgerAccountTemplate(id: "wechat", name: "微信", icon: "message.fill", tintStyle: .mint, group: .asset),
        LedgerAccountTemplate(id: "alipay", name: "支付宝", icon: "qrcode", tintStyle: .accent, group: .asset),
        LedgerAccountTemplate(id: "cash", name: "现金", icon: "banknote.fill", tintStyle: .gold, group: .asset),
        LedgerAccountTemplate(
            id: "custom-asset",
            name: "自定义",
            icon: "ellipsis.circle.fill",
            tintStyle: .lavender,
            group: .asset),
        LedgerAccountTemplate(
            id: "credit-card",
            name: "信用卡",
            icon: "creditcard.trianglebadge.exclamationmark",
            tintStyle: .coral,
            group: .credit),
        LedgerAccountTemplate(
            id: "huabei",
            name: "花呗",
            icon: "circle.hexagongrid.fill",
            tintStyle: .accent,
            group: .credit),
        LedgerAccountTemplate(id: "baitiao", name: "白条", icon: "doc.text.fill", tintStyle: .gold, group: .credit),
        LedgerAccountTemplate(
            id: "jiebei",
            name: "借呗",
            icon: "arrow.up.arrow.down.circle.fill",
            tintStyle: .lavender,
            group: .credit),
        LedgerAccountTemplate(
            id: "custom-credit",
            name: "自定义",
            icon: "ellipsis.circle.fill",
            tintStyle: .coral,
            group: .credit),
        LedgerAccountTemplate(id: "metro", name: "公交卡", icon: "tram.fill", tintStyle: .gold, group: .recharge),
        LedgerAccountTemplate(id: "meal-card", name: "饭卡", icon: "fork.knife", tintStyle: .mint, group: .recharge),
        LedgerAccountTemplate(
            id: "custom-recharge",
            name: "自定义",
            icon: "ellipsis.circle.fill",
            tintStyle: .lavender,
            group: .recharge),
        LedgerAccountTemplate(
            id: "stock",
            name: "股票",
            icon: "chart.line.uptrend.xyaxis.circle.fill",
            tintStyle: .accent,
            group: .investment),
        LedgerAccountTemplate(
            id: "fund",
            name: "基金",
            icon: "chart.bar.doc.horizontal.fill",
            tintStyle: .gold,
            group: .investment),
        LedgerAccountTemplate(
            id: "yuebao",
            name: "余额宝",
            icon: "wallet.pass.fill",
            tintStyle: .mint,
            group: .investment),
        LedgerAccountTemplate(
            id: "change",
            name: "零钱通",
            icon: "bitcoinsign.circle.fill",
            tintStyle: .lavender,
            group: .investment),
        LedgerAccountTemplate(
            id: "deposit",
            name: "定期存款",
            icon: "lock.circle.fill",
            tintStyle: .coral,
            group: .investment),
        LedgerAccountTemplate(
            id: "loan-out",
            name: "借出",
            icon: "arrow.up.right.circle.fill",
            tintStyle: .lavender,
            group: .loan),
        LedgerAccountTemplate(
            id: "loan-in",
            name: "借入",
            icon: "arrow.down.left.circle.fill",
            tintStyle: .coral,
            group: .loan)
    ]

    static func templates(for group: LedgerAccountGroup) -> [LedgerAccountTemplate] {
        all.filter { $0.group == group }
    }

    static func template(withID id: String) -> LedgerAccountTemplate? {
        all.first { $0.id == id }
    }
}

extension DrawerShortcut {
    static let commonTools: [DrawerShortcut] = [
        DrawerShortcut(
            id: "stats",
            title: "图表统计",
            icon: "chart.pie",
            accent: .ledgerAccent,
            destination: .screen(.statistics)),
        DrawerShortcut(
            id: "assets",
            title: "资产管理",
            icon: "creditcard",
            accent: .ledgerGold,
            destination: .screen(.assets)),
        DrawerShortcut(
            id: "books",
            title: "账本管理",
            icon: "book.closed",
            accent: .ledgerMint,
            destination: .screen(.books)),
        DrawerShortcut(
            id: "budget",
            title: "预算管理",
            icon: "square.and.pencil",
            accent: .ledgerLavender,
            destination: .screen(.budget)),
        DrawerShortcut(
            id: "saving",
            title: "攒钱计划",
            icon: "dollarsign.circle",
            accent: .ledgerIncome,
            destination: .placeholder("攒钱计划")),
        DrawerShortcut(
            id: "widgets",
            title: "小组件",
            icon: "square.grid.2x2",
            accent: .ledgerCoral,
            destination: .screen(.widgets)),
        DrawerShortcut(
            id: "categories",
            title: "分类管理",
            icon: "square.grid.3x1.folder.fill.badge.plus",
            accent: .ledgerAccent,
            destination: .screen(.categories)),
        DrawerShortcut(
            id: "history",
            title: "全部记录",
            icon: "text.document",
            accent: .ledgerGold,
            destination: .screen(.history))
    ]

    static let quickTools: [DrawerShortcut] = [
        DrawerShortcut(
            id: "import",
            title: "导入 / 导出",
            icon: "square.and.arrow.up.on.square",
            accent: .ledgerAccent,
            destination: .screen(.csvImportExport)),
        DrawerShortcut(
            id: "aibilling",
            title: "AI 智能记账",
            icon: "sparkles",
            accent: .ledgerMint,
            destination: .screen(.aiBilling)),
        DrawerShortcut(
            id: "automation",
            title: "自动记账",
            icon: "doc.text.magnifyingglass",
            accent: .ledgerMint,
            destination: .screen(.autoLedgerCenter)),
        DrawerShortcut(
            id: "schedule",
            title: "定时记账",
            icon: "clock.arrow.circlepath",
            accent: .ledgerLavender,
            destination: .placeholder("定时记账"))
    ]
}

extension DrawerLinkItem {
    static let settingsItems: [DrawerLinkItem] = [
        DrawerLinkItem(
            id: "settings",
            title: "设置",
            icon: "gearshape",
            accent: .ledgerAccent,
            showsBadge: false,
            destination: .screen(.settings)),
        DrawerLinkItem(
            id: "backup",
            title: "数据备份",
            icon: "externaldrive",
            accent: .ledgerMint,
            showsBadge: false,
            destination: .screen(.backup)),
        DrawerLinkItem(
            id: "privacy",
            title: "隐私与安全",
            icon: "lock.shield",
            accent: .ledgerGold,
            showsBadge: false,
            destination: .screen(.privacy))
    ]
}
