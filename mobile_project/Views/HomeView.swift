import SwiftUI

struct HomeView: View {
    private enum HomePrimaryTab: String {
        case ledger = "记账"
        case calendar = "日历"
    }

    @EnvironmentObject private var store: LedgerStore

    @State private var isDrawerPresented = false
    @State private var activeHomeTab: HomePrimaryTab = .ledger
    @State private var activeScreen: ManagementScreen?
    @State private var highlightedFeature: String?

    private var isSensitiveInfoVisible: Bool {
        store.isBalanceVisible && !store.appSettings.hideSensitiveInfo
    }

    private var selectedDrawerDestination: DrawerDestination? {
        guard let activeScreen else { return nil }
        return .screen(activeScreen)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color.ledgerCanvas
                    .ignoresSafeArea()

                mainContent
                    .blur(radius: isDrawerPresented ? 3 : 0)
                    .overlay {
                        if isDrawerPresented {
                            Color.black.opacity(0.10)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    closeDrawer()
                                }
                        }
                    }

                if isDrawerPresented {
                    DrawerMenuView(
                        width: min(proxy.size.width * 0.72, 300),
                        topSafeInset: proxy.safeAreaInsets.top,
                        selectedDestination: selectedDrawerDestination,
                        onShortcutTap: handleDrawerDestination(_:),
                        onClose: {
                            closeDrawer()
                        }
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.9), value: isDrawerPresented)
        }
        .sheet(isPresented: $store.isQuickAddPresented) {
            QuickAddSheet(store: store)
        }
        .sheet(item: $activeScreen) { screen in
            ManagementSheetView(screen: screen)
                .environmentObject(store)
        }
        .alert("功能预留", isPresented: featureAlertBinding) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("\(highlightedFeature ?? "这个入口") 先保留了结构和入口，后续我们可以继续把它做成完整功能。")
        }
        .onOpenURL(perform: handleWidgetDeepLink(_:))
    }

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                topBar
                if activeHomeTab == .ledger {
                    summaryCard
                    todayHeader
                    if store.appSettings.showOfferRecommendations {
                        assistantCard
                    }
                    autoLedgerCard
                    transactionsCard
                } else {
                    calendarOverviewPage
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 128)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            quickEntryDock
        }
    }

    private var daysInCurrentMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
    }

    private var calendarOverviewPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(LedgerFormatters.drawerMonthTitle(for: Date()))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Spacer()

                    Text("独立日历")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.ledgerAccentMuted.opacity(0.75))
                        .clipShape(Capsule())
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(1...daysInCurrentMonth, id: \.self) { day in
                        let isToday = day == Calendar.current.component(.day, from: Date())
                        let hasRecord = store.monthRecordedDays.contains(day)

                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(hasRecord ? Color.ledgerAccentSoft : Color.ledgerCanvas)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(isToday ? Color.ledgerAccent : Color.clear, lineWidth: 2)
                                )

                            Text(isToday ? "今" : "\(day)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(hasRecord || isToday ? Color.ledgerAccent : Color.ledgerMuted.opacity(0.8))
                        }
                        .frame(height: 46)
                    }
                }

                HStack {
                    CalendarStatItem(value: "\(store.totalRecordDays)天", title: "坚持记录")
                    Spacer()
                    CalendarStatItem(value: "\(store.totalRecords)条", title: "总记录")
                    Spacer()
                    CalendarStatItem(value: "\(store.currentStreak)天", title: "连续记录")
                }
            }
            .padding(16)
            .ledgerCard()

            VStack(alignment: .leading, spacing: 10) {
                Text("今天建议")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                Text("把本月预算回顾、周期账单和提醒统一放到这个日历页，日常记账页保持更专注。")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .ledgerCard()
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                openDrawer()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.ledgerMuted)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.75))
                    .clipShape(Circle())
            }

            homeTabSwitcher

            Spacer()

            CapsuleIconButton(icon: "book.closed.fill", title: store.currentBook.name) {
                openScreen(.books)
            }
        }
    }

    private var homeTabSwitcher: some View {
        HStack(spacing: 6) {
            homeTabItem(.ledger, icon: "wallet.pass")
            homeTabItem(.calendar, icon: "calendar")
        }
        .padding(4)
        .background(.white.opacity(0.86))
        .clipShape(Capsule())
    }

    private func homeTabItem(_ tab: HomePrimaryTab, icon: String) -> some View {
        let isActive = activeHomeTab == tab
        return Button {
            guard activeHomeTab != tab else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                activeHomeTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isActive ? Color.ledgerText : Color.ledgerMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color.ledgerAccentSoft.opacity(0.95) : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 10) {
                    Text("统计周期支出")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)

                    Button {
                        guard !store.appSettings.hideSensitiveInfo else { return }
                        withAnimation(.easeInOut(duration: 0.18)) {
                            store.isBalanceVisible.toggle()
                        }
                    } label: {
                        Image(systemName: store.appSettings.hideSensitiveInfo ? "lock.fill" : (store.isBalanceVisible ? "eye.fill" : "eye.slash.fill"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.ledgerAccent)
                    }
                    .disabled(store.appSettings.hideSensitiveInfo)
                }

                Spacer()

                Button {
                    openScreen(.statistics)
                } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.pie.fill")
                            Text("统计")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(Color.ledgerText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.ledgerAccentSoft.opacity(0.85))
                        .clipShape(Capsule())
                    }
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.ledgerAccentSoft, lineWidth: 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)

                Text(isSensitiveInfoVisible ? LedgerFormatters.currency(store.currentMonthExpense) : "¥••••")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 18)
            }

            HStack(spacing: 12) {
                SummaryNumber(title: "收入", value: store.currentMonthIncome, isVisible: isSensitiveInfoVisible)
                SummaryNumber(title: "结余", value: store.currentMonthBalance, isVisible: isSensitiveInfoVisible)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 18) {
                    budgetDetails
                    BudgetRingView(
                        progress: store.budgetProgress,
                        budgetLimit: store.budgetLimit,
                        isSensitiveVisible: isSensitiveInfoVisible
                    )
                        .frame(width: 100, height: 100)
                }

                VStack(alignment: .leading, spacing: 18) {
                    budgetDetails
                    HStack {
                        Spacer()
                        BudgetRingView(
                            progress: store.budgetProgress,
                            budgetLimit: store.budgetLimit,
                            isSensitiveVisible: isSensitiveInfoVisible
                        )
                            .frame(width: 108, height: 108)
                        Spacer()
                    }
                }
            }
        }
        .padding(18)
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
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Spacer()

            Button {
                store.isQuickAddPresented = true
            } label: {
                Image(systemName: "banknote")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ledgerAccent)
                    .frame(width: 38, height: 38)
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
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("一句话快速记账")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Text("试试输入“今天午饭 15 元，用电子支付”")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text(store.assistantCardHint)
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerAccent)
                }

                Spacer(minLength: 12)

                ZStack {
                    Circle()
                        .fill(Color.ledgerAccentSoft.opacity(0.65))
                        .frame(width: 66, height: 66)

                    Image(systemName: "message.and.waveform.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.ledgerAccent)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ledgerCard()
        }
        .buttonStyle(.plain)
    }

    private var autoLedgerCard: some View {
        Button {
            openScreen(.autoLedgerCenter)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("自动记账中心")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Text(store.appSettings.showRecordImages ? "截图识别 -> AI 结构化 -> 人工确认后入账" : "截图识别 -> AI 结构化（图片仅用于解析，不回显）")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text(store.appSettings.showLocation ? "支持快捷指令触发，审核时展示地点字段" : "支持快捷指令触发与审核保存")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerAccent)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.ledgerAccentSoft.opacity(0.72))
                        .frame(width: 70, height: 70)

                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.ledgerAccent)
                }
            }
            .padding(18)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("今日流水")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Spacer()

                if !store.todayEntries.isEmpty {
                    Text("\(store.todayEntries.count) 笔")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
            }

            if store.todayEntries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("今天还没有记录")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Text("先点底部输入条或上方快捷卡片，录入第一笔本地账单。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.ledgerAccentMuted.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    ForEach(store.todayEntries) { entry in
                        TransactionRow(entry: entry, isSensitiveVisible: isSensitiveInfoVisible)
                    }
                }
            }
        }
        .padding(18)
        .ledgerCard()
    }

    private var quickEntryDock: some View {
        HStack(spacing: 12) {
            if activeHomeTab == .ledger {
                Button {
                    handleDrawerDestination(.placeholder("搜索"))
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.ledgerText)
                        .frame(width: 50, height: 50)
                        .background(.white.opacity(0.96))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
                }
            }

            Button {
                store.isQuickAddPresented = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.ledgerText)

                    Text(activeHomeTab == .ledger ? "记一笔" : "新建日程")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Text(activeHomeTab == .ledger ? "金额、分类、备注" : "添加今天计划")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "waveform")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.ledgerAccent)
                }
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(.white.opacity(0.96))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
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

    private func handleDrawerDestination(_ destination: DrawerDestination) {
        switch destination {
        case .screen(let screen):
            openScreen(screen)
        case .placeholder(let feature):
            highlightedFeature = feature
        }
    }

    private var budgetDescription: String {
        guard let budgetLimit = store.budgetLimit else {
            return "还没设置预算，数据默认只保存在本机。"
        }

        if !isSensitiveInfoVisible {
            return "去敏展示已开启，预算金额默认隐藏。"
        }

        let remaining = max(0, budgetLimit - store.currentMonthExpense)
        return "本统计周期预算 \(LedgerFormatters.currency(budgetLimit))，剩余 \(LedgerFormatters.currency(remaining))。"
    }

    private func openDrawer() {
        guard !isDrawerPresented else { return }
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.9)) {
            isDrawerPresented = true
        }
    }

    private func closeDrawer() {
        guard isDrawerPresented else { return }
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.92)) {
            isDrawerPresented = false
        }
    }

    private func openScreen(_ screen: ManagementScreen) {
        if isDrawerPresented {
            closeDrawer()
        }
        activeHomeTab = .ledger
        activeScreen = screen
    }

    private func handleWidgetDeepLink(_ url: URL) {
        guard url.scheme == LedgerWidgetShared.deepLinkScheme else { return }

        let action = url.host ?? url.pathComponents.dropFirst().first ?? ""

        switch action {
        case "quick-add":
            activeHomeTab = .ledger
            store.isQuickAddPresented = true
        case "statistics":
            openScreen(.statistics)
        case "assets":
            openScreen(.assets)
        case "books":
            openScreen(.books)
        case "categories":
            openScreen(.categories)
        case "auto-ledger":
            openScreen(.autoLedgerCenter)
        case "widgets":
            openScreen(.widgets)
        default:
            break
        }
    }
}

private struct CalendarStatItem: View {
    let value: String
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
        }
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
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .lineLimit(1)
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
    let isSensitiveVisible: Bool

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

                    Text(isSensitiveVisible ? LedgerFormatters.currency(budgetLimit) : "¥••••")
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
    let isSensitiveVisible: Bool

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

                Text("\(isSensitiveVisible ? entry.paymentMethod : "支付方式已隐藏") · \(LedgerFormatters.entryTime(for: entry.date))")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            Spacer()

            Text(
                isSensitiveVisible
                    ? (entry.kind == .expense ? "-\(LedgerFormatters.currency(entry.amount))" : "+\(LedgerFormatters.currency(entry.amount))")
                    : (entry.kind == .expense ? "-¥••••" : "+¥••••")
            )
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(entry.kind == .expense ? Color.ledgerExpense : Color.ledgerIncome)
        }
        .padding(14)
        .background(Color.ledgerAccentMuted.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
