import Charts
import SwiftUI

enum ManagementScreen: String, Identifiable {
    case statistics
    case assets
    case books
    case categories
    case autoLedgerCenter
    case widgets
    case settings

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
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.ledgerText)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .statistics:
            StatisticsView()
        case .assets:
            AssetManagementView()
        case .books:
            BookManagementView()
        case .categories:
            CategoryManagementView()
        case .autoLedgerCenter:
            AutoLedgerCenterView()
        case .widgets:
            WidgetCenterView()
        case .settings:
            SettingsView()
        }
    }
}

private enum StatisticsRange: String, CaseIterable, Identifiable {
    case week = "近7天"
    case month = "本月"

    var id: String { rawValue }
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
        store.currentBookEntries.filter { entry in
            switch range {
            case .week:
                let start = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date())) ?? Date()
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
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("图表统计")
    }

    private var statisticsHeader: some View {
        HStack(spacing: 12) {
            Picker("范围", selection: $range) {
                ForEach(StatisticsRange.allCases) { item in
                    Text(item.rawValue).tag(item)
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
                .background(.white.opacity(0.88))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(range == .week ? "近 7 天概览" : "本月概览")
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
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.ledgerAccent.opacity(0.22), radius: 24, x: 0, y: 18)
        )
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
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 176)
            }

            if trendPoints.allSatisfy({ $0.amount == 0 }) {
                EmptyFeatureState(
                    icon: "chart.bar.xaxis",
                    title: "还没有可统计的数据",
                    detail: "先记几笔账，再回来看看趋势变化。"
                )
                .frame(height: 220)
            } else {
                Chart(trendPoints) { point in
                    BarMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("金额", point.amount)
                    )
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
                    detail: "等你记上几笔以后，这里会显示主要分类占比。"
                )
            } else {
                VStack(spacing: 14) {
                    ForEach(categoryRanks.prefix(6)) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(item.category.name, systemImage: item.category.icon)
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
                    detail: "这部分会帮你快速看到金额最大的记录。"
                )
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

                                Text("\(entry.category.name) · \(LedgerFormatters.entryTime(for: entry.date))")
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
                        detail: "先添加储蓄卡、现金或负债账户，资产页会自动汇总。"
                    )
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
                MetricBlock(title: "资产", value: store.totalAssets, valueColor: Color.ledgerText, background: Color.white.opacity(0.45))
                MetricBlock(title: "负债", value: store.totalLiabilities, valueColor: Color.ledgerText, background: Color.white.opacity(0.45))
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.00, green: 0.96, blue: 0.80), Color(red: 1.00, green: 0.90, blue: 0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.ledgerGold.opacity(0.18), radius: 22, x: 0, y: 14)
        )
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
                                Text(account.name)
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
                        .background(.white)
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

                                Text("\(LedgerFormatters.bookDate(book.createdAt)) 创建 · \(store.bookEntryCount(book)) 笔记录")
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
                        .background(.white)
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

                    Text("\(store.bookEntryCount(store.currentBook)) 笔记录 · 本月收入 \(LedgerFormatters.currency(store.bookMonthlyIncome(store.currentBook)))")
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
                        colors: [Color.white, store.currentBook.tintStyle.color.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
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
                                SchemeMetric(title: "支出", value: "\(scheme.expenseCategories.count) 类", accent: .ledgerAccent)
                                SchemeMetric(title: "收入", value: "\(scheme.incomeCategories.count) 类", accent: .ledgerGold)
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

                                        Text(category.name)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color.ledgerMuted)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(20)
                        .background(.white)
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
                                    Text(kind.rawValue).tag(kind)
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

                                    Text(category.name)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.ledgerText)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .contextMenu {
                                    Button("删除分类", role: .destructive) {
                                        store.removeCategory(from: schemeID, categoryID: category.id, kind: selectedKind)
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
                                .background(.white)
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
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(selectedTemplate.group.affectsAssets ? "初始余额" : "当前欠款")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ledgerText)

                        TextField("0.00", text: $balanceText)
                            .keyboardType(.decimalPad)
                            .padding(18)
                            .background(.white)
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
                                                .fill(template.tintStyle.color.opacity(selectedTemplateID == template.id ? 0.22 : 0.12))
                                                .frame(width: 56, height: 56)
                                                .overlay {
                                                    Image(systemName: template.icon)
                                                        .font(.system(size: 22, weight: .semibold))
                                                        .foregroundStyle(template.tintStyle.color)
                                                }

                                            Text(template.name)
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundStyle(Color.ledgerText)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .fill(selectedTemplateID == template.id ? template.tintStyle.color.opacity(0.08) : Color.white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                        .stroke(selectedTemplateID == template.id ? template.tintStyle.color : Color.clear, lineWidth: 1.4)
                                                )
                                        )
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
                            store.updateAccount(account, template: selectedTemplate, customName: accountName, balance: balance)
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
                            .background(.white)
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
                                        .fill(Color.white)
                                        .frame(width: 54, height: 54)
                                        .overlay {
                                            Image(systemName: icon)
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(selectedTint.color)
                                        }
                                        .overlay {
                                            Circle()
                                                .stroke(selectedIcon == icon ? selectedTint.color : Color.clear, lineWidth: 2)
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
                                                .stroke(Color.white, lineWidth: 2)
                                                .padding(3)
                                        }
                                        .overlay {
                                            Circle()
                                                .stroke(selectedTint == tint ? Color.ledgerText : Color.clear, lineWidth: 2)
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
                            tintStyle: selectedTint
                        )
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
    var background: Color = Color.white.opacity(0.18)

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

struct SettingsView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var isDeleteAlertPresented = false
    @State private var isHelpPresented = false
    @State private var isAboutPresented = false

    private let monthStartDayOptions = Array(1...28)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
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
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isHelpPresented) {
            HelpFeedbackView()
        }
        .sheet(isPresented: $isAboutPresented) {
            AboutAppView()
        }
        .alert("确认删除历史账单？", isPresented: $isDeleteAlertPresented) {
            Button("删除", role: .destructive) {
                store.clearAllHistoryEntries()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("这会清空当前本地账单记录，但不会删除账本、账户和分类设置。")
        }
    }

    private var displaySettingsCard: some View {
        VStack(spacing: 0) {
            SettingSelectRow(
                title: "月统计起始日",
                value: store.appSettings.monthStartDayLabel
            ) {
                ForEach(monthStartDayOptions, id: \.self) { day in
                    Button("每月\(day)日") {
                        store.setMonthStartDay(day)
                    }
                }
            }

            Divider().padding(.leading, 18)

            SettingSelectRow(
                title: "助手回复风格",
                value: store.appSettings.assistantReplyStyle.title
            ) {
                ForEach(AssistantReplyStyle.allCases) { style in
                    Button(style.title) {
                        store.setAssistantReplyStyle(style)
                    }
                }
            }

            Divider().padding(.leading, 18)

            SettingToggleRow(
                title: "展示记录图片",
                subtitle: "用于自动记账回看截图",
                isOn: Binding(
                    get: { store.appSettings.showRecordImages },
                    set: { store.appSettings.showRecordImages = $0 }
                )
            )

            Divider().padding(.leading, 18)

            SettingToggleRow(
                title: "地点展示",
                subtitle: "允许在账单中展示地点字段",
                isOn: Binding(
                    get: { store.appSettings.showLocation },
                    set: { store.appSettings.showLocation = $0 }
                )
            )

            Divider().padding(.leading, 18)

            SettingToggleRow(
                title: "优惠推荐",
                subtitle: "控制首页推荐卡片展示",
                isOn: Binding(
                    get: { store.appSettings.showOfferRecommendations },
                    set: { store.appSettings.showOfferRecommendations = $0 }
                )
            )

            Divider().padding(.leading, 18)

            SettingToggleRow(
                title: "去敏展示",
                subtitle: "隐藏金额和支付方式",
                isOn: Binding(
                    get: { store.appSettings.hideSensitiveInfo },
                    set: { store.appSettings.hideSensitiveInfo = $0 }
                )
            )
        }
        .ledgerCard()
    }

    private var pushSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingToggleRow(
                title: "推送服务",
                subtitle: "总开关会联动下方提醒项",
                isOn: Binding(
                    get: { store.appSettings.pushEnabled },
                    set: { store.setPushEnabled($0) }
                )
            )
            .padding(.horizontal, 18)
            .padding(.top, 18)

            VStack(spacing: 0) {
                SettingCheckRow(
                    title: "每日记账",
                    isChecked: Binding(
                        get: { store.appSettings.pushDailyLedger },
                        set: { store.setPushSubItem(dailyLedger: $0) }
                    )
                )
                Divider().padding(.leading, 18)

                SettingCheckRow(
                    title: "预算提醒",
                    isChecked: Binding(
                        get: { store.appSettings.pushBudgetReminder },
                        set: { store.setPushSubItem(budgetReminder: $0) }
                    )
                )
                Divider().padding(.leading, 18)

                SettingCheckRow(
                    title: "功能推荐",
                    isChecked: Binding(
                        get: { store.appSettings.pushFeatureRecommendation },
                        set: { store.setPushSubItem(featureRecommendation: $0) }
                    )
                )
                Divider().padding(.leading, 18)

                SettingCheckRow(
                    title: "账单回顾",
                    isChecked: Binding(
                        get: { store.appSettings.pushBillReview },
                        set: { store.setPushSubItem(billReview: $0) }
                    )
                )
            }
            .background(Color.ledgerAccentMuted.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(12)
            .opacity(store.appSettings.pushEnabled ? 1 : 0.45)
            .disabled(!store.appSettings.pushEnabled)
        }
        .ledgerCard()
    }

    private var serviceCard: some View {
        VStack(spacing: 0) {
            SettingActionRow(title: "帮助与反馈") { isHelpPresented = true }
            Divider().padding(.leading, 18)
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
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                Spacer()
                Text("删除")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.red)
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .buttonStyle(.plain)
        .ledgerCard()
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
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.ledgerAccent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
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
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerText)
            Spacer()
            Menu {
                menuContent
            } label: {
                HStack(spacing: 6) {
                    Text(value)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.ledgerMuted)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
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
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                Spacer()
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(isChecked ? Color.ledgerAccent : Color.ledgerMuted.opacity(0.6))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
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
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.ledgerMuted)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .buttonStyle(.plain)
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
                        message: "1. 数据默认只保存在本机。\n2. 删除账单后无法恢复。\n3. 月统计起始日会影响预算与图表。"
                    )
                    infoCard(
                        title: "反馈方式",
                        message: "你可以把问题截图、复现步骤和系统版本整理后提交给产品团队。"
                    )
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
                    Text("本地记账")
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
