import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var isDrawerPresented = false
    @State private var highlightedFeature: String?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color.ledgerCanvas
                    .ignoresSafeArea()

                mainContent
                    .blur(radius: isDrawerPresented ? 5 : 0)
                    .overlay {
                        if isDrawerPresented {
                            Color.black.opacity(0.18)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                        isDrawerPresented = false
                                    }
                                }
                        }
                    }

                if isDrawerPresented {
                    DrawerMenuView(
                        width: min(proxy.size.width * 0.86, 360),
                        recordedDays: store.monthRecordedDays,
                        totalRecordDays: store.totalRecordDays,
                        totalRecords: store.totalRecords,
                        streak: store.currentStreak,
                        onShortcutTap: presentPlaceholderFeature(_:),
                        onClose: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                isDrawerPresented = false
                            }
                        }
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(1)
                }
            }
        }
        .sheet(isPresented: $store.isQuickAddPresented) {
            QuickAddSheet(store: store)
        }
        .alert("功能预留", isPresented: featureAlertBinding) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("\(highlightedFeature ?? "这个入口") 先保留了结构和入口，后续我们可以继续把它做成完整功能。")
        }
    }

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                topBar
                summaryCard
                todayHeader
                assistantCard
                transactionsCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 128)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            quickEntryDock
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                    isDrawerPresented = true
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.ledgerMuted)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.75))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("记账")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                    .overlay(alignment: .bottomLeading) {
                        Capsule()
                            .fill(Color.ledgerAccent)
                            .frame(width: 66, height: 4)
                            .offset(y: 8)
                    }

                Text("本地速记")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            Spacer()

            CapsuleIconButton(icon: "calendar", title: "本月") {
                presentPlaceholderFeature("月份切换")
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 10) {
                    Text("\(LedgerFormatters.monthTitle(for: Date()))支出")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)

                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            store.isBalanceVisible.toggle()
                        }
                    } label: {
                        Image(systemName: store.isBalanceVisible ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.ledgerAccent)
                    }
                }

                Spacer()

                Button {
                    presentPlaceholderFeature("统计")
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.pie.fill")
                        Text("统计")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.ledgerText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.ledgerAccentSoft.opacity(0.85))
                    .clipShape(Capsule())
                }
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.ledgerAccentSoft, lineWidth: 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)

                Text(store.isBalanceVisible ? LedgerFormatters.currency(store.currentMonthExpense) : "¥••••")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 22)
            }

            HStack(spacing: 12) {
                SummaryNumber(title: "收入", value: store.currentMonthIncome, isVisible: store.isBalanceVisible)
                SummaryNumber(title: "结余", value: store.currentMonthBalance, isVisible: store.isBalanceVisible)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 18) {
                    budgetDetails
                    BudgetRingView(progress: store.budgetProgress, budgetLimit: store.budgetLimit)
                        .frame(width: 110, height: 110)
                }

                VStack(alignment: .leading, spacing: 18) {
                    budgetDetails
                    HStack {
                        Spacer()
                        BudgetRingView(progress: store.budgetProgress, budgetLimit: store.budgetLimit)
                            .frame(width: 118, height: 118)
                        Spacer()
                    }
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color.ledgerCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.ledgerAccent.opacity(0.08), radius: 20, x: 0, y: 14)
        )
    }

    private var todayHeader: some View {
        HStack(alignment: .center) {
            Text(LedgerFormatters.todayHeadline(for: Date()))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Spacer()

            Button {
                store.isQuickAddPresented = true
            } label: {
                Image(systemName: "banknote")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.ledgerAccent)
                    .frame(width: 42, height: 42)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
            }
        }
    }

    private var assistantCard: some View {
        Button {
            store.isQuickAddPresented = true
        } label: {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("一句话快速记账")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Text("试试输入“今天午饭 15 元，用支付宝支付”")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("先用本地表单录入，后面再扩展智能识别")
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerAccent)
                }

                Spacer(minLength: 12)

                ZStack {
                    Circle()
                        .fill(Color.ledgerAccentSoft.opacity(0.65))
                        .frame(width: 80, height: 80)

                    Image(systemName: "message.and.waveform.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.ledgerAccent)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ledgerCard()
        }
        .buttonStyle(.plain)
    }

    private var budgetDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("月预算")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        store.setStarterBudgetIfNeeded()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(store.budgetLimit == nil ? "设置" : "调整")
                        Image(systemName: "square.and.pencil")
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
                }
            }

            BudgetProgressBar(progress: store.budgetProgress)

            Text(budgetDescription)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var transactionsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("今日流水")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Spacer()

                if !store.todayEntries.isEmpty {
                    Text("\(store.todayEntries.count) 笔")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
            }

            if store.todayEntries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("今天还没有记录")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Text("先点底部输入条或上方快捷卡片，录入第一笔本地账单。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color.ledgerAccentMuted.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    ForEach(store.todayEntries) { entry in
                        TransactionRow(entry: entry)
                    }
                }
            }
        }
        .padding(22)
        .ledgerCard()
    }

    private var quickEntryDock: some View {
        HStack(spacing: 12) {
            Button {
                presentPlaceholderFeature("搜索")
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.ledgerText)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.96))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
            }

            Button {
                store.isQuickAddPresented = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.ledgerText)

                    Text("记一笔")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Text("金额、分类、备注")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "waveform")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.ledgerAccent)
                }
                .padding(.horizontal, 20)
                .frame(height: 60)
                .background(.white.opacity(0.96))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.0), Color.white.opacity(0.68), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var featureAlertBinding: Binding<Bool> {
        Binding(
            get: { highlightedFeature != nil },
            set: { newValue in
                if !newValue {
                    highlightedFeature = nil
                }
            }
        )
    }

    private func presentPlaceholderFeature(_ feature: String) {
        highlightedFeature = feature
    }

    private var budgetDescription: String {
        guard let budgetLimit = store.budgetLimit else {
            return "还没设置预算，数据默认只保存在本机。"
        }

        let remaining = max(0, budgetLimit - store.currentMonthExpense)
        return "本月预算 \(LedgerFormatters.currency(budgetLimit))，剩余 \(LedgerFormatters.currency(remaining))。"
    }
}

private struct CapsuleIconButton: View {
    let icon: String
    let title: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                if let title {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Color.ledgerText)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(.white.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SummaryNumber: View {
    let title: String
    let value: Double
    let isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)

            Text(isVisible ? LedgerFormatters.currency(value) : "¥••••")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BudgetRingView: View {
    let progress: Double
    let budgetLimit: Double?

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.ledgerAccentSoft.opacity(0.85), style: StrokeStyle(lineWidth: 14, dash: budgetLimit == nil ? [8, 6] : []))

            if budgetLimit != nil {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.ledgerAccent, .ledgerMint, .ledgerGold],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 6) {
                if let budgetLimit {
                    Text("预算")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)

                    Text(LedgerFormatters.currency(budgetLimit))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)
                } else {
                    Text("暂未设置预算")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(width: 130, height: 130)
    }
}

private struct BudgetProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.ledgerAccentMuted)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.ledgerAccent, .ledgerMint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 14)
    }
}

private struct TransactionRow: View {
    let entry: LedgerEntry

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(entry.category.tint.opacity(0.16))
                    .frame(width: 48, height: 48)

                Image(systemName: entry.category.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(entry.category.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Text("\(entry.paymentMethod) · \(LedgerFormatters.entryTime(for: entry.date))")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            Spacer()

            Text(entry.kind == .expense ? "-\(LedgerFormatters.currency(entry.amount))" : "+\(LedgerFormatters.currency(entry.amount))")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(entry.kind == .expense ? Color.ledgerExpense : Color.ledgerIncome)
        }
        .padding(14)
        .background(Color.ledgerAccentMuted.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
