import SwiftUI

enum LedgerKind: String, CaseIterable, Identifiable {
    case expense = "支出"
    case income = "收入"

    var id: String { rawValue }
}

struct LedgerCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let tint: Color
    let kind: LedgerKind

    static func == (lhs: LedgerCategory, rhs: LedgerCategory) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct LedgerEntry: Identifiable {
    let id = UUID()
    let title: String
    let amount: Double
    let kind: LedgerKind
    let category: LedgerCategory
    let paymentMethod: String
    let note: String
    let date: Date
}

struct QuickEntryDraft {
    var kind: LedgerKind = .expense
    var amountText = ""
    var selectedCategory = LedgerCategory.defaultCategory(for: .expense)
    var paymentMethod = "支付宝"
    var note = ""

    var parsedAmount: Double? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    mutating func syncCategoryIfNeeded() {
        if selectedCategory.kind != kind {
            selectedCategory = LedgerCategory.defaultCategory(for: kind)
        }
    }
}

struct DrawerShortcut: Identifiable {
    let id: String
    let title: String
    let icon: String
    let accent: Color
}

struct DrawerLinkItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let accent: Color
    let showsBadge: Bool
}

extension LedgerCategory {
    static let expenseCategories: [LedgerCategory] = [
        LedgerCategory(id: "expense.meal", name: "餐饮", icon: "fork.knife", tint: .ledgerExpense, kind: .expense),
        LedgerCategory(id: "expense.transit", name: "通勤", icon: "tram.fill", tint: .ledgerAccent, kind: .expense),
        LedgerCategory(id: "expense.shopping", name: "购物", icon: "bag.fill", tint: .ledgerGold, kind: .expense),
        LedgerCategory(id: "expense.fun", name: "娱乐", icon: "sparkles", tint: .ledgerLavender, kind: .expense),
        LedgerCategory(id: "expense.home", name: "居家", icon: "house.fill", tint: .ledgerMint, kind: .expense),
        LedgerCategory(id: "expense.health", name: "医疗", icon: "cross.case.fill", tint: .ledgerCoral, kind: .expense)
    ]

    static let incomeCategories: [LedgerCategory] = [
        LedgerCategory(id: "income.salary", name: "工资", icon: "banknote.fill", tint: .ledgerIncome, kind: .income),
        LedgerCategory(id: "income.bonus", name: "奖金", icon: "star.circle.fill", tint: .ledgerGold, kind: .income),
        LedgerCategory(id: "income.wealth", name: "理财", icon: "chart.line.uptrend.xyaxis", tint: .ledgerAccent, kind: .income),
        LedgerCategory(id: "income.refund", name: "退款", icon: "arrow.uturn.backward.circle.fill", tint: .ledgerMint, kind: .income)
    ]

    static func categories(for kind: LedgerKind) -> [LedgerCategory] {
        switch kind {
        case .expense:
            expenseCategories
        case .income:
            incomeCategories
        }
    }

    static func defaultCategory(for kind: LedgerKind) -> LedgerCategory {
        categories(for: kind).first ?? expenseCategories[0]
    }
}

extension DrawerShortcut {
    static let commonTools: [DrawerShortcut] = [
        DrawerShortcut(id: "stats", title: "图表统计", icon: "chart.pie", accent: .ledgerAccent),
        DrawerShortcut(id: "assets", title: "资产管理", icon: "creditcard", accent: .ledgerGold),
        DrawerShortcut(id: "books", title: "账本管理", icon: "book.closed", accent: .ledgerMint),
        DrawerShortcut(id: "budget", title: "预算管理", icon: "square.and.pencil", accent: .ledgerLavender),
        DrawerShortcut(id: "saving", title: "攒钱计划", icon: "dollarsign.circle", accent: .ledgerIncome),
        DrawerShortcut(id: "widgets", title: "小组件", icon: "square.grid.2x2", accent: .ledgerCoral),
        DrawerShortcut(id: "categories", title: "分类管理", icon: "square.grid.3x1.folder.fill.badge.plus", accent: .ledgerAccent),
        DrawerShortcut(id: "tags", title: "标签管理", icon: "bookmark", accent: .ledgerGold)
    ]

    static let quickTools: [DrawerShortcut] = [
        DrawerShortcut(id: "import", title: "导入导出", icon: "square.and.arrow.down", accent: .ledgerAccent),
        DrawerShortcut(id: "automation", title: "自动记账", icon: "doc.text.magnifyingglass", accent: .ledgerMint),
        DrawerShortcut(id: "schedule", title: "定时记账", icon: "clock.arrow.circlepath", accent: .ledgerLavender)
    ]
}

extension DrawerLinkItem {
    static let settingsItems: [DrawerLinkItem] = [
        DrawerLinkItem(id: "settings", title: "设置", icon: "gearshape", accent: .ledgerAccent, showsBadge: false),
        DrawerLinkItem(id: "backup", title: "数据备份", icon: "externaldrive", accent: .ledgerMint, showsBadge: false),
        DrawerLinkItem(id: "privacy", title: "隐私与安全", icon: "lock.shield", accent: .ledgerGold, showsBadge: false)
    ]
}
