import SwiftUI

struct BudgetManagementView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var isMonthlyBudgetEditorPresented = false
    @State private var categoryBudgetDraft: CategoryBudgetDraft?
    @State private var isAIBudgetAlertPresented = false

    private let calendar = Calendar.current
    private let weekSymbols = ["一", "二", "三", "四", "五", "六", "日"]

    private var isSensitiveVisible: Bool {
        store.isBalanceVisible && !store.appSettings.hideSensitiveInfo
    }

    private var monthStartDate: Date {
        calendar.startOfDay(for: store.currentStatisticsMonthInterval.start)
    }

    private var monthEndDate: Date {
        calendar.date(byAdding: .day, value: -1, to: store.currentStatisticsMonthInterval.end) ?? monthStartDate
    }

    private var monthTitle: String {
        "本月（\(BudgetViewFormatters.rangeLabel(start: monthStartDate, end: monthEndDate))）"
    }

    private var calendarDays: [BudgetCalendarDay] {
        let dates = monthDates
        let totalsByDay = Dictionary(grouping: store.currentBookBudgetEntries.filter {
            $0.kind == .expense && store.currentStatisticsMonthInterval.contains($0.date)
        }, by: {
            calendar.startOfDay(for: $0.date)
        })
        .mapValues { dayEntries in
            dayEntries.reduce(0) { $0 + $1.amount }
        }

        var spentBeforeToday = 0.0

        return dates.enumerated().map { index, date in
            let dayStart = calendar.startOfDay(for: date)
            let dayExpense = totalsByDay[dayStart] ?? 0
            let remainingDays = max(dates.count - index, 1)
            let recommendedBudget = store.budgetLimit.map { limit in
                max(limit - spentBeforeToday, 0) / Double(remainingDays)
            }

            defer {
                spentBeforeToday += dayExpense
            }

            return BudgetCalendarDay(
                date: dayStart,
                recommendedBudget: recommendedBudget,
                expense: dayExpense)
        }
    }

    private var calendarSlots: [BudgetCalendarSlot] {
        let leadingBlankCount = (calendar.component(.weekday, from: monthStartDate) + 5) % 7
        let leadingSlots = (0..<leadingBlankCount).map { index in
            BudgetCalendarSlot(id: "blank-\(index)", day: nil)
        }

        let daySlots = calendarDays.map { day in
            BudgetCalendarSlot(id: BudgetViewFormatters.dayKey(for: day.date), day: day)
        }

        return leadingSlots + daySlots
    }

    private var monthDates: [Date] {
        var dates: [Date] = []
        var cursor = monthStartDate

        while cursor <= monthEndDate {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return dates
    }

    private var allExpenseCategories: [LedgerCategory] {
        store.allCategories(for: .expense)
    }

    private var addableCategories: [LedgerCategory] {
        let budgetedCategoryIDs = Set(store.currentBookCategoryBudgetSummaries.map(\.category.id))
        return allExpenseCategories.filter { !budgetedCategoryIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                summaryCard
                dynamicDailyBudgetSection
                categoryBudgetSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [Color.ledgerAccentSoft.opacity(0.32), Color.ledgerCanvas],
                startPoint: .top,
                endPoint: .bottom)
                .ignoresSafeArea())
        .navigationTitle("预算管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(store.books) { book in
                        Button(book.name) {
                            store.setCurrentBook(book)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(store.currentBook.name)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.ledgerAccentSoft.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .sheet(isPresented: $isMonthlyBudgetEditorPresented) {
            BudgetAmountEditorSheet(
                title: "设置月预算",
                subtitle: "\(store.currentBook.name) · 当前统计周期",
                initialAmount: store.budgetLimit,
                allowsRemoval: store.budgetLimit != nil,
                onSave: { amount in
                    store.setBudgetLimit(amount)
                })
                .presentationDetents([.height(320)])
        }
        .sheet(item: $categoryBudgetDraft) { draft in
            CategoryBudgetEditorSheet(
                draft: draft,
                categories: draft.isEditing ? [draft.category] : addableCategories,
                onSave: { categoryID, amount in
                    store.upsertCategoryBudget(categoryID: categoryID, monthlyLimit: amount)
                },
                onDelete: draft.isEditing ? {
                    if let budget = store.categoryBudget(for: draft.category.id) {
                        store.removeCategoryBudget(budget)
                    }
                } : nil)
                .presentationDetents([.height(360)])
        }
        .alert("AI 预算功能预留", isPresented: $isAIBudgetAlertPresented) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("入口和页面节奏已经预留好了，后续我们接入 AI 预算建议和智能分配时，可以直接沿用这里的结构。")
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(monthTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Text("预算围绕当前账本单独管理，切换账本后会看到对应预算。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button {
                    isAIBudgetAlertPresented = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                        Text("体验智能预算")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.ledgerLavender, Color.ledgerAccent],
                            startPoint: .leading,
                            endPoint: .trailing))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.ledgerLavender, Color.ledgerAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing),
                                lineWidth: 1.6))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("月预算")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)

                HStack(spacing: 12) {
                    Text(displayAmount(store.budgetLimit, fallback: "¥--"))
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ledgerText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Button {
                        isMonthlyBudgetEditorPresented = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.ledgerMuted)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if store.currentBudgetOverspent > 0 {
                        BudgetStatusBadge(
                            title: "已超支",
                            tint: .ledgerExpense)
                    } else if store.budgetLimit != nil {
                        BudgetStatusBadge(
                            title: "正常",
                            tint: .ledgerIncome)
                    }
                }
            }

            BudgetLinearProgressView(
                progress: store.budgetProgress,
                tint: store.currentBudgetOverspent > 0 ? .ledgerExpense : .ledgerAccent)
                .frame(height: 14)

            HStack {
                summaryMetric(
                    title: "已用",
                    value: displayAmount(store.currentMonthBudgetExpense, fallback: "¥--"))

                Spacer()

                summaryMetric(
                    title: "剩余",
                    value: displayAmount(store.currentBudgetRemaining, fallback: "¥--"))
            }

            Rectangle()
                .fill(Color.clear)
                .frame(height: 1)
                .overlay(
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.ledgerAccent.opacity(0.22)))

            HStack(alignment: .firstTextBaseline) {
                Text("今日可用预算")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)

                Spacer()

                Text(displayAmount(store.suggestedDailyBudget, fallback: "¥--"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if !isSensitiveVisible {
                Text("你已开启去敏展示，预算金额默认隐藏。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color.ledgerCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                .shadow(color: Color.ledgerAccent.opacity(0.08), radius: 24, x: 0, y: 14))
    }

    private var dynamicDailyBudgetSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("动态日预算")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Spacer()

                Text(store.budgetLimit == nil ? "添加月预算后将智能生成日预算" : "按剩余预算和剩余天数动态分配")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
                    .multilineTextAlignment(.trailing)
            }

            if store.budgetLimit == nil {
                PlaceholderBudgetCard(
                    icon: "calendar.badge.exclamationmark",
                    title: "先设置月预算",
                    detail: "设置好月预算后，这里会按当前账本自动生成每日建议预算，并结合已消费情况动态调整。")
            } else {
                VStack(spacing: 14) {
                    HStack {
                        ForEach(weekSymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ledgerMuted)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                        ForEach(calendarSlots) { slot in
                            if let day = slot.day {
                                calendarDayCard(day)
                            } else {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        BudgetLegendItem(color: Color.ledgerAccentSoft.opacity(0.95), text: "今天")
                        BudgetLegendItem(color: Color.ledgerAccentMuted.opacity(0.72), text: "已过日期")
                        BudgetLegendItem(color: .white, text: "未来日期")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
                .ledgerCard()
            }
        }
    }

    private var categoryBudgetSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("本月分类预算")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Spacer()

                Button {
                    presentCategoryBudgetComposer()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("添加")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerAccent)
                }
                .buttonStyle(.plain)
                .disabled(addableCategories.isEmpty)
                .opacity(addableCategories.isEmpty ? 0.4 : 1)
            }

            if store.currentBookCategoryBudgetSummaries.isEmpty {
                PlaceholderBudgetCard(
                    icon: "square.grid.2x2",
                    title: "还没有分类预算",
                    detail: "可以先给餐饮、交通、购物这些高频分类设置预算，页面会自动显示已用、剩余和超支状态。")
            } else {
                VStack(spacing: 12) {
                    ForEach(store.currentBookCategoryBudgetSummaries) { summary in
                        categoryBudgetCard(summary)
                    }
                }
            }
        }
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func calendarDayCard(_ day: BudgetCalendarDay) -> some View {
        let isToday = calendar.isDateInToday(day.date)
        let isPast = calendar.compare(day.date, to: Date(), toGranularity: .day) == .orderedAscending

        return VStack(alignment: .leading, spacing: 8) {
            Text(isToday ? "今" : "\(calendar.component(.day, from: day.date))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Text(mainValue(for: day, isToday: isToday, isPast: isPast))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isPast && !isToday ? Color.ledgerExpense : Color.ledgerAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(dayBackgroundColor(isToday: isToday, isPast: isPast)))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isToday ? Color.ledgerAccent.opacity(0.42) : Color.clear, lineWidth: 1.4))
    }

    private func categoryBudgetCard(_ summary: LedgerBudgetCategorySummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(summary.category.tint.opacity(0.16))
                        .frame(width: 46, height: 46)

                    Image(systemName: summary.category.icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(summary.category.tint)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(summary.category.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Text(
                        "\(displayAmount(summary.spent, fallback: "¥--")) / \(displayAmount(summary.budget.monthlyLimit, fallback: "¥--"))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    categoryBudgetDraft = CategoryBudgetDraft(
                        category: summary.category,
                        amountText: BudgetViewFormatters.editingAmount(summary.budget.monthlyLimit),
                        isEditing: true)
                } label: {
                    Text("调整")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.ledgerAccentSoft.opacity(0.72))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            BudgetLinearProgressView(
                progress: summary.progress,
                tint: summary.overspent > 0 ? .ledgerExpense : summary.category.tint)
                .frame(height: 12)

            HStack {
                Text(summary
                    .overspent > 0 ? "已超 \(displayAmount(summary.overspent, fallback: "¥--"))" :
                    "剩余 \(displayAmount(summary.remaining, fallback: "¥--"))")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(summary.overspent > 0 ? Color.ledgerExpense : Color.ledgerMuted)

                Spacer()

                Button(role: .destructive) {
                    store.removeCategoryBudget(summary.budget)
                } label: {
                    Label("删除", systemImage: "trash")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .ledgerCard()
    }

    private func displayAmount(_ value: Double?, fallback: String) -> String {
        guard let value else { return fallback }
        guard isSensitiveVisible else { return "¥••••" }
        return LedgerFormatters.currency(value)
    }

    private func mainValue(for day: BudgetCalendarDay, isToday: Bool, isPast: Bool) -> String {
        if isToday {
            return shortAmount(store.suggestedDailyBudget ?? day.recommendedBudget ?? 0)
        }

        if isPast {
            return day.expense > 0 ? "-\(shortAmount(day.expense))" : "¥0"
        }

        return shortAmount(day.recommendedBudget ?? 0)
    }

    private func dayBackgroundColor(isToday: Bool, isPast: Bool) -> Color {
        if isToday {
            return Color.ledgerAccentSoft.opacity(0.96)
        }

        if isPast {
            return Color.ledgerAccentMuted.opacity(0.68)
        }

        return .white
    }

    private func shortAmount(_ value: Double) -> String {
        guard isSensitiveVisible else { return "¥••••" }
        return BudgetViewFormatters.compactCurrency(value)
    }

    private func presentCategoryBudgetComposer() {
        guard let category = addableCategories.first ?? allExpenseCategories.first else { return }
        categoryBudgetDraft = CategoryBudgetDraft(
            category: category,
            amountText: "",
            isEditing: false)
    }
}

private struct BudgetCalendarDay {
    let date: Date
    let recommendedBudget: Double?
    let expense: Double
}

private struct BudgetCalendarSlot: Identifiable {
    let id: String
    let day: BudgetCalendarDay?
}

private struct CategoryBudgetDraft: Identifiable {
    let id = UUID()
    let category: LedgerCategory
    let amountText: String
    let isEditing: Bool
}

private struct PlaceholderBudgetCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.ledgerAccentSoft.opacity(0.72))
                    .frame(width: 58, height: 58)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.ledgerAccent)
            }

            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Text(detail)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .ledgerCard()
    }
}

private struct BudgetStatusBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct BudgetLegendItem: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.ledgerDivider, lineWidth: 0.8))

            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
        }
    }
}

private struct BudgetLinearProgressView: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.ledgerAccentMuted)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.65)],
                            startPoint: .leading,
                            endPoint: .trailing))
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
    }
}

private struct BudgetAmountEditorSheet: View {
    let title: String
    let subtitle: String
    let initialAmount: Double?
    let allowsRemoval: Bool
    let onSave: (Double?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String

    init(
        title: String,
        subtitle: String,
        initialAmount: Double?,
        allowsRemoval: Bool,
        onSave: @escaping (Double?) -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.initialAmount = initialAmount
        self.allowsRemoval = allowsRemoval
        self.onSave = onSave
        _amountText = State(initialValue: BudgetViewFormatters.editingAmount(initialAmount))
    }

    private var parsedAmount: Double? {
        BudgetViewFormatters.parseAmount(amountText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)

                VStack(alignment: .leading, spacing: 10) {
                    Text("预算金额")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    TextField("例如 3600", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.ledgerAccentMuted.opacity(0.68))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                Text("留空或清除可以移除当前账本的月预算。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)

                Spacer()

                HStack(spacing: 12) {
                    if allowsRemoval {
                        Button(role: .destructive) {
                            onSave(nil)
                            dismiss()
                        } label: {
                            Text("清除预算")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        onSave(parsedAmount)
                        dismiss()
                    } label: {
                        Text("保存")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ledgerAccent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!amountText.trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty && parsedAmount == nil)
                    .opacity(!amountText.trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty && parsedAmount == nil ? 0.5 : 1)
                }
            }
            .padding(22)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct CategoryBudgetEditorSheet: View {
    let draft: CategoryBudgetDraft
    let categories: [LedgerCategory]
    let onSave: (String, Double) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategoryID: String
    @State private var amountText: String

    init(
        draft: CategoryBudgetDraft,
        categories: [LedgerCategory],
        onSave: @escaping (String, Double) -> Void,
        onDelete: (() -> Void)? = nil) {
        self.draft = draft
        self.categories = categories
        self.onSave = onSave
        self.onDelete = onDelete
        _selectedCategoryID = State(initialValue: draft.category.id)
        _amountText = State(initialValue: draft.amountText)
    }

    private var parsedAmount: Double? {
        BudgetViewFormatters.parseAmount(amountText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                if draft.isEditing {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("预算分类")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ledgerText)

                        categoryPill(draft.category)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("预算分类")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ledgerText)

                        Picker("分类", selection: $selectedCategoryID) {
                            ForEach(categories) { category in
                                Text(category.name).tag(category.id)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("预算金额")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    TextField("例如 600", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.ledgerAccentMuted.opacity(0.68))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                Spacer()

                HStack(spacing: 12) {
                    if let onDelete {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("删除")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        guard let parsedAmount else { return }
                        onSave(selectedCategoryID, parsedAmount)
                        dismiss()
                    } label: {
                        Text(draft.isEditing ? "保存调整" : "添加预算")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ledgerAccent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(parsedAmount == nil)
                    .opacity(parsedAmount == nil ? 0.5 : 1)
                }
            }
            .padding(22)
            .navigationTitle(draft.isEditing ? "调整分类预算" : "新增分类预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func categoryPill(_ category: LedgerCategory) -> some View {
        HStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(category.tint)

            Text(category.name)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ledgerText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(category.tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private enum BudgetViewFormatters {
    private static let locale = Locale(identifier: "zh_Hans_CN")

    private static let rangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M.d"
        return formatter
    }()

    private static let compactFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static func rangeLabel(start: Date, end: Date) -> String {
        "\(rangeFormatter.string(from: start))-\(rangeFormatter.string(from: end))"
    }

    static func compactCurrency(_ value: Double) -> String {
        compactFormatter.string(from: NSNumber(value: value)) ?? "¥0"
    }

    static func editingAmount(_ value: Double?) -> String {
        guard let value else { return "" }
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }

    static func parseAmount(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    static func dayKey(for date: Date) -> String {
        String(Int(date.timeIntervalSince1970))
    }
}
