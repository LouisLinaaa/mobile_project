import AVFoundation
import Charts
import Combine
import PhotosUI
import Speech
import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import Vision

enum ManagementScreen: String, Identifiable {
    case history
    case statistics
    case budget
    case assets
    case books
    case categories
    case autoLedgerCenter
    case csvImportExport
    case aiBilling
    case widgets
    case profile
    case settings
    case backup
    case privacy
    case scheduledLedger

    var id: String { rawValue }
}

struct ManagementSheetView: View {
    let screen: ManagementScreen

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        LedgerToolbarBackButton {
                            dismiss()
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .history:
            LedgerHistoryView()
        case .statistics:
            StatisticsView()
        case .budget:
            BudgetManagementView()
        case .assets:
            AssetManagementView()
        case .books:
            BookManagementView()
        case .categories:
            CategoryManagementView()
        case .autoLedgerCenter:
            AutoLedgerCenterView()
        case .csvImportExport:
            CSVImportExportView()
        case .aiBilling:
            AIBillingView()
        case .widgets:
            WidgetCenterView()
        case .profile:
            ProfileSettingsView()
        case .settings:
            SettingsView()
        case .backup:
            BackupSettingsView()
        case .privacy:
            PrivacySecurityView()
        case .scheduledLedger:
            ScheduledLedgerView()
        }
    }
}

private enum StatisticsRange: String, CaseIterable, Identifiable {
    case week = "近7天"
    case month = "统计月"

    var id: String { rawValue }

    var localizedTitle: String { rawValue.localized }
}

private struct TrendPoint: Identifiable {
    let date: Date
    let amount: Double

    var id: Date { date }
}

private struct CategoryRankItem: Identifiable {
    let category: LedgerCategory
    let total: Double
    let share: Double

    var id: String { category.id }
}

struct StatisticsView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var range: StatisticsRange = .month
    @State private var selectedKind: LedgerKind = .expense

    private var filteredEntries: [LedgerEntry] {
        store.currentBookStatisticEntries.filter { entry in
            switch range {
            case .week:
                let start = Calendar.current.date(
                    byAdding: .day,
                    value: -6,
                    to: Calendar.current.startOfDay(for: Date())) ?? Date()
                return entry.date >= start
            case .month:
                return store.isInCurrentStatisticsMonth(entry.date)
            }
        }
    }

    private var expenseTotal: Double {
        filteredEntries.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var incomeTotal: Double {
        filteredEntries.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }
    }

    private var balanceTotal: Double {
        incomeTotal - expenseTotal
    }

    private var trendPoints: [TrendPoint] {
        let calendar = Calendar.current
        let entries = filteredEntries.filter { $0.kind == selectedKind }
        let totalsByDay = Dictionary(grouping: entries, by: { calendar.startOfDay(for: $0.date) })
            .mapValues { dayEntries in
                dayEntries.reduce(0) { $0 + $1.amount }
            }
        let dates: [Date]

        switch range {
        case .week:
            dates = (0..<7).compactMap {
                calendar.date(byAdding: .day, value: -6 + $0, to: calendar.startOfDay(for: Date()))
            }
        case .month:
            let interval = store.currentStatisticsMonthInterval
            let start = calendar.startOfDay(for: interval.start)
            let dayCount = calendar.dateComponents([.day], from: start, to: interval.end).day ?? 30

            dates = (0..<max(dayCount, 1)).compactMap { offset in
                calendar.date(byAdding: .day, value: offset, to: start)
            }
        }

        return dates.map { date in
            let dayKey = calendar.startOfDay(for: date)
            let total = totalsByDay[dayKey] ?? 0
            return TrendPoint(date: date, amount: total)
        }
    }

    private var categoryRanks: [CategoryRankItem] {
        let source = filteredEntries.filter { $0.kind == selectedKind }
        let total = source.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return [] }

        let grouped = Dictionary(grouping: source, by: { $0.category.id })

        return grouped.compactMap { _, items in
            guard let category = items.first?.category else { return nil }
            let value = items.reduce(0) { $0 + $1.amount }
            return CategoryRankItem(category: category, total: value, share: value / total)
        }
        .sorted { $0.total > $1.total }
    }

    private var topTransactions: [LedgerEntry] {
        filteredEntries
            .filter { $0.kind == selectedKind }
            .sorted { $0.amount > $1.amount }
            .prefix(5)
            .map { $0 }
    }

    private var chartColor: Color {
        selectedKind == .expense ? .ledgerAccent : .ledgerIncome
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                statisticsHeader
                summaryCard
                trendCard
                categoryCard
                rankingCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [Color.ledgerAccentSoft.opacity(0.5), Color.ledgerCanvas],
                startPoint: .top,
                endPoint: .bottom)
                .ignoresSafeArea())
        .navigationTitle("图表统计")
    }

    private var statisticsHeader: some View {
        HStack(spacing: 12) {
            Picker("范围", selection: $range) {
                ForEach(StatisticsRange.allCases) { item in
                    Text(item.localizedTitle).tag(item)
                }
            }
            .pickerStyle(.segmented)

            Menu {
                ForEach(store.books) { book in
                    Button(book.name) {
                        store.setCurrentBook(book)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                    Text(store.currentBook.name)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ledgerText)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.ledgerElevated.opacity(0.88))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(range == .week ? "近 7 天概览" : "统计月概览")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))

            HStack(spacing: 12) {
                MetricBlock(title: "支出", value: expenseTotal, valueColor: .white)
                MetricBlock(title: "收入", value: incomeTotal, valueColor: .white)
                MetricBlock(title: "结余", value: balanceTotal, valueColor: .white)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.ledgerAccent, Color.ledgerLavender],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                .shadow(color: Color.ledgerAccent.opacity(0.22), radius: 24, x: 0, y: 18))
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("每日走势")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Spacer()

                Picker("类型", selection: $selectedKind) {
                    ForEach(LedgerKind.allCases) { kind in
                        Text(kind.localizedTitle).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 176)
            }

            if trendPoints.allSatisfy({ $0.amount == 0 }) {
                EmptyFeatureState(
                    icon: "chart.bar.xaxis",
                    title: "还没有可统计的数据",
                    detail: "先记几笔账，再回来看看趋势变化。")
                    .frame(height: 220)
            } else {
                Chart(trendPoints) { point in
                    BarMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("金额", point.amount))
                        .foregroundStyle(chartColor.gradient)
                        .cornerRadius(6)
                }
                .frame(height: 220)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    let stride = range == .week ? 1 : 7
                    AxisMarks(values: .stride(by: .day, count: stride)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(Color.ledgerDivider)
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                    }
                }
            }
        }
        .padding(22)
        .ledgerCard()
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(selectedKind == .expense ? "支出分类构成" : "收入分类构成")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            if categoryRanks.isEmpty {
                EmptyFeatureState(
                    icon: "circle.dotted",
                    title: "暂无分类数据",
                    detail: "等你记上几笔以后，这里会显示主要分类占比。")
            } else {
                VStack(spacing: 14) {
                    ForEach(categoryRanks.prefix(6)) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(item.category.name.localized, systemImage: item.category.icon)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.ledgerText)

                                Spacer()

                                Text(LedgerFormatters.currency(item.total))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(item.category.tint)
                            }

                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.ledgerAccentMuted)

                                    Capsule()
                                        .fill(item.category.tint)
                                        .frame(width: proxy.size.width * item.share)
                                }
                            }
                            .frame(height: 10)
                        }
                    }
                }
            }
        }
        .padding(22)
        .ledgerCard()
    }

    private var rankingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(selectedKind == .expense ? "单笔支出排行" : "单笔收入排行")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            if topTransactions.isEmpty {
                EmptyFeatureState(
                    icon: "list.number",
                    title: "暂无排行",
                    detail: "这部分会帮你快速看到金额最大的记录。")
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(topTransactions.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 14) {
                            Text("\(index + 1)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(entry.category.tint)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.ledgerText)

                                Text(
                                    "\(entry.category.name.localized) · \(LedgerFormatters.entryTime(for: entry.date))")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.ledgerMuted)
                            }

                            Spacer()

                            Text(LedgerFormatters.currency(entry.amount))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(entry.kind == .expense ? Color.ledgerExpense : Color.ledgerIncome)
                        }
                        .padding(14)
                        .background(Color.ledgerAccentMuted.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
        .padding(22)
        .ledgerCard()
    }
}

struct AssetManagementView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var isAddPresented = false
    @State private var editingAccount: LedgerAccount?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                assetHeroCard

                ForEach(LedgerAccountGroup.allCases) { group in
                    let groupAccounts = store.accounts(for: group)

                    if !groupAccounts.isEmpty {
                        accountSection(group: group, accounts: groupAccounts)
                    }
                }

                if store.accounts.isEmpty {
                    EmptyFeatureState(
                        icon: "wallet.pass",
                        title: "还没有账户",
                        detail: "先添加储蓄卡、现金或负债账户，资产页会自动汇总。")
                        .padding(.top, 40)
                }
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .background(Color(red: 1.00, green: 0.98, blue: 0.92).ignoresSafeArea())
        .navigationTitle("资产管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.ledgerText)
                }
            }
        }
        .sheet(isPresented: $isAddPresented) {
            AccountEditorSheet(account: nil)
                .environmentObject(store)
        }
        .sheet(item: $editingAccount) { account in
            AccountEditorSheet(account: account)
                .environmentObject(store)
        }
    }

    private var assetHeroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Text("净资产")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)

                Image(systemName: store.isBalanceVisible ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.ledgerGold)
            }

            Text(store.isBalanceVisible ? LedgerFormatters.currency(store.netWorth) : "¥••••")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            HStack(spacing: 12) {
                MetricBlock(
                    title: "资产",
                    value: store.totalAssets,
                    valueColor: Color.ledgerText,
                    background: Color.ledgerSurface.opacity(0.45))
                MetricBlock(
                    title: "负债",
                    value: store.totalLiabilities,
                    valueColor: Color.ledgerText,
                    background: Color.ledgerSurface.opacity(0.45))
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.00, green: 0.96, blue: 0.80), Color(red: 1.00, green: 0.90, blue: 0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                .shadow(color: Color.ledgerGold.opacity(0.18), radius: 22, x: 0, y: 14))
    }

    private func accountSection(group: LedgerAccountGroup, accounts: [LedgerAccount]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(group.title)（\(group.subtitle)）")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Spacer()

                Text("\(accounts.count) 个")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(group.accent)
            }

            VStack(spacing: 12) {
                ForEach(accounts) { account in
                    Button {
                        editingAccount = account
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(account.tint.opacity(0.16))
                                    .frame(width: 48, height: 48)

                                Image(systemName: account.icon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(account.tint)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.name.localized)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.ledgerText)

                                Text(group.subtitle)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.ledgerMuted)
                            }

                            Spacer()

                            Text(LedgerFormatters.currency(account.balance))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(group.affectsAssets ? Color.ledgerIncome : Color.ledgerExpense)
                        }
                        .padding(14)
                        .background(Color.ledgerElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("编辑") {
                            editingAccount = account
                        }

                        Button("删除", role: .destructive) {
                            store.deleteAccount(account)
                        }
                    }
                }
            }
        }
        .padding(20)
        .ledgerCard()
    }
}

struct BookManagementView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var isAddPresented = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                currentBookCard

                ForEach(store.books) { book in
                    Button {
                        store.setCurrentBook(book)
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(book.tintStyle.color.opacity(0.14))
                                    .frame(width: 72, height: 72)

                                Image(systemName: book.icon)
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(book.tintStyle.color)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Text(book.name)
                                        .font(.system(size: 21, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.ledgerText)

                                    if book.id == store.currentBook.id {
                                        Text("当前")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(book.tintStyle.color)
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(
                                    "\(LedgerFormatters.bookDate(book.createdAt)) 创建 · \(store.bookEntryCount(book)) 笔记录")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.ledgerMuted)

                                Text(book.note)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.ledgerMuted)
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                Text("本月支出")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.ledgerMuted)

                                Text(LedgerFormatters.currency(store.bookMonthlyExpense(book)))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.ledgerText)
                            }
                        }
                        .padding(18)
                        .background(Color.ledgerElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .background(Color.ledgerCanvas.ignoresSafeArea())
        .navigationTitle("账本管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.ledgerText)
                }
            }
        }
        .sheet(isPresented: $isAddPresented) {
            AddBookSheet()
                .environmentObject(store)
        }
    }

    private var currentBookCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前使用")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(store.currentBook.tintStyle.color.opacity(0.18))
                        .frame(width: 74, height: 74)

                    Image(systemName: store.currentBook.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(store.currentBook.tintStyle.color)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.currentBook.name)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Text(
                        "\(store.bookEntryCount(store.currentBook)) 笔记录 · 本月收入 \(LedgerFormatters.currency(store.bookMonthlyIncome(store.currentBook)))")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.ledgerSurface, store.currentBook.tintStyle.color.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing)))
    }
}

private struct SchemeSheetSelection: Identifiable {
    let id: UUID
}

struct CategoryManagementView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var isAddSchemePresented = false
    @State private var selectedScheme: SchemeSheetSelection?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(store.categorySchemes) { scheme in
                    Button {
                        selectedScheme = SchemeSheetSelection(id: scheme.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(scheme.name)
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.ledgerText)

                                    Text(scheme.note)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.ledgerMuted)
                                }

                                Spacer()

                                if scheme.id == store.currentCategoryScheme.id {
                                    Text("使用中")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .background(Color.ledgerAccent)
                                        .clipShape(Capsule())
                                }
                            }

                            HStack(spacing: 18) {
                                SchemeMetric(
                                    title: "支出",
                                    value: "\(scheme.expenseCategories.count) 类",
                                    accent: .ledgerAccent)
                                SchemeMetric(
                                    title: "收入",
                                    value: "\(scheme.incomeCategories.count) 类",
                                    accent: .ledgerGold)
                            }

                            HStack(spacing: 10) {
                                ForEach(scheme.expenseCategories.prefix(4)) { category in
                                    VStack(spacing: 8) {
                                        Circle()
                                            .fill(category.tint.opacity(0.14))
                                            .frame(width: 44, height: 44)
                                            .overlay {
                                                Image(systemName: category.icon)
                                                    .foregroundStyle(category.tint)
                                            }

                                        Text(category.name.localized)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color.ledgerMuted)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.ledgerElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if scheme.id != store.currentCategoryScheme.id {
                            Button("设为当前方案") {
                                store.setCurrentCategoryScheme(scheme)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .background(Color.ledgerCanvas.ignoresSafeArea())
        .navigationTitle("分类管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddSchemePresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.ledgerText)
                }
            }
        }
        .sheet(item: $selectedScheme) { selection in
            CategorySchemeDetailView(schemeID: selection.id)
                .environmentObject(store)
        }
        .sheet(isPresented: $isAddSchemePresented) {
            AddCategorySchemeSheet()
                .environmentObject(store)
        }
    }
}

private struct CategorySchemeDetailView: View {
    let schemeID: UUID

    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedKind: LedgerKind = .expense
    @State private var isAddPresented = false

    private var scheme: LedgerCategoryScheme? {
        store.categorySchemes.first(where: { $0.id == schemeID })
    }

    private var categories: [LedgerCategory] {
        guard let scheme else { return [] }
        switch selectedKind {
        case .expense:
            return scheme.expenseCategories
        case .income:
            return scheme.incomeCategories
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let scheme {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(scheme.note)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ledgerMuted)

                            Picker("类型", selection: $selectedKind) {
                                ForEach(LedgerKind.allCases) { kind in
                                    Text(kind.localizedTitle).tag(kind)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 16)], spacing: 16) {
                            ForEach(categories) { category in
                                VStack(spacing: 10) {
                                    Circle()
                                        .fill(category.tint.opacity(0.14))
                                        .frame(width: 60, height: 60)
                                        .overlay {
                                            Image(systemName: category.icon)
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(category.tint)
                                        }

                                    Text(category.name.localized)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.ledgerText)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.ledgerElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .contextMenu {
                                    Button("删除分类", role: .destructive) {
                                        store.removeCategory(
                                            from: schemeID,
                                            categoryID: category.id,
                                            kind: selectedKind)
                                    }
                                }
                            }

                            Button {
                                isAddPresented = true
                            } label: {
                                VStack(spacing: 10) {
                                    Circle()
                                        .stroke(Color.ledgerDivider, lineWidth: 1.4)
                                        .frame(width: 60, height: 60)
                                        .overlay {
                                            Image(systemName: "plus")
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundStyle(Color.ledgerMuted)
                                        }

                                    Text("添加")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.ledgerMuted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.ledgerElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(Color.ledgerCanvas.ignoresSafeArea())
            .navigationTitle(scheme?.name ?? "分类方案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.ledgerText)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if let scheme, scheme.id != store.currentCategoryScheme.id {
                        Button("设为当前") {
                            store.setCurrentCategoryScheme(scheme)
                        }
                        .fontWeight(.bold)
                    }
                }
            }
        }
        .sheet(isPresented: $isAddPresented) {
            AddCategorySheet(kind: selectedKind, schemeID: schemeID)
                .environmentObject(store)
        }
    }
}

private struct AccountEditorSheet: View {
    let account: LedgerAccount?

    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplateID = LedgerAccountTemplate.all.first?.id ?? ""
    @State private var accountName = ""
    @State private var balanceText = "0"

    private var selectedTemplate: LedgerAccountTemplate {
        LedgerAccountTemplate.template(withID: selectedTemplateID) ?? LedgerAccountTemplate.all[0]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("账户名称")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ledgerText)

                        TextField("请输入名称", text: $accountName)
                            .padding(18)
                            .background(Color.ledgerElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(selectedTemplate.group.affectsAssets ? "初始余额" : "当前欠款")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ledgerText)

                        TextField("0.00", text: $balanceText)
                            .keyboardType(.decimalPad)
                            .padding(18)
                            .background(Color.ledgerElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }

                    ForEach(LedgerAccountGroup.allCases) { group in
                        VStack(alignment: .leading, spacing: 14) {
                            Text("\(group.title)（\(group.subtitle)）")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ledgerText)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 14)], spacing: 14) {
                                ForEach(store.accountTemplates(for: group)) { template in
                                    Button {
                                        let previousTemplateName = selectedTemplate.name
                                        selectedTemplateID = template.id
                                        if accountName.isEmpty || accountName == previousTemplateName {
                                            accountName = template.name
                                        }
                                    } label: {
                                        VStack(spacing: 10) {
                                            Circle()
                                                .fill(template.tintStyle.color
                                                    .opacity(selectedTemplateID == template.id ? 0.22 : 0.12))
                                                .frame(width: 56, height: 56)
                                                .overlay {
                                                    Image(systemName: template.icon)
                                                        .font(.system(size: 22, weight: .semibold))
                                                        .foregroundStyle(template.tintStyle.color)
                                                }

                                            Text(template.name.localized)
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundStyle(Color.ledgerText)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .fill(selectedTemplateID == template.id ? template.tintStyle.color
                                                    .opacity(0.08) : Color.ledgerSurface)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                        .stroke(
                                                            selectedTemplateID == template.id ? template.tintStyle
                                                                .color : Color.clear,
                                                            lineWidth: 1.4)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.ledgerCanvas)
            .navigationTitle(account == nil ? "添加账户" : "编辑账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(account == nil ? "添加" : "保存") {
                        let balance = Double(balanceText.replacingOccurrences(of: ",", with: ".")) ?? 0

                        if let account {
                            store.updateAccount(
                                account,
                                template: selectedTemplate,
                                customName: accountName,
                                balance: balance)
                        } else {
                            store.addAccount(template: selectedTemplate, customName: accountName, balance: balance)
                        }

                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let account {
                selectedTemplateID = account.templateID
                accountName = account.name
                balanceText = account.balance == 0 ? "0" : String(format: "%.2f", account.balance)
            } else {
                selectedTemplateID = LedgerAccountTemplate.all.first?.id ?? ""
                accountName = LedgerAccountTemplate.template(withID: selectedTemplateID)?.name ?? ""
                balanceText = "0"
            }
        }
    }
}

private struct AddBookSheet: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("账本名称") {
                    TextField("例如：旅行账本", text: $name)
                }

                Section("说明") {
                    TextField("例如：记录项目、旅行或家庭账单", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("新增账本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        store.addBook(name: name, note: note)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct AddCategorySchemeSheet: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("方案名称") {
                    TextField("例如：家庭日常", text: $name)
                }

                Section("说明") {
                    TextField("例如：适合家庭和孩子相关支出", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("新增方案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        store.addCategoryScheme(name: name, note: note)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct AddCategorySheet: View {
    let kind: LedgerKind
    let schemeID: UUID

    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedTint: LedgerTintStyle = .accent

    private let iconOptions = [
        "fork.knife.circle.fill",
        "bag.fill",
        "car.fill",
        "house.fill",
        "gamecontroller.fill",
        "cross.case.fill",
        "book.fill",
        "pawprint.fill",
        "shield.fill",
        "banknote.fill",
        "briefcase.fill",
        "gift.fill"
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("分类名称")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ledgerText)

                        TextField("请输入名称", text: $name)
                            .padding(18)
                            .background(Color.ledgerElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("图标")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ledgerText)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 12)], spacing: 12) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Circle()
                                        .fill(Color.ledgerSurface)
                                        .frame(width: 54, height: 54)
                                        .overlay {
                                            Image(systemName: icon)
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(selectedTint.color)
                                        }
                                        .overlay {
                                            Circle()
                                                .stroke(
                                                    selectedIcon == icon ? selectedTint.color : Color.clear,
                                                    lineWidth: 2)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("颜色")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ledgerText)

                        HStack(spacing: 14) {
                            ForEach(LedgerTintStyle.allCases) { tint in
                                Button {
                                    selectedTint = tint
                                } label: {
                                    Circle()
                                        .fill(tint.color)
                                        .frame(width: 34, height: 34)
                                        .overlay {
                                            Circle()
                                                .stroke(.white, lineWidth: 2)
                                                .padding(3)
                                        }
                                        .overlay {
                                            Circle()
                                                .stroke(
                                                    selectedTint == tint ? Color.ledgerText : Color.clear,
                                                    lineWidth: 2)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.ledgerCanvas)
            .navigationTitle(kind == .expense ? "新增支出分类" : "新增收入分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        store.addCategory(
                            to: schemeID,
                            kind: kind,
                            name: name,
                            icon: selectedIcon,
                            tintStyle: selectedTint)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct EmptyFeatureState: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.ledgerAccent)

            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Text(detail)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(Color.ledgerAccentMuted.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct MetricBlock: View {
    let title: String
    let value: Double
    let valueColor: Color
    var background: Color = .white.opacity(0.18)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(valueColor.opacity(0.8))

            Text(LedgerFormatters.currency(value))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SchemeMetric: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(accent)
                .frame(width: 4, height: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)

                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
            }
        }
    }
}

private enum SettingsLayout {
    static let sectionSpacing: CGFloat = 16
    static let dividerLeading: CGFloat = 18
    static let rowHorizontalPadding: CGFloat = 18
    static let rowVerticalPadding: CGFloat = 16
    static let titleFontSize: CGFloat = 18
    static let valueFontSize: CGFloat = 16
    static let subtitleFontSize: CGFloat = 13
}

private enum ProfileEditorField: Identifiable {
    case nickname

    var id: String {
        switch self {
        case .nickname:
            "nickname"
        }
    }

    var title: String {
        switch self {
        case .nickname:
            "昵称"
        }
    }

    var placeholder: String {
        switch self {
        case .nickname:
            "输入昵称"
        }
    }
}

private struct NoHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct ProfileSettingsView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var activeEditor: ProfileEditorField?
    @State private var isGenderSheetPresented = false
    @State private var genderDraft = ""
    @State private var avatarLoadTask: Task<Void, Never>?
    @State private var avatarSelectionToken = UUID()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                profileHero
                profileDetailsCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.93, green: 0.96, blue: 1.0), Color.ledgerCanvas],
                startPoint: .top,
                endPoint: .bottom)
                .ignoresSafeArea())
        .navigationTitle("关于你")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeEditor) { field in
            ProfileTextEditSheet(field: field)
                .environmentObject(store)
        }
        .sheet(isPresented: $isGenderSheetPresented) {
            ProfileGenderSheet(selection: $genderDraft) {
                store.updateUserGender(genderDraft)
                isGenderSheetPresented = false
            } onCancel: {
                genderDraft = store.appSettings.userProfile.gender
                isGenderSheetPresented = false
            }
        }
        .onChange(of: selectedAvatarItem) { _, item in
            guard let item else { return }
            avatarLoadTask?.cancel()
            let selectionToken = UUID()
            avatarSelectionToken = selectionToken
            avatarLoadTask = Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    guard !Task.isCancelled else { return }
                    let normalizedData = await Task.detached(priority: .userInitiated) {
                        normalizedAvatarData(from: data)
                    }.value
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard avatarSelectionToken == selectionToken else { return }
                        store.updateUserAvatar(data: normalizedData)
                    }
                }
            }
        }
        .onAppear {
            genderDraft = store.appSettings.userProfile.gender
        }
        .onDisappear {
            avatarLoadTask?.cancel()
        }
    }

    private var profileHero: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                DrawerAvatarView(imageData: store.appSettings.userProfile.avatarData, size: 132)

                PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(Color.ledgerSurface)
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)

                        Image(systemName: "camera")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.ledgerMuted)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: -6, y: -4)
            }

            Text(store.appSettings.userProfile.displayName)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var profileDetailsCard: some View {
        VStack(spacing: 0) {
            profileFieldRow(
                title: "昵称",
                value: store.appSettings.userProfile.displayName,
                action: { activeEditor = .nickname })

            Divider().padding(.leading, SettingsLayout.dividerLeading)

            profileFieldRow(
                title: "性别",
                value: store.appSettings.userProfile.gender.isEmpty ? "未填写" : store.appSettings.userProfile.gender,
                isPlaceholder: store.appSettings.userProfile.gender.isEmpty,
                action: {
                    genderDraft =
                        store.appSettings.userProfile.gender.isEmpty ? "保密" : store.appSettings.userProfile.gender
                    isGenderSheetPresented = true
                })

            Divider().padding(.leading, SettingsLayout.dividerLeading)

            profileInfoRow(title: "ID", value: store.appSettings.userProfile.userID)

            Divider().padding(.leading, SettingsLayout.dividerLeading)

            profileInfoRow(title: "版本号", value: appVersionText)
        }
        .ledgerCard()
    }

    private func profileFieldRow(
        title: String,
        value: String,
        isPlaceholder: Bool = false,
        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Spacer()

                Text(value)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(isPlaceholder ? Color.ledgerMuted.opacity(0.8) : Color.ledgerMuted)
                    .lineLimit(1)

                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.ledgerMuted.opacity(0.72))
            }
            .padding(.horizontal, SettingsLayout.rowHorizontalPadding)
            .padding(.vertical, 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoHighlightButtonStyle())
    }

    private func profileInfoRow(title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Spacer()

            Text(value)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .lineLimit(1)
        }
        .padding(.horizontal, SettingsLayout.rowHorizontalPadding)
        .padding(.vertical, 22)
    }

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return shortVersion == buildVersion ? shortVersion : "\(shortVersion).\(buildVersion)"
    }
}

private struct ProfileTextEditSheet: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    let field: ProfileEditorField

    @State private var text = ""

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.ledgerMuted.opacity(0.18))
                .frame(width: 48, height: 6)
                .padding(.top, 10)
                .padding(.bottom, 26)

            Text("修改昵称")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)
                .padding(.bottom, 28)

            HStack(spacing: 12) {
                TextField(field.placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.ledgerMuted.opacity(0.7))
                    }
                    .buttonStyle(NoHighlightButtonStyle())
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 72)
            .background(Color.black.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Button("保存") {
                save()
            }
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.ledgerAccent)
            .clipShape(Capsule())
            .padding(.top, 28)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(Color.ledgerElevated)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            text = store.appSettings.userProfile.displayName
        }
    }

    private func save() {
        store.updateUserDisplayName(text)
        dismiss()
    }
}

private struct ProfileGenderSheet: View {
    @Binding var selection: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private let options = ["女", "男", "保密"]

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.ledgerMuted.opacity(0.18))
                .frame(width: 48, height: 6)
                .padding(.top, 10)
                .padding(.bottom, 24)

            Text("选择性别")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)
                .padding(.bottom, 22)

            Divider()
                .padding(.bottom, 22)

            VStack(spacing: 12) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        Text(option)
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .foregroundStyle(selection == option ? Color.ledgerText : Color.ledgerMuted.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(selection == option ? Color.black.opacity(0.04) : Color.clear))
                    }
                    .buttonStyle(NoHighlightButtonStyle())
                }
            }

            HStack(spacing: 14) {
                Button("取消") {
                    onCancel()
                }
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerMuted.opacity(0.65))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.black.opacity(0.06))
                .clipShape(Capsule())

                Button("确认") {
                    onConfirm()
                }
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.ledgerAccent)
                .clipShape(Capsule())
            }
            .padding(.top, 28)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(Color.ledgerElevated)
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.hidden)
    }
}

private func normalizedAvatarData(from data: Data) -> Data {
    guard let image = UIImage(data: data) else { return data }

    let maxDimension: CGFloat = 512
    let originalSize = image.size
    let longestEdge = max(originalSize.width, originalSize.height)
    let scale = min(1, maxDimension / max(longestEdge, 1))
    let targetSize = CGSize(
        width: max(1, floor(originalSize.width * scale)),
        height: max(1, floor(originalSize.height * scale)))

    let renderedImage: UIImage
    if scale < 1 {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        renderedImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    } else {
        renderedImage = image
    }

    let compressionQualities: [CGFloat] = [0.82, 0.68, 0.52]
    let maxByteCount = 350_000
    var fallbackData = data

    for quality in compressionQualities {
        if let jpegData = renderedImage.jpegData(compressionQuality: quality) {
            fallbackData = jpegData
            if jpegData.count <= maxByteCount {
                return jpegData
            }
        }
    }

    return fallbackData
}

struct SettingsView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var isDeleteAlertPresented = false
    @State private var isHelpPresented = false
    @State private var isAboutPresented = false
    @State private var isBackupPresented = false
    @State private var isPrivacyPresented = false

    private let monthStartDayOptions = Array(1...28)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SettingsLayout.sectionSpacing) {
                displaySettingsCard
                pushSettingsCard
                serviceCard
                dangerCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [Color.ledgerAccentSoft.opacity(0.42), Color.ledgerCanvas],
                startPoint: .top,
                endPoint: .bottom)
                .ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isHelpPresented) {
            HelpFeedbackView()
        }
        .sheet(isPresented: $isAboutPresented) {
            AboutAppView()
        }
        .sheet(isPresented: $isBackupPresented) {
            NavigationStack {
                BackupSettingsView()
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $isPrivacyPresented) {
            NavigationStack {
                PrivacySecurityView()
                    .environmentObject(store)
            }
        }
        .alert("确认删除历史账单？", isPresented: $isDeleteAlertPresented) {
            Button("删除", role: .destructive) {
                store.clearAllHistoryEntries()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会清空当前本地账单记录，但不会删除账本、账户和分类设置。")
        }
        .task {
            store.refreshNotificationAuthorizationStatus()
        }
    }

    private var displaySettingsCard: some View {
        VStack(spacing: 0) {
            SettingSelectRow(
                title: "月统计起始日",
                value: store.appSettings.monthStartDayLabel) {
                    ForEach(monthStartDayOptions, id: \.self) { day in
                        Button("每月\(day)日") {
                            store.setMonthStartDay(day)
                        }
                    }
                }

            Divider().padding(.leading, SettingsLayout.dividerLeading)

            SettingSelectRow(
                title: "助手回复风格",
                value: store.appSettings.assistantReplyStyle.title) {
                    ForEach(AssistantReplyStyle.allCases) { style in
                        Button(style.title) {
                            store.setAssistantReplyStyle(style)
                        }
                    }
                }

            Divider().padding(.leading, SettingsLayout.dividerLeading)

            SettingToggleRow(
                title: "首页助手卡片",
                subtitle: "控制首页“一句话快速记账”卡片展示",
                isOn: Binding(
                    get: { store.appSettings.showOfferRecommendations },
                    set: { store.appSettings.showOfferRecommendations = $0 }))
        }
        .ledgerCard()
    }

    private var pushSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingToggleRow(
                title: "推送服务",
                subtitle: "本地提醒会根据预算和记账状态自动安排",
                isOn: Binding(
                    get: { store.appSettings.pushEnabled },
                    set: { store.setPushEnabled($0) }))
                .padding(.horizontal, SettingsLayout.rowHorizontalPadding)
                .padding(.top, 16)

            notificationStatusRow

            VStack(spacing: 0) {
                SettingCheckRow(
                    title: "每日记账",
                    isChecked: Binding(
                        get: { store.appSettings.pushDailyLedger },
                        set: { store.setPushSubItem(dailyLedger: $0) }))
                Divider().padding(.leading, SettingsLayout.dividerLeading)

                SettingCheckRow(
                    title: "预算提醒",
                    isChecked: Binding(
                        get: { store.appSettings.pushBudgetReminder },
                        set: { store.setPushSubItem(budgetReminder: $0) }))
                Divider().padding(.leading, SettingsLayout.dividerLeading)

                SettingCheckRow(
                    title: "功能推荐",
                    isChecked: Binding(
                        get: { store.appSettings.pushFeatureRecommendation },
                        set: { store.setPushSubItem(featureRecommendation: $0) }))
                Divider().padding(.leading, SettingsLayout.dividerLeading)

                SettingCheckRow(
                    title: "账单回顾",
                    isChecked: Binding(
                        get: { store.appSettings.pushBillReview },
                        set: { store.setPushSubItem(billReview: $0) }))
            }
            .background(Color.ledgerAccentMuted.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(12)
            .opacity(store.appSettings.pushEnabled ? 1 : 0.45)
            .disabled(!store.appSettings.pushEnabled)
        }
        .ledgerCard()
    }

    private var notificationStatusRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: notificationStatusIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(notificationStatusTint)
                .frame(width: 28, height: 28)
                .background(notificationStatusTint.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(store.notificationAuthorizationState.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                Text(store.notificationAuthorizationState.subtitle)
                    .font(.system(size: SettingsLayout.subtitleFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if let actionTitle = notificationStatusActionTitle {
                Button(actionTitle) {
                    handleNotificationStatusAction()
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ledgerAccent)
            }
        }
        .padding(.horizontal, SettingsLayout.rowHorizontalPadding)
        .padding(.bottom, 4)
    }

    private var notificationStatusIcon: String {
        switch store.notificationAuthorizationState {
        case .authorized, .provisional, .ephemeral:
            "bell.badge.fill"
        case .denied:
            "bell.slash.fill"
        case .unknown, .notDetermined:
            "bell.fill"
        }
    }

    private var notificationStatusTint: Color {
        switch store.notificationAuthorizationState {
        case .authorized, .provisional, .ephemeral:
            .ledgerIncome
        case .denied:
            .ledgerExpense
        case .unknown, .notDetermined:
            .ledgerAccent
        }
    }

    private var notificationStatusActionTitle: String? {
        switch store.notificationAuthorizationState {
        case .notDetermined:
            "开启权限"
        case .denied:
            "去设置"
        case .unknown, .authorized, .provisional, .ephemeral:
            nil
        }
    }

    private func handleNotificationStatusAction() {
        switch store.notificationAuthorizationState {
        case .notDetermined:
            store.setPushEnabled(true)
        case .denied:
            store.openNotificationSystemSettings()
        case .unknown, .authorized, .provisional, .ephemeral:
            break
        }
    }

    private var serviceCard: some View {
        VStack(spacing: 0) {
            SettingActionRow(title: "数据备份") { isBackupPresented = true }
            Divider().padding(.leading, SettingsLayout.dividerLeading)
            SettingActionRow(title: "隐私与安全") { isPrivacyPresented = true }
            Divider().padding(.leading, SettingsLayout.dividerLeading)
            SettingActionRow(title: "帮助与反馈") { isHelpPresented = true }
            Divider().padding(.leading, SettingsLayout.dividerLeading)
            SettingActionRow(title: "关于 App") { isAboutPresented = true }
        }
        .ledgerCard()
    }

    private var dangerCard: some View {
        Button(role: .destructive) {
            isDeleteAlertPresented = true
        } label: {
            HStack {
                Text("删除所有历史账单数据")
                    .font(.system(size: SettingsLayout.titleFontSize, weight: .medium, design: .rounded))
                Spacer()
                Text("删除")
                    .font(.system(size: SettingsLayout.titleFontSize, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.red)
            .padding(.horizontal, SettingsLayout.rowHorizontalPadding)
            .padding(.vertical, 20)
        }
        .buttonStyle(.plain)
        .ledgerCard()
    }
}

struct BackupSettingsView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    @State private var isRestoreAlertPresented = false
    @State private var statusMessage: String?

    private var statusBinding: Binding<Bool> {
        Binding(
            get: { statusMessage != nil },
            set: { shouldShow in
                if !shouldShow {
                    statusMessage = nil
                }
            })
    }

    private var summary: LedgerStore.CloudBackupSummary? {
        store.iCloudBackupSummary
    }

    private var statusTitle: String {
        if !store.isICloudBackupAvailable {
            return "未检测到 iCloud 账户"
        }
        if summary != nil {
            return "iCloud 备份已就绪"
        }
        return "还没有云端备份"
    }

    private var statusSubtitle: String {
        if !store.isICloudBackupAvailable {
            return "请先在系统设置中登录 iCloud，随后就可以把账本安全备份到当前 Apple ID。"
        }
        guard let summary else {
            return "当前设备已支持云端备份，建议先执行一次手动备份，后续再继续扩展自动策略。"
        }
        return "最近备份时间：\(summary.generatedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SettingsLayout.sectionSpacing) {
                backupIntroCard
                iCloudActionCard
                if let summary {
                    iCloudDetailCard(summary)
                } else {
                    backupEmptyCard
                }
                backupSafetyCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [Color.ledgerMint.opacity(0.18), Color.ledgerCanvas],
                startPoint: .top,
                endPoint: .bottom)
                .ignoresSafeArea())
        .navigationTitle("数据备份")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
            }
        }
        .onAppear {
            store.refreshICloudBackupSummary()
        }
        .alert("确认从 iCloud 恢复？", isPresented: $isRestoreAlertPresented) {
            Button("恢复", role: .destructive) {
                statusMessage = store.restoreFromICloudBackupSnapshot() ? "云端备份已恢复到当前设备。" : "恢复失败，请确认 iCloud 中已有可用备份。"
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("恢复会覆盖当前设备上的账本、账户、分类和设置内容。")
        }
        .alert("备份状态", isPresented: statusBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(statusMessage ?? "")
        }
    }

    private var backupIntroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "icloud")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.ledgerAccent)
                Text("云端备份与恢复")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
            }

            Text("将账本、账户、分类方案和偏好设置备份到当前 Apple ID 对应的 iCloud 空间，在新设备上也能快速接回。")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .ledgerCard()
    }

    private var iCloudActionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill((store.isICloudBackupAvailable ? Color.ledgerMint : Color.ledgerCoral).opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(systemName: store
                        .isICloudBackupAvailable ? "checkmark.icloud.fill" : "exclamationmark.icloud.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(store.isICloudBackupAvailable ? Color.ledgerMint : Color.ledgerCoral)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(statusTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)
                    Text(statusSubtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 12) {
                BackupActionButton(
                    title: "立即备份",
                    systemImage: "arrow.up.circle.fill",
                    tint: .ledgerAccent) {
                        statusMessage = store.createICloudBackupSnapshot() ? "已将当前数据写入 iCloud 备份。" : "备份失败，请稍后重试。"
                    }
                    .disabled(!store.isICloudBackupAvailable)

                BackupActionButton(
                    title: "从云端恢复",
                    systemImage: "arrow.down.circle.fill",
                    tint: .ledgerMint) {
                        isRestoreAlertPresented = true
                    }
                    .disabled(summary == nil)
            }
        }
        .padding(18)
        .ledgerCard()
    }

    private func iCloudDetailCard(_ summary: LedgerStore.CloudBackupSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("最近一次云端备份")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                Spacer()
                Button {
                    store.refreshICloudBackupSummary()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.ledgerMuted)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(summary.generatedAt.formatted(date: .complete, time: .shortened))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                Text(
                    "本次备份包含 \(summary.totalEntryCount) 条账单、\(summary.totalBookCount) 个账本、\(summary.totalAccountCount) 个账户。")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                BackupMetricTile(title: "分类方案", value: "\(summary.totalCategorySchemeCount) 套")
                BackupMetricTile(title: "文件大小", value: summary.fileSizeDescription)
                BackupMetricTile(title: "应用版本", value: summary.appVersion)
                BackupMetricTile(title: "备份格式", value: summary.backupVersion)
            }
        }
        .padding(18)
        .ledgerCard()
    }

    private var backupEmptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还没有发现云端备份")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)
            Text("先执行一次“立即备份”，后续这里会展示最近一次备份时间、数据规模和恢复入口。")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .ledgerCard()
    }

    private var backupSafetyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("恢复提醒", systemImage: "exclamationmark.triangle")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerCoral)
            Text("恢复操作会覆盖当前设备上的现有内容。若你刚录入了新数据，建议先执行一次手动备份，再继续恢复。")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .ledgerCard()
    }
}

struct PrivacySecurityView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SettingsLayout.sectionSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("隐私策略")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)
                    Text("敏感信息默认可控，展示行为只影响界面回显，不影响原始账单数据。")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .ledgerCard()

                VStack(spacing: 0) {
                    SettingToggleRow(
                        title: "去敏展示",
                        subtitle: "隐藏金额和支付方式",
                        isOn: Binding(
                            get: { store.appSettings.hideSensitiveInfo },
                            set: { store.appSettings.hideSensitiveInfo = $0 }))
                    Divider().padding(.leading, SettingsLayout.dividerLeading)

                    SettingToggleRow(
                        title: "展示记录图片",
                        subtitle: "用于自动记账回看截图",
                        isOn: Binding(
                            get: { store.appSettings.showRecordImages },
                            set: { store.appSettings.showRecordImages = $0 }))
                    Divider().padding(.leading, SettingsLayout.dividerLeading)

                    SettingToggleRow(
                        title: "地点展示",
                        subtitle: "允许在账单中展示地点字段",
                        isOn: Binding(
                            get: { store.appSettings.showLocation },
                            set: { store.appSettings.showLocation = $0 }))
                }
                .ledgerCard()
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(Color.ledgerCanvas.ignoresSafeArea())
        .navigationTitle("隐私与安全")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
            }
        }
    }
}

private struct SettingToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: SettingsLayout.titleFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: SettingsLayout.subtitleFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .accessibilityLabel(title)
                .tint(Color.ledgerAccent)
        }
        .padding(.horizontal, SettingsLayout.rowHorizontalPadding)
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
    }
}

private struct SettingSelectRow<MenuContent: View>: View {
    let title: String
    let value: String
    let menuContent: MenuContent

    init(title: String, value: String, @ViewBuilder menuContent: () -> MenuContent) {
        self.title = title
        self.value = value
        self.menuContent = menuContent()
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: SettingsLayout.titleFontSize, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerText)
            Spacer()
            Menu {
                menuContent
            } label: {
                HStack(spacing: 6) {
                    Text(value)
                        .font(.system(size: SettingsLayout.valueFontSize, weight: .medium, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.ledgerMuted)
            }
        }
        .padding(.horizontal, SettingsLayout.rowHorizontalPadding)
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
    }
}

private struct SettingCheckRow: View {
    let title: String
    @Binding var isChecked: Bool

    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: SettingsLayout.titleFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                Spacer()
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(isChecked ? Color.ledgerAccent : Color.ledgerMuted.opacity(0.6))
            }
            .padding(.horizontal, SettingsLayout.rowHorizontalPadding)
            .padding(.vertical, SettingsLayout.rowVerticalPadding)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingActionRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: SettingsLayout.titleFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.ledgerMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SettingsLayout.rowHorizontalPadding)
            .padding(.vertical, SettingsLayout.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct BackupActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint))
        }
        .buttonStyle(.plain)
        .opacity(1)
    }
}

private struct BackupMetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(16)
        .background(Color.ledgerAccentMuted.opacity(0.32))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HelpFeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    infoCard(
                        title: "常见问题",
                        message: "1. 你可以在设置中手动执行 iCloud 备份与恢复。\n2. 恢复云端备份会覆盖当前设备的数据。\n3. 月统计起始日会影响预算与图表。")
                    infoCard(
                        title: "反馈方式",
                        message: "你可以把问题截图、复现步骤和系统版本整理后提交给产品团队。")
                }
                .padding(20)
            }
            .background(Color.ledgerCanvas.ignoresSafeArea())
            .navigationTitle("帮助与反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func infoCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)
            Text(message)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .ledgerCard()
    }
}

private struct AboutAppView: View {
    @Environment(\.dismiss) private var dismiss

    private var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Monee")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ledgerText)
                    Text("专注记录效率与隐私保护的轻量记账应用。")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
                .padding(18)
                .ledgerCard()

                HStack {
                    Text("当前版本")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerText)
                    Spacer()
                    Text(versionDescription)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .ledgerCard()

                Spacer()
            }
            .padding(20)
            .background(Color.ledgerCanvas.ignoresSafeArea())
            .navigationTitle("关于 App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct LedgerHistoryDaySection: Identifiable {
    let date: Date
    let entries: [LedgerEntry]

    var id: Date { date }
}

struct LedgerHistoryView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var scope: LedgerHistoryScope = .currentBook
    @State private var showsFocusedBatchOnly = false
    @State private var selectedEntry: LedgerEntry?

    private static let sectionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    private var isSensitiveVisible: Bool {
        store.isBalanceVisible && !store.appSettings.hideSensitiveInfo
    }

    private var highlightedIDs: Set<UUID> {
        Set(store.historyPresentation.highlightedEntryIDs)
    }

    private var filteredDate: Date? {
        store.historyPresentation.filteredDate
    }

    private var isDayFiltered: Bool {
        filteredDate != nil
    }

    private var visibleEntries: [LedgerEntry] {
        let source = store.entries(scope: scope)
        let dateFiltered = source.filter { entry in
            guard let filteredDate else { return true }
            return Calendar.current.isDate(entry.date, inSameDayAs: filteredDate)
        }
        guard showsFocusedBatchOnly, !highlightedIDs.isEmpty else { return dateFiltered }
        return dateFiltered.filter { highlightedIDs.contains($0.id) }
    }

    private var daySections: [LedgerHistoryDaySection] {
        let grouped = Dictionary(grouping: visibleEntries) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }

        return grouped.keys
            .sorted(by: >)
            .map { day in
                LedgerHistoryDaySection(
                    date: day,
                    entries: grouped[day]?.sorted(by: { $0.date > $1.date }) ?? [])
            }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                historyHeader

                if highlightedIDs.isEmpty == false, !isDayFiltered {
                    focusedBatchBanner
                }

                if daySections.isEmpty {
                    EmptyFeatureState(
                        icon: "tray",
                        title: "还没有可显示的记录",
                        detail: emptyStateDetail)
                        .padding(.top, 24)
                } else {
                    VStack(spacing: 16) {
                        ForEach(daySections) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(sectionTitle(for: section.date))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.ledgerMuted)

                                VStack(spacing: 12) {
                                    ForEach(section.entries) { entry in
                                        Button {
                                            selectedEntry = entry
                                        } label: {
                                            TransactionRow(entry: entry, isSensitiveVisible: isSensitiveVisible)
                                                .padding(4)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                        .fill(highlightedIDs.contains(entry.id) ? Color.ledgerAccentSoft
                                                            .opacity(0.45) : Color.clear))
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button("删除", role: .destructive) {
                                                store.deleteEntry(id: entry.id)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(18)
                            .ledgerCard()
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(Color.ledgerCanvas.ignoresSafeArea())
        .navigationTitle(historyTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedEntry) { entry in
            LedgerEntryDetailSheet(store: store, entry: entry)
        }
        .onAppear {
            scope = store.historyPresentation.scope
            showsFocusedBatchOnly = !isDayFiltered &&
                store.historyPresentation.prefersFocusedBatch &&
                !highlightedIDs.isEmpty
        }
    }

    private var historyHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !isDayFiltered {
                Picker("记录范围", selection: $scope) {
                    ForEach(LedgerHistoryScope.allCases) { item in
                        Text(item.localizedTitle).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 12) {
                historyMetric(value: "\(visibleEntries.count)", title: showsFocusedBatchOnly ? "本次记录" : "当前结果")
                historyMetric(
                    value: LedgerFormatters
                        .currency(visibleEntries.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }),
                    title: "支出")
                historyMetric(
                    value: LedgerFormatters
                        .currency(visibleEntries.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }),
                    title: "收入")
            }
        }
    }

    private var focusedBatchBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.historyPresentation.title ?? "本次新增记录")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Text(showsFocusedBatchOnly ? "当前只看本次批次，关闭后会回到完整历史列表。" : "已高亮本次新增记录。")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(showsFocusedBatchOnly ? "查看全部" : "只看本次") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showsFocusedBatchOnly.toggle()
                }
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ledgerAccent)
        }
        .padding(16)
        .background(Color.ledgerAccentSoft.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var historyTitle: String {
        if let title = store.historyPresentation.title {
            return title
        }
        if let filteredDate {
            return LedgerFormatters.historyTitle(for: filteredDate)
        }
        return "全部记录"
    }

    private var emptyStateDetail: String {
        if isDayFiltered {
            return "这一天还没有记录，换个日期看看，或者先记一笔。"
        }
        if showsFocusedBatchOnly {
            return "这批记录已经被删除或当前过滤条件下为空。"
        }
        return "先记一笔或导入一份 CSV，这里会按日期汇总。"
    }

    private func historyMetric(value: String, title: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.ledgerElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sectionTitle(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "今天"
        }

        if Calendar.current.isDateInYesterday(date) {
            return "昨天"
        }

        return Self.sectionDateFormatter.string(from: date)
    }
}

// MARK: - CSV Import / Export (embedded so no separate target membership needed)

private enum CSVError: LocalizedError {
    case invalidFormat(String)
    case emptyFile
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case let .invalidFormat(msg): return "格式错误：\(msg)"
        case .emptyFile: return "文件为空或没有有效数据"
        case .encodingFailed: return "文件编码失败，请重试"
        }
    }
}

private struct CSVParseResult {
    let succeeded: [LedgerEntry]
    let failed: [(row: Int, reason: String)]
    let skipped: Int
}

@MainActor
private enum CSVService {
    private static let dateParseFormats = ["yyyy-MM-dd HH:mm", "yyyy/MM/dd HH:mm", "yyyy-MM-dd", "yyyy/MM/dd"]
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        return formatter
    }()
    private static let isoDateFormatter = ISO8601DateFormatter()

    private enum Column: CaseIterable {
        case date
        case kind
        case amount
        case category
        case paymentMethod
        case title
        case note
        case book
        case tags
        case excludeStatistics
        case excludeBudget
    }

    static func exportCSV(entries: [LedgerEntry], store: LedgerStore) -> String {
        var lines = ["日期,类型,金额,分类,付款账户,交易方,备注,账本,标签,不计收支,不计预算"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        for entry in entries.sorted(by: { $0.date > $1.date }) {
            let bookName = store.book(withID: entry.bookID)?.name ?? store.currentBook.name
            let paymentAccount = store.resolvedPaymentAccountName(for: entry)
            let tags = entry.tags.joined(separator: "|")
            let row = [
                formatter.string(from: entry.date),
                entry.kind == .expense ? "支出" : "收入",
                String(format: "%.2f", entry.amount),
                esc(entry.category.name),
                esc(paymentAccount),
                esc(entry.title),
                esc(entry.note),
                esc(bookName),
                esc(tags),
                entry.isExcludedFromStatistics ? "是" : "否",
                entry.isExcludedFromBudget ? "是" : "否"
            ].joined(separator: ",")
            lines.append(row)
        }

        return "\u{FEFF}" + lines.joined(separator: "\n")
    }

    static func parseCSV(_ csv: String, defaultBookID: UUID, store: LedgerStore) -> CSVParseResult {
        let content = csv.hasPrefix("\u{FEFF}") ? String(csv.dropFirst()) : csv
        let rows = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !rows.isEmpty else {
            return CSVParseResult(succeeded: [], failed: [(1, "文件为空")], skipped: 0)
        }

        let firstColumns = parseLine(rows[0])
        let headerMap = headerMapping(from: firstColumns)
        let dataRows: ArraySlice<String>
        let rowOffset: Int

        if headerMap.isEmpty {
            dataRows = rows[...]
            rowOffset = 1
        } else {
            dataRows = rows.dropFirst()
            rowOffset = 2
        }

        let allCategories = store.allCategories(for: .expense) + store.allCategories(for: .income)
        var succeeded: [LedgerEntry] = []
        var failed: [(row: Int, reason: String)] = []

        for (index, line) in dataRows.enumerated() {
            let rowNumber = index + rowOffset
            let columns = parseLine(line)

            guard let rawDate = value(for: .date, columns: columns, headerMap: headerMap),
                  let date = parseDate(rawDate) else {
                failed.append((rowNumber, "日期无效"))
                continue
            }

            guard let rawKind = value(for: .kind, columns: columns, headerMap: headerMap),
                  let kind = parseKind(rawKind) else {
                failed.append((rowNumber, "类型无效"))
                continue
            }

            guard let rawAmount = value(for: .amount, columns: columns, headerMap: headerMap),
                  let amount = parseAmount(rawAmount),
                  amount > 0 else {
                failed.append((rowNumber, "金额无效"))
                continue
            }

            let category = resolveCategory(
                value(for: .category, columns: columns, headerMap: headerMap),
                kind: kind,
                allCategories: allCategories)

            let paymentMethod = value(for: .paymentMethod, columns: columns, headerMap: headerMap)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let note = value(for: .note, columns: columns, headerMap: headerMap)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let titleValue = value(for: .title, columns: columns, headerMap: headerMap)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = titleValue.isEmpty ? (note.isEmpty ? category.name : note) : titleValue
            let bookName = value(for: .book, columns: columns, headerMap: headerMap)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let matchedBookID = store.books.first(where: { $0.name == bookName })?.id ?? defaultBookID
            let tags = parseTags(value(for: .tags, columns: columns, headerMap: headerMap))
            let excludeStatistics = parseBoolean(value(for: .excludeStatistics, columns: columns, headerMap: headerMap))
            let excludeBudget = excludeStatistics || parseBoolean(
                value(for: .excludeBudget, columns: columns, headerMap: headerMap))

            succeeded.append(
                LedgerEntry(
                    bookID: matchedBookID,
                    title: title,
                    amount: amount,
                    kind: kind,
                    category: category,
                    paymentMethod: paymentMethod.isEmpty ? "待确认" : paymentMethod,
                    accountID: store.matchingAccountID(for: paymentMethod),
                    tags: tags,
                    note: note,
                    date: date,
                    isExcludedFromStatistics: excludeStatistics,
                    isExcludedFromBudget: excludeBudget))
        }

        return CSVParseResult(succeeded: succeeded, failed: failed, skipped: 0)
    }

    private static func headerMapping(from columns: [String]) -> [Column: Int] {
        var mapping: [Column: Int] = [:]

        for (index, rawValue) in columns.enumerated() {
            switch normalizedHeader(rawValue) {
            case "日期", "时间", "账单日期":
                mapping[.date] = index
            case "类型":
                mapping[.kind] = index
            case "金额", "实付金额":
                mapping[.amount] = index
            case "分类":
                mapping[.category] = index
            case "付款账户", "支付方式", "支付账户":
                mapping[.paymentMethod] = index
            case "交易方", "标题", "商户":
                mapping[.title] = index
            case "备注":
                mapping[.note] = index
            case "账本":
                mapping[.book] = index
            case "标签":
                mapping[.tags] = index
            case "不计收支":
                mapping[.excludeStatistics] = index
            case "不计预算":
                mapping[.excludeBudget] = index
            default:
                break
            }
        }

        guard mapping[.date] != nil, mapping[.kind] != nil, mapping[.amount] != nil else {
            return [:]
        }

        return mapping
    }

    private static func normalizedHeader(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    private static func value(for column: Column, columns: [String], headerMap: [Column: Int]) -> String? {
        if let index = headerMap[column], columns.indices.contains(index) {
            return columns[index]
        }

        if !headerMap.isEmpty {
            return nil
        }

        let legacyIndex: Int? = switch column {
        case .date: 0
        case .kind: 1
        case .amount: 2
        case .category: 3
        case .paymentMethod: 4
        case .title: 5
        case .note: 5
        case .book: 6
        case .tags, .excludeStatistics, .excludeBudget: nil
        }

        guard let legacyIndex, columns.indices.contains(legacyIndex) else { return nil }
        return columns[legacyIndex]
    }

    private static func parseDate(_ rawValue: String) -> Date? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        for format in dateParseFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: trimmed) {
                return date
            }
        }

        if let date = isoDateFormatter.date(from: trimmed) {
            return date
        }

        return nil
    }

    private static func parseKind(_ rawValue: String) -> LedgerKind? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case "支出", "expense":
            return .expense
        case "收入", "income":
            return .income
        default:
            return nil
        }
    }

    private static func parseAmount(_ rawValue: String) -> Double? {
        let normalized = rawValue
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalized)
    }

    private static func resolveCategory(
        _ rawValue: String?,
        kind: LedgerKind,
        allCategories: [LedgerCategory]) -> LedgerCategory {
        guard let rawValue else {
            return LedgerCategory.defaultCategory(for: kind)
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return LedgerCategory.defaultCategory(for: kind)
        }

        let candidates = allCategories.filter { $0.kind == kind }
        if let exact = candidates.first(where: { $0.name == trimmed || $0.id == trimmed }) {
            return exact
        }

        let normalized = trimmed.lowercased().replacingOccurrences(of: " ", with: "")
        if let fuzzy = candidates.first(where: {
            let name = $0.name.lowercased().replacingOccurrences(of: " ", with: "")
            return name.contains(normalized) || normalized.contains(name)
        }) {
            return fuzzy
        }

        return LedgerCategory.defaultCategory(for: kind)
    }

    private static func parseTags(_ rawValue: String?) -> [String] {
        guard let rawValue else { return [] }

        return rawValue
            .components(separatedBy: CharacterSet(charactersIn: "|,，、"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func parseBoolean(_ rawValue: String?) -> Bool {
        guard let rawValue else { return false }
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "是", "开", "开启":
            return true
        default:
            return false
        }
    }

    private static func esc(_ v: String) -> String {
        (v.contains(",") || v.contains("\"") || v.contains("\n")) ?
            "\"\(v.replacingOccurrences(of: "\"", with: "\"\""))\"" : v
    }

    private static func parseLine(_ line: String) -> [String] {
        var res: [String] = []
        var cur = ""
        var inQ = false
        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]
            if ch == "\"" {
                let next = line.index(after: i)
                if inQ && next < line.endIndex && line[next] == "\"" { cur.append("\"")
                    i = next
                }
                else { inQ.toggle() }
            } else if ch == "," && !inQ { res.append(cur)
                cur = ""
            }
            else { cur.append(ch) }
            i = line.index(after: i)
        }
        res.append(cur)
        return res
    }
}

private struct CSVFile: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    var content: String
    init(content: String) {
        self.content = content
    }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let s = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { throw CSVError.encodingFailed }
        content = s
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let d = content.data(using: .utf8) else { throw CSVError.encodingFailed }
        return FileWrapper(regularFileWithContents: d)
    }
}

struct CSVImportExportView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    @State private var activeTab: Tab = .export
    @State private var scope: Scope = .currentBook
    @State private var range: Range = .allTime
    @State private var exportFile: CSVFile?
    @State private var showExportShare = false
    @State private var isPreparingExport = false
    @State private var isImporting = false
    @State private var importResult: CSVParseResult?
    @State private var showImportConfirm = false
    @State private var isProcessing = false
    @State private var importSuccessMessage: String?
    @State private var errorMessage: String?

    private enum Tab: String, CaseIterable { case export = "导出"
        case `import` = "导入"
    }
    private enum Scope: String, CaseIterable { case currentBook = "当前账本"
        case allBooks = "全部账本"
    }
    private enum Range: String, CaseIterable { case thisMonth = "本月"
        case last3Months = "近3个月"
        case thisYear = "今年"
        case allTime = "全部"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                tabBar.padding(.top, 4)
                if activeTab == .export { exportTab } else { importTab }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.ledgerCanvas.ignoresSafeArea())
        .navigationTitle("导入 / 导出")
        .fileExporter(isPresented: $showExportShare, document: exportFile,
                      contentType: .commaSeparatedText, defaultFilename: exportName) { r in
            isPreparingExport = false
            defer { exportFile = nil }
            if case .failure(let error) = r,
               (error as NSError).code != NSUserCancelledError {
                errorMessage = "导出失败，请重试"
            }
        }
        .fileImporter(isPresented: $isImporting,
                      allowedContentTypes: [.commaSeparatedText, .plainText],
                      allowsMultipleSelection: false, onCompletion: handleImport)
        .confirmationDialog(confirmTitle, isPresented: $showImportConfirm, titleVisibility: .visible) {
            if let r = importResult, !r.succeeded.isEmpty {
                Button("确认导入 \(r.succeeded.count) 条") { commitImport(r) }
            }
            Button("取消", role: .cancel) { importResult = nil }
        } message: { if let r = importResult { Text(confirmMessage(r)) } }
        .alert("错误", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好的") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onChange(of: showExportShare) { _, isPresented in
            if !isPresented, exportFile != nil {
                isPreparingExport = false
                exportFile = nil
            }
        }
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { activeTab = t } } label: {
                    Text(t.rawValue.localized)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(activeTab == t ? .white : Color.ledgerMuted)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(activeTab == t ? RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.ledgerAccent) : RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous).fill(Color.clear))
                }.buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.ledgerAccentMuted))
    }

    // MARK: Export tab

    private var exportTab: some View {
        let entries = filtered()
        return VStack(spacing: 16) {
            // Scope picker
            VStack(alignment: .leading, spacing: 0) {
                header("导出范围", icon: "books.vertical.fill")
                ForEach(Scope.allCases, id: \.self) { s in
                    optionRow(title: s.rawValue,
                              subtitle: s == .currentBook ? store.currentBook.name : "共 \(store.books.count) 个账本",
                              selected: scope == s) { scope = s }
                    if s != Scope.allCases.last { Divider().padding(.leading, 52) }
                }
            }.ledgerCard()

            // Range picker
            VStack(alignment: .leading, spacing: 0) {
                header("时间范围", icon: "calendar")
                ForEach(Range.allCases, id: \.self) { r in
                    let cnt = filtered(scope: scope, range: r).count
                    optionRow(title: r.rawValue, subtitle: "\(cnt) 条记录", selected: range == r) { range = r }
                    if r != Range.allCases.last { Divider().padding(.leading, 52) }
                }
            }.ledgerCard()

            // Summary
            HStack(spacing: 0) {
                statBlock("\(entries.count)", label: "记录数", color: .ledgerAccent)
                Divider().frame(height: 40)
                statBlock(
                    LedgerFormatters.currency(entries.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }),
                    label: "总支出",
                    color: .ledgerExpense)
                Divider().frame(height: 40)
                statBlock(
                    LedgerFormatters.currency(entries.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }),
                    label: "总收入",
                    color: .ledgerIncome)
            }.padding(.vertical, 16).ledgerCard()

            // Export button
            Button {
                beginExport(entries: entries)
            } label: {
                Label("导出 CSV 文件", systemImage: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(entries.isEmpty || isPreparingExport ? Color.ledgerMuted : Color.ledgerAccent))
            }
            .buttonStyle(LedgerResponsiveButtonStyle())
            .disabled(entries.isEmpty || isPreparingExport || showExportShare)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill").foregroundStyle(Color.ledgerGold).font(.system(size: 14))
                Text("导出的 CSV 可直接用 Excel 或 Numbers 打开，也可以重新导入本应用。")
                    .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color.ledgerMuted)
            }.padding(14).background(Color.ledgerGold.opacity(0.08)).clipShape(RoundedRectangle(
                cornerRadius: 14,
                style: .continuous))
        }
    }

    // MARK: Import tab

    private var importTab: some View {
        VStack(spacing: 16) {
            Button { isImporting = true } label: {
                VStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.ledgerAccentMuted).frame(width: 72, height: 72)
                        Image(systemName: "doc.badge.plus").font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Color.ledgerAccent)
                    }
                    VStack(spacing: 4) {
                        Text("选择 CSV 文件").font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ledgerText)
                        Text("支持从本地、iCloud Drive 或其他 App 导入")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ledgerMuted).multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 36)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.ledgerAccent.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.ledgerAccentMuted.opacity(0.4))))
            }.buttonStyle(.plain)

            if isProcessing {
                HStack(spacing: 12) { ProgressView()
                    Text("解析中…").font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16).ledgerCard()
            }

            if let importSuccessMessage {
                Label(importSuccessMessage, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerIncome)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    .background(Color.ledgerIncome.opacity(0.08)).clipShape(RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous))
            }

            VStack(alignment: .leading, spacing: 0) {
                header("CSV 格式说明", icon: "info.circle.fill")
                ForEach([
                    ("日期", "支持 YYYY-MM-DD HH:mm，也兼容旧版纯日期"),
                    ("类型", "支出 / 收入，兼容 expense / income"),
                    ("金额", "正数，如 58.00"),
                    ("分类", "按当前分类名称匹配，找不到会回退默认分类"),
                    ("付款账户", "如 微信余额、支付宝、现金"),
                    ("交易方", "商户或记录标题"),
                    ("备注", "可留空"),
                    ("账本", "可留空，默认导入到当前账本"),
                    ("标签", "可用 | 、逗号分隔多个标签"),
                    ("不计收支", "是 / 否"),
                    ("不计预算", "是 / 否")
                ], id: \.0) { col, desc in
                    HStack(alignment: .top, spacing: 8) {
                        Text(col).font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ledgerAccent).frame(
                                width: 60,
                                alignment: .leading)
                        Text(desc).font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ledgerMuted)
                    }.padding(.horizontal, 16).padding(.vertical, 6)
                }
                Spacer().frame(height: 12)
            }.ledgerCard()
        }
    }

    // MARK: Helpers

    private func header(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Color.ledgerMuted)
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
    }

    private func optionRow(title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(selected ? Color.ledgerAccent : Color.ledgerAccentMuted).frame(width: 22, height: 22)
                    if selected {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)
                    Text(subtitle).font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
                Spacer()
            }.padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func statBlock(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(color).lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Color.ledgerMuted)
        }.frame(maxWidth: .infinity)
    }

    private func filtered(scope s: Scope? = nil, range r: Range? = nil) -> [LedgerEntry] {
        let s = s ?? scope
        let r = r ?? range
        var all = s == .currentBook ? store.entries.filter { $0.bookID == store.currentBook.id } : store.entries
        let cal = Calendar.current
        let now = Date()
        switch r {
        case .thisMonth: if let d = cal
            .date(from: cal.dateComponents([.year, .month], from: now)) { all = all.filter { $0.date >= d } }
        case .last3Months: if let d = cal
            .date(byAdding: .month, value: -3, to: now) { all = all.filter { $0.date >= d } }
        case .thisYear: if let d = cal.date(from: DateComponents(
                year: cal.component(.year, from: now),
                month: 1,
                day: 1)) { all = all.filter { $0.date >= d } }
        case .allTime: break
        }
        return all
    }

    private var exportName: String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return "ledger_\(f.string(from: Date())).csv"
    }

    private var confirmTitle: String { importResult?.succeeded.isEmpty == true ? "无法导入" : "解析完成" }
    private func confirmMessage(_ r: CSVParseResult) -> String {
        var p: [String] = []
        if !r.succeeded.isEmpty { p.append("可导入 \(r.succeeded.count) 条") }
        if !r.failed.isEmpty { p.append("\(r.failed.count) 行失败") }
        return p.joined(separator: "，")
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else {
            if case let .failure(e) = result { errorMessage = e.localizedDescription }
            return
        }
        isProcessing = true
        importSuccessMessage = nil
        Task {
            do {
                let ok = url.startAccessingSecurityScopedResource()
                defer { if ok { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
                guard !str.isEmpty else { throw CSVError.emptyFile }
                await MainActor.run {
                    isProcessing = false
                    importResult = CSVService.parseCSV(str, defaultBookID: store.currentBook.id, store: store)
                    showImportConfirm = true
                }
            } catch {
                await MainActor.run { isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func commitImport(_ r: CSVParseResult) {
        let createdEntries = r.succeeded.map { entry in
            store.addEntry(
                bookID: entry.bookID,
                title: entry.title,
                amount: entry.amount,
                kind: entry.kind,
                category: entry.category,
                accountID: entry.accountID,
                paymentMethod: entry.paymentMethod,
                tags: entry.tags,
                note: entry.note,
                date: entry.date,
                isExcludedFromStatistics: entry.isExcludedFromStatistics,
                isExcludedFromBudget: entry.isExcludedFromBudget)
        }

        importResult = nil
        guard !createdEntries.isEmpty else { return }

        let importedBookCount = Set(createdEntries.map(\.bookID)).count
        if createdEntries.count == 1 {
            importSuccessMessage = "导入成功！1 条记录已添加到账本"
        } else if importedBookCount > 1 {
            importSuccessMessage = "导入成功！\(createdEntries.count) 条记录已添加到 \(importedBookCount) 个账本"
        } else {
            importSuccessMessage = "导入成功！\(createdEntries.count) 条记录已添加到账本"
        }
    }

    private func beginExport(entries: [LedgerEntry]) {
        guard !entries.isEmpty, !isPreparingExport, !showExportShare else { return }
        isPreparingExport = true
        exportFile = CSVFile(content: CSVService.exportCSV(entries: entries, store: store))
        DispatchQueue.main.async {
            guard exportFile != nil else {
                isPreparingExport = false
                return
            }
            showExportShare = true
        }
    }
}

// MARK: - AI Billing (embedded)

// MARK: - AI Parse Result

struct AIParseResult {
    var amount: Double?
    var kind: LedgerKind
    var categoryHint: String
    var merchant: String
    var note: String
    var paymentMethod: String
    var rawText: String

    init(
        amount: Double? = nil,
        kind: LedgerKind = .expense,
        categoryHint: String = "",
        merchant: String = "",
        note: String = "",
        paymentMethod: String = "",
        rawText: String = "") {
        self.amount = amount
        self.kind = kind
        self.categoryHint = categoryHint
        self.merchant = merchant
        self.note = note
        self.paymentMethod = paymentMethod
        self.rawText = rawText
    }
}

// MARK: - AI Parser

enum AIParser {
    // Regex for Chinese currency amounts
    private static let amountPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"[¥￥]\s*(\d+(?:[.,]\d{1,2})?)"#),
        try! NSRegularExpression(pattern: #"(?:合计|总计|金额|实付|支付|消费|到账|转账)[：:]\s*[¥￥]?\s*(\d+(?:[.,]\d{1,2})?)"#),
        try! NSRegularExpression(pattern: #"(\d+(?:\.\d{1,2})?)元"#),
        try! NSRegularExpression(pattern: #"Amount[:\s]+\$?(\d+(?:\.\d{1,2})?)"#, options: .caseInsensitive)
    ]

    private static let incomeKeywords = [
        "工资",
        "到账",
        "收入",
        "报销",
        "转入",
        "salary",
        "income",
        "received",
        "refund",
        "退款",
        "奖金"
    ]
    private static let paymentKeywords: [String: String] = [
        "微信": "微信", "wechat": "微信",
        "支付宝": "支付宝", "alipay": "支付宝",
        "银联": "银行卡", "银行": "银行卡", "储蓄卡": "银行卡",
        "信用卡": "信用卡", "visa": "信用卡", "mastercard": "信用卡",
        "现金": "现金", "cash": "现金"
    ]
    private static let categoryMap: [(keywords: [String], category: String)] = [
        (
            ["餐厅", "外卖", "美食", "早餐", "午餐", "晚餐", "奶茶", "咖啡", "food", "restaurant", "meal", "lunch", "dinner",
             "mcdonald",
             "kfc", "starbucks"],
            "餐饮"),
        (["超市", "便利店", "购物", "淘宝", "京东", "天猫", "amazon", "mall", "shop"], "购物"),
        (["滴滴", "地铁", "公交", "打车", "高铁", "机票", "taxi", "uber", "grab", "mrt", "bus", "train", "flight"], "交通"),
        (["租金", "水电", "物业", "房", "rent", "utilities", "housing"], "住房"),
        (["电影", "游戏", "娱乐", "ktv", "cinema", "game", "entertainment"], "休闲娱乐"),
        (["医院", "药店", "体检", "诊所", "hospital", "pharmacy", "clinic", "health"], "医疗健康"),
        (["书", "课程", "培训", "教育", "book", "course", "study", "tuition"], "学习办公"),
        (["宠物", "pet", "cat", "dog"], "宠物"),
        (["工资", "salary", "wage"], "工资"),
        (["理财", "基金", "股票", "invest", "fund"], "理财收益")
    ]

    /// Main entry point when spatial row-pair data is available (screenshot OCR).
    /// rowPairs contains (label, value) tuples extracted by grouping observations
    /// that share the same Y coordinate — this correctly handles payment apps where
    /// label and value are on the same row but different X positions.
    static func parseTextAndPairs(
        _ text: String,
        rowPairs: [(label: String, value: String)],
        scheme: LedgerCategoryScheme) -> AIParseResult {
        var result = parseText(text, scheme: scheme)

        // Override note/merchant using the spatial row pairs — much more reliable
        let noteLabels = ["备注", "摘要", "remark", "note", "description"]
        let payeeLabels = ["收款方", "商户名称", "收款商家", "merchant", "收款人"]
        let paymentLabels = ["付款方式", "支付方式", "payment"]

        for pair in rowPairs {
            let labelLower = pair.label.lowercased()
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "：:"))

            // Note field — highest priority
            if noteLabels.contains(where: { labelLower == $0 || labelLower.hasPrefix($0) }) {
                let val = pair.value.trimmingCharacters(in: .whitespaces)
                if !val.isEmpty {
                    result.note = val
                    result.merchant = val
                }
            }
            // Payee — use as note fallback if no explicit 备注 found
            else if result.note.isEmpty,
                    payeeLabels.contains(where: { labelLower == $0 || labelLower.hasPrefix($0) }) {
                let val = pair.value.trimmingCharacters(in: .whitespaces)
                if !val.isEmpty {
                    result.merchant = val
                    // Only set note from payee if still empty
                    if result.note.isEmpty { result.note = val }
                }
            }
            // Payment method from row pairs (more reliable than keyword scan)
            else if paymentLabels.contains(where: { labelLower.hasPrefix($0) }) {
                let val = pair.value.lowercased()
                for (keyword, method) in paymentKeywords {
                    if val.contains(keyword) {
                        result.paymentMethod = method
                        break
                    }
                }
            }
        }

        return result
    }

    static func parseText(_ text: String, scheme: LedgerCategoryScheme) -> AIParseResult {
        let lower = text.lowercased()
        var result = AIParseResult(rawText: text)

        // Amount
        for pattern in amountPatterns {
            let range = NSRange(text.startIndex..., in: text)
            if let match = pattern.firstMatch(in: text, range: range),
               let r = Range(match.range(at: 1), in: text),
               let value = Double(text[r].replacingOccurrences(of: ",", with: "")) {
                result.amount = value
                break
            }
        }

        // Kind
        if incomeKeywords.contains(where: { lower.contains($0) }) {
            result.kind = .income
        }

        // Payment method
        for (keyword, method) in paymentKeywords {
            if lower.contains(keyword) {
                result.paymentMethod = method
                break
            }
        }

        // Category hint
        for (keywords, categoryName) in categoryMap {
            if keywords.contains(where: { lower.contains($0) }) {
                result.categoryHint = categoryName
                break
            }
        }

        // Merchant / note — prefer explicit 备注 field, then fall back to merchant name
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // 1. Look for a line that IS or immediately follows a 备注 label
        let noteKeywords = ["备注", "摘要", "remark", "note", "description"]
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            // Pattern A: "备注  打车 回家"  — label and value on the same line
            for kw in noteKeywords {
                if lower.hasPrefix(kw) {
                    let value = line.dropFirst(kw.count)
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "：:"))
                        .trimmingCharacters(in: .whitespaces)
                    if value.count >= 1 {
                        result.merchant = String(value)
                        result.note = String(value)
                        break
                    }
                }
            }
            if !result.note.isEmpty { break }
            // Pattern B: label on one line, value on the next
            if noteKeywords.contains(where: { lower == $0 || lower == $0 + "：" || lower == $0 + ":" }),
               i + 1 < lines.count {
                let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                if nextLine.count >= 1 {
                    result.merchant = nextLine
                    result.note = nextLine
                    break
                }
            }
        }

        // 2. Fall back: use the merchant/payee name (收款方 line)
        if result.note.isEmpty {
            let payeeKeywords = ["收款方", "商户名称", "收款商家", "merchant"]
            for (i, line) in lines.enumerated() {
                let lower = line.lowercased()
                for kw in payeeKeywords {
                    if lower.hasPrefix(kw) {
                        let value = line.dropFirst(kw.count)
                            .trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "：:"))
                            .trimmingCharacters(in: .whitespaces)
                        if value.count >= 1 {
                            result.merchant = String(value)
                            result.note = String(value)
                            break
                        }
                    }
                }
                if !result.note.isEmpty { break }
                if payeeKeywords.contains(where: { lower == $0 || lower == $0 + "：" }),
                   i + 1 < lines.count {
                    let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                    if nextLine.count >= 1 {
                        result.merchant = nextLine
                        result.note = nextLine
                        break
                    }
                }
            }
        }

        return result
    }

    /// Match categoryHint to actual LedgerCategory in the current scheme
    static func resolvedCategory(for result: AIParseResult, scheme: LedgerCategoryScheme) -> LedgerCategory {
        let allCats = result.kind == .expense ? scheme.expenseCategories : scheme.incomeCategories
        let hint = result.categoryHint.lowercased()
        return allCats.first(where: { $0.name.lowercased().contains(hint) || hint.contains($0.name.lowercased()) })
            ?? LedgerCategory.defaultCategory(for: result.kind)
    }
}

// MARK: - Screenshot OCR

@MainActor
final class ScreenshotOCRViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var recognizedText = ""
    @Published var parseResult: AIParseResult?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showImagePicker = false
    @Published var showCamera = false
    @Published var confidence: Float = 0

    func recognizeImage(_ image: UIImage, scheme: LedgerCategoryScheme) {
        selectedImage = image
        isProcessing = true
        errorMessage = nil
        recognizedText = ""
        parseResult = nil
        confidence = 0

        guard let cgImage = image.cgImage else {
            errorMessage = "无法处理该图片"
            isProcessing = false
            return
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                guard let self else { return }

                if let error {
                    Task { @MainActor in
                        self.errorMessage = "识别失败：\(error.localizedDescription)"
                        self.isProcessing = false
                    }
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    Task { @MainActor in
                        self.errorMessage = "未识别到文字"
                        self.isProcessing = false
                    }
                    return
                }

                let allText = observations.compactMap { $0.topCandidates(1).first }
                let fullText = allText.map(\.string).joined(separator: "\n")
                let avgConfidence =
                    allText.isEmpty ? 0 : allText.reduce(0) { $0 + $1.confidence } / Float(allText.count)

                // Build row-aware pairs: group observations by Y position so that
                // left-side labels (e.g. "备注") are matched with right-side values
                // (e.g. "打车 回家") that sit on the same horizontal row.
                var rowPairs: [(label: String, value: String)] = []
                // Each observation has a boundingBox in normalised coords (0-1, origin bottom-left)
                let obs = observations.compactMap { o -> (text: String, midY: CGFloat, minX: CGFloat)? in
                    guard let top = o.topCandidates(1).first else { return nil }
                    let box = o.boundingBox
                    return (top.string, box.midY, box.minX)
                }
                // Group by midY within a tolerance of 0.03 (≈ one text line height)
                let tolerance: CGFloat = 0.03
                var used = [Bool](repeating: false, count: obs.count)
                for i in 0..<obs.count {
                    guard !used[i] else { continue }
                    var group = [obs[i]]
                    used[i] = true
                    for j in (i + 1)..<obs.count {
                        if !used[j], abs(obs[j].midY - obs[i].midY) < tolerance {
                            group.append(obs[j])
                            used[j] = true
                        }
                    }
                    // Sort left→right by minX
                    group.sort { $0.minX < $1.minX }
                    if group.count >= 2 {
                        // Left-most = label, right-most = value
                        rowPairs.append((label: group.first!.text, value: group.last!.text))
                    }
                }

                Task { @MainActor in
                    self.recognizedText = fullText
                    self.confidence = avgConfidence
                    self.parseResult = AIParser.parseTextAndPairs(fullText, rowPairs: rowPairs, scheme: scheme)
                    self.isProcessing = false
                }
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true

            try? handler.perform([request])
        }
    }
}

// MARK: - Voice Recognition

@MainActor
final class VoiceRecognitionViewModel: ObservableObject {
    @Published var transcript = ""
    @Published var isListening = false
    @Published var parseResult: AIParseResult?
    @Published var errorMessage: String?
    @Published var authStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-Hans-CN"))
        authStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                self?.authStatus = status
            }
        }
    }

    func startListening(scheme: LedgerCategoryScheme) {
        guard authStatus == .authorized else {
            errorMessage = "请在设置中允许麦克风和语音识别权限"
            return
        }
        guard !isListening else { return }

        stopListening()
        transcript = ""
        parseResult = nil
        errorMessage = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "麦克风初始化失败"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation

        let inputNode = audioEngine.inputNode
        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor [weak self] in
                    self?.transcript = text
                    self?.resetSilenceTimer(text: text, scheme: scheme)
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor [weak self] in
                    self?.finalize(scheme: scheme)
                }
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            errorMessage = "无法启动录音引擎"
        }
    }

    func stopListening() {
        silenceTimer?.invalidate()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func resetSilenceTimer(text: String, scheme: LedgerCategoryScheme) {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.finalize(scheme: scheme)
            }
        }
    }

    private func finalize(scheme: LedgerCategoryScheme) {
        stopListening()
        guard !transcript.isEmpty else { return }
        parseResult = AIParser.parseText(transcript, scheme: scheme)
    }
}

// MARK: - Main AI Billing View

struct AIBillingView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var activeTab: AITab = .screenshot
    @StateObject private var ocrVM = ScreenshotOCRViewModel()
    @StateObject private var voiceVM = VoiceRecognitionViewModel()
    @State private var savedEntry = false
    @State private var lastSavedAmount: String = ""

    private enum AITab: String, CaseIterable {
        case screenshot = "截图识别"
        case voice = "语音记账"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Hero pill tabs
                HStack(spacing: 0) {
                    ForEach(AITab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                                activeTab = tab
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab == .screenshot ? "camera.viewfinder" : "waveform.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(tab.rawValue.localized)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(activeTab == tab ? .white : Color.ledgerMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                activeTab == tab
                                    ? RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.ledgerAccent)
                                    : RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.clear))
                        }
                    }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.ledgerAccentMuted))
                .padding(.top, 4)

                if activeTab == .screenshot {
                    screenshotTab
                } else {
                    voiceTab
                }

                if savedEntry {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.ledgerIncome)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("已记账！")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ledgerText)
                            Text("\(lastSavedAmount) 已添加到账本")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ledgerMuted)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.ledgerIncome.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.ledgerCanvas.ignoresSafeArea())
        .navigationTitle("AI 智能记账")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $ocrVM.showImagePicker) {
            ImagePickerRepresentable(sourceType: .photoLibrary) { image in
                ocrVM.recognizeImage(image, scheme: store.currentCategoryScheme)
            }
        }
        .sheet(isPresented: $ocrVM.showCamera) {
            ImagePickerRepresentable(sourceType: .camera) { image in
                ocrVM.recognizeImage(image, scheme: store.currentCategoryScheme)
            }
        }
    }

    // MARK: Screenshot Tab

    private var screenshotTab: some View {
        VStack(spacing: 16) {
            // Image preview or upload prompt
            if let image = ocrVM.selectedImage {
                imagePreviewCard(image)
            } else {
                screenshotUploadArea
            }

            // Loading
            if ocrVM.isProcessing {
                aiProcessingCard(message: "正在识别图片文字…")
            }

            // Error
            if let err = ocrVM.errorMessage {
                aiErrorCard(err)
            }

            // Result
            if let result = ocrVM.parseResult {
                aiResultCard(result: result, onUse: {
                    saveEntry(from: result)
                }, onRetry: {
                    ocrVM.selectedImage = nil
                    ocrVM.parseResult = nil
                })
            }

            // Tips
            screenshotTipsCard
        }
    }

    private var screenshotUploadArea: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.ledgerAccentMuted)
                    .frame(width: 80, height: 80)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.ledgerAccent)
            }
            VStack(spacing: 4) {
                Text("上传支付截图")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                Text("支持微信、支付宝、银行 App 等截图")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            HStack(spacing: 12) {
                Button {
                    ocrVM.showImagePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                        Text("从相册选择")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.ledgerAccentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    ocrVM.showCamera = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera")
                        Text("拍照识别")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.ledgerAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.ledgerAccent.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.ledgerAccentMuted.opacity(0.3))))
    }

    private func imagePreviewCard(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(maxHeight: 280)

            Button {
                ocrVM.selectedImage = nil
                ocrVM.parseResult = nil
                ocrVM.recognizedText = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.ledgerMuted)
                    .background(Circle().fill(Color.ledgerSurface))
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }

    private var screenshotTipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("识别效果最佳的截图类型", systemImage: "sparkles")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerAccent)
            ForEach([
                ("微信支付成功页", "checkmark.circle"),
                ("支付宝收付款记录", "checkmark.circle"),
                ("银行 App 转账/消费通知", "checkmark.circle"),
                ("收款码金额截图", "checkmark.circle")
            ], id: \.0) { tip, icon in
                Label(tip, systemImage: icon)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ledgerCard()
    }

    // MARK: Voice Tab

    private var voiceTab: some View {
        VStack(spacing: 16) {
            voiceMicArea
            if voiceVM.isListening || !voiceVM.transcript.isEmpty {
                voiceTranscriptCard
            }
            if voiceVM.isListening {
                aiProcessingCard(message: "正在聆听，说完后自动识别…")
            }
            if let err = voiceVM.errorMessage {
                aiErrorCard(err)
            }
            if let result = voiceVM.parseResult {
                aiResultCard(result: result, onUse: {
                    saveEntry(from: result)
                }, onRetry: {
                    voiceVM.transcript = ""
                    voiceVM.parseResult = nil
                })
            }
            voiceTipsCard
        }
        .onAppear { voiceVM.requestPermissions() }
        .onDisappear { voiceVM.stopListening() }
    }

    private var voiceMicArea: some View {
        VStack(spacing: 20) {
            // Pulse animation when listening
            ZStack {
                if voiceVM.isListening {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.ledgerAccent.opacity(0.15 - Double(i) * 0.04))
                            .frame(width: 120 + CGFloat(i) * 30, height: 120 + CGFloat(i) * 30)
                            .scaleEffect(voiceVM.isListening ? 1.1 : 0.9)
                            .animation(
                                .easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(Double(i) * 0.2),
                                value: voiceVM.isListening)
                    }
                }

                Button {
                    if voiceVM.isListening {
                        voiceVM.stopListening()
                    } else {
                        voiceVM.startListening(scheme: store.currentCategoryScheme)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(voiceVM.isListening ? Color.ledgerExpense : Color.ledgerAccent)
                            .frame(width: 88, height: 88)
                            .shadow(
                                color: (voiceVM.isListening ? Color.ledgerExpense : Color.ledgerAccent).opacity(0.4),
                                radius: 16,
                                x: 0,
                                y: 8)
                        Image(systemName: voiceVM.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 160)

            VStack(spacing: 4) {
                Text(voiceVM.isListening ? "正在录音…点击停止" : "点击开始语音记账")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                Text(voiceVM.isListening ? "说出金额和消费类型" : "支持普通话和粤语")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            if voiceVM.authStatus == .denied || voiceVM.authStatus == .restricted {
                Label("请在系统设置中开启语音识别权限", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerExpense)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .ledgerCard()
    }

    private var voiceTranscriptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("识别内容", systemImage: "text.quote")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
            Text(voiceVM.transcript.isEmpty ? "等待语音输入…" : voiceVM.transcript)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(voiceVM.transcript.isEmpty ? Color.ledgerMuted : Color.ledgerText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .ledgerCard()
    }

    private var voiceTipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("语音示例", systemImage: "text.bubble.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerAccent)
            ForEach([
                "「今天吃饭花了 58 元」",
                "「打车花了 32 块，用支付宝」",
                "「工资到账 15000 元」",
                "「超市购物 120.5 元，微信支付」"
            ], id: \.self) { tip in
                HStack(spacing: 6) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ledgerAccent.opacity(0.6))
                    Text(tip)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ledgerCard()
    }

    // MARK: Shared Components

    private func aiProcessingCard(message: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Color.ledgerAccent)
            Text(message)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .ledgerCard()
    }

    private func aiErrorCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.ledgerExpense)
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ledgerExpense.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func aiResultCard(result: AIParseResult, onUse: @escaping () -> Void,
                              onRetry: @escaping () -> Void) -> some View {
        let category = AIParser.resolvedCategory(for: result, scheme: store.currentCategoryScheme)

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("AI 识别结果", systemImage: "sparkle")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerAccent)
                Spacer()
                Button(action: onRetry) {
                    Text("重新识别")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            // Fields
            VStack(spacing: 0) {
                aiResultRow(
                    label: "金额",
                    value: result.amount.map { LedgerFormatters.currency($0) } ?? "未识别",
                    accent: result
                        .amount != nil ? (result.kind == .expense ? .ledgerExpense : .ledgerIncome) : .ledgerMuted)
                Divider().padding(.leading, 16)
                aiResultRow(label: "类型", value: result.kind.localizedTitle, accent: .ledgerText)
                Divider().padding(.leading, 16)
                aiResultRow(label: "分类", value: category.name.localized, accent: category.tint)
                if !result.paymentMethod.isEmpty {
                    Divider().padding(.leading, 16)
                    aiResultRow(label: "支付", value: result.paymentMethod, accent: .ledgerText)
                }
            }

            // Use button
            Divider()
            Button(action: onUse) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(result.amount != nil ? "确认记账" : "手动补充后记账")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.ledgerAccent)
                .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
                .clipShape(
                    .rect(bottomLeadingRadius: 22, bottomTrailingRadius: 22, style: .continuous))
            }
            .buttonStyle(LedgerResponsiveButtonStyle())
        }
        .background(Color.ledgerElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
    }

    private func aiResultRow(label: String, value: String, accent: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .frame(width: 44, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Direct save

    private func saveEntry(from result: AIParseResult) {
        var draft = store.makeDraft()
        draft.kind = result.kind
        draft.amountText = result.amount.map { String(format: "%.2f", $0) } ?? ""
        draft.selectedCategory = AIParser.resolvedCategory(for: result, scheme: store.currentCategoryScheme)
        draft.paymentMethod = result.paymentMethod.isEmpty ? draft.paymentMethod : result.paymentMethod
        draft.note = ""
        store.addEntry(from: draft)
        lastSavedAmount = result.amount.map { LedgerFormatters.currency($0) } ?? ""
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            savedEntry = true
        }
        // Reset after 2.5s so user can scan another receipt
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { savedEntry = false }
            ocrVM.selectedImage = nil
            ocrVM.parseResult = nil
            voiceVM.transcript = ""
            voiceVM.parseResult = nil
        }
    }
}

// MARK: - Entry Confirm Sheet

// MARK: - Image Picker Bridge

struct ImagePickerRepresentable: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onSelect: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onSelect: (UIImage) -> Void
        init(onSelect: @escaping (UIImage) -> Void) {
            self.onSelect = onSelect
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onSelect(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
