import PhotosUI
import SwiftUI

struct HomeView: View {
    private enum HomePrimaryTab: String {
        case ledger = "记账"
        case calendar = "日历"
    }

    @EnvironmentObject private var store: LedgerStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var isDrawerPresented = false
    @State private var activeHomeTab: HomePrimaryTab = .ledger
    @State private var activeScreen: ManagementScreen?
    @State private var selectedEntry: LedgerEntry?
    @State private var highlightedFeature: String?
    @State private var pendingInteractionTask: Task<Void, Never>?

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
                    .scaleEffect(isDrawerPresented ? 0.992 : 1, anchor: .center)
                    .opacity(isDrawerPresented ? 0.985 : 1)
                    .allowsHitTesting(!isDrawerPresented)

                if isDrawerPresented {
                    Button {
                        closeDrawer()
                    } label: {
                        Color.black.opacity(0.10)
                            .ignoresSafeArea()
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }

                if isDrawerPresented {
                    DrawerMenuView(
                        width: min(proxy.size.width * 0.72, 300),
                        topSafeInset: proxy.safeAreaInsets.top,
                        selectedDestination: selectedDrawerDestination,
                        onShortcutTap: handleDrawerDestination(_:),
                        onClose: {
                            closeDrawer()
                        })
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.92), value: isDrawerPresented)
        }
        .sheet(isPresented: $store.isQuickAddPresented) {
            QuickAddSheet(store: store)
        }
        .sheet(item: $activeScreen) { screen in
            ManagementSheetView(screen: screen)
                .environmentObject(store)
        }
        .sheet(item: $selectedEntry) { entry in
            LedgerEntryDetailSheet(store: store, entry: entry)
        }
        .alert("功能预留", isPresented: featureAlertBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("\(highlightedFeature ?? "这个入口") 先保留了结构和入口，后续我们可以继续把它做成完整功能。")
        }
        .onOpenURL(perform: handleWidgetDeepLink(_:))
        .onAppear(perform: openPendingAutoLedgerIfNeeded)
        .onAppear {
            handleEntryNavigation(store.entryNavigationRequest)
        }
        .onChange(of: store.autoLedgerPendingLaunch) { _, _ in
            openPendingAutoLedgerIfNeeded()
        }
        .onChange(of: store.entryNavigationRequest) { _, request in
            handleEntryNavigation(request)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            store.refreshAutoLedgerShortcutState()
            openPendingAutoLedgerIfNeeded()
            handleEntryNavigation(store.entryNavigationRequest)
        }
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
                        Button {
                            openHistoryForDay(day)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(hasRecord ? Color.ledgerAccentSoft : Color.ledgerCanvas)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(isToday ? Color.ledgerAccent : Color.clear, lineWidth: 2))

                                Text(isToday ? "今" : "\(day)")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(hasRecord || isToday ? Color.ledgerAccent : Color.ledgerMuted
                                        .opacity(0.8))
                            }
                            .frame(height: 46)
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasRecord)
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
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.75))
                    .clipShape(Circle())
            }
            .buttonStyle(LedgerResponsiveButtonStyle())

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
        .buttonStyle(LedgerResponsiveButtonStyle())
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
                        Image(systemName: store.appSettings
                            .hideSensitiveInfo ? "lock.fill" : (store.isBalanceVisible ? "eye.fill" : "eye.slash.fill"))
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
                .buttonStyle(LedgerResponsiveButtonStyle())
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
                        isSensitiveVisible: isSensitiveInfoVisible)
                        .frame(width: 100, height: 100)
                }

                VStack(alignment: .leading, spacing: 18) {
                    budgetDetails
                    HStack {
                        Spacer()
                        BudgetRingView(
                            progress: store.budgetProgress,
                            budgetLimit: store.budgetLimit,
                            isSensitiveVisible: isSensitiveInfoVisible)
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
                        endPoint: .bottomTrailing))
                .shadow(color: Color.ledgerAccent.opacity(0.08), radius: 20, x: 0, y: 14))
    }

    private var todayHeader: some View {
        HStack(alignment: .center) {
            Text(LedgerFormatters.todayHeadline(for: Date()))
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Spacer()

            Button {
                openQuickAddSheet()
            } label: {
                Image(systemName: "banknote")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ledgerAccent)
                    .frame(width: 38, height: 38)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(LedgerResponsiveButtonStyle())
        }
    }

    private var assistantCard: some View {
        Button {
            openQuickAddSheet()
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
        .buttonStyle(LedgerResponsiveButtonStyle())
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

                    Text(store.appSettings
                        .showRecordImages ? "截图识别 -> 大模型解析 -> 自动入账" : "截图识别 -> 大模型解析（图片仅用于解析，不回显）")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text(store.appSettings.showLocation ? "支持快捷指令触发，自动入账后保留地点能力" : "支持快捷指令触发与自动入账")
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
        .buttonStyle(LedgerResponsiveButtonStyle())
    }

    private var budgetDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("月预算")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Spacer()

                Button {
                    openScreen(.budget)
                } label: {
                    HStack(spacing: 6) {
                        Text(store.budgetLimit == nil ? "去设置" : "去管理")
                        Image(systemName: "square.and.pencil")
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
                }
                .buttonStyle(LedgerResponsiveButtonStyle())
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
                    Button {
                        store.clearHistoryPresentation()
                        openScreen(.history)
                    } label: {
                        Text("全部记录")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ledgerAccent)
                    }
                    .buttonStyle(LedgerResponsiveButtonStyle())

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
                        Button {
                            selectedEntry = entry
                        } label: {
                            TransactionRow(entry: entry, isSensitiveVisible: isSensitiveInfoVisible)
                        }
                        .buttonStyle(.plain)
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
                    presentPlaceholderFeature("搜索")
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.ledgerText)
                        .frame(width: 50, height: 50)
                        .background(.white.opacity(0.96))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(LedgerResponsiveButtonStyle())
            }

            Button {
                openQuickAddSheet()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.ledgerText)

                    Text("记一笔")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Text("金额、分类、备注")
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
            .buttonStyle(LedgerResponsiveButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.0), Color.white.opacity(0.68), Color.white],
                startPoint: .top,
                endPoint: .bottom)
                .ignoresSafeArea())
    }

    private var featureAlertBinding: Binding<Bool> {
        Binding(
            get: { highlightedFeature != nil },
            set: { newValue in
                if !newValue {
                    highlightedFeature = nil
                }
            })
    }

    private func handleDrawerDestination(_ destination: DrawerDestination) {
        switch destination {
        case .screen(let screen):
            openScreen(screen)
        case .placeholder(let feature):
            presentPlaceholderFeature(feature)
        }
    }

    private var budgetDescription: String {
        guard let budgetLimit = store.budgetLimit else {
            return "还没设置预算，数据默认只保存在本机。"
        }

        if !isSensitiveInfoVisible {
            return "去敏展示已开启，预算金额默认隐藏。"
        }

        let remaining = max(0, budgetLimit - store.currentMonthBudgetExpense)
        return "本统计周期预算 \(LedgerFormatters.currency(budgetLimit))，剩余 \(LedgerFormatters.currency(remaining))。"
    }

    private func openDrawer() {
        guard !isDrawerPresented else { return }
        pendingInteractionTask?.cancel()
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
        runAfterInteractiveTransition {
            activeHomeTab = .ledger

            guard activeScreen != screen else { return }

            if activeScreen == nil {
                activeScreen = screen
            } else {
                activeScreen = nil
                DispatchQueue.main.async {
                    activeScreen = screen
                }
            }
        }
    }

    private func openQuickAddSheet() {
        runAfterInteractiveTransition {
            activeHomeTab = .ledger
            guard !store.isQuickAddPresented else { return }
            store.isQuickAddPresented = true
        }
    }

    private func presentPlaceholderFeature(_ feature: String) {
        runAfterInteractiveTransition {
            highlightedFeature = feature
        }
    }

    private func runAfterInteractiveTransition(_ action: @escaping @MainActor () -> Void) {
        pendingInteractionTask?.cancel()
        pendingInteractionTask = Task { @MainActor in
            if isDrawerPresented {
                closeDrawer()
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !Task.isCancelled else { return }
            }

            action()
        }
    }

    private func handleWidgetDeepLink(_ url: URL) {
        guard url.scheme == LedgerWidgetShared.deepLinkScheme else { return }

        let action = url.host ?? url.pathComponents.dropFirst().first ?? ""

        switch action {
        case "quick-add":
            openQuickAddSheet()
        case "statistics":
            openScreen(.statistics)
        case "budget":
            openScreen(.budget)
        case "assets":
            openScreen(.assets)
        case "books":
            openScreen(.books)
        case "categories":
            openScreen(.categories)
        case "auto-ledger":
            openScreen(.autoLedgerCenter)
        case "auto-ledger-review":
            store.refreshAutoLedgerShortcutState()
            openScreen(.autoLedgerCenter)
        case "widgets":
            openScreen(.widgets)
        default:
            break
        }
    }

    private func openPendingAutoLedgerIfNeeded() {
        guard store.hasPendingAutoLedgerLaunch else { return }
        openScreen(.autoLedgerCenter)
    }

    private func handleEntryNavigation(_ request: LedgerNavigationRequest?) {
        guard let request else { return }

        runAfterInteractiveTransition {
            switch request.destination {
            case .detail(let entryID):
                activeHomeTab = .ledger
                activeScreen = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    selectedEntry = store.entry(withID: entryID)
                    store.clearEntryNavigationRequest()
                }

            case .history(let presentation):
                if presentation.filteredDate == nil {
                    activeHomeTab = .ledger
                }
                selectedEntry = nil

                if activeScreen == nil {
                    activeScreen = .history
                } else {
                    activeScreen = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        activeScreen = .history
                        store.clearEntryNavigationRequest()
                    }
                    return
                }

                store.clearEntryNavigationRequest()
            }
        }
    }

    private func openHistoryForDay(_ day: Int) {
        var components = Calendar.current.dateComponents([.year, .month], from: Date())
        components.day = day

        guard let date = Calendar.current.date(from: components)
        else {
            return
        }

        store.presentHistory(
            scope: .currentBook,
            filteredDate: date,
            title: LedgerFormatters.historyTitle(for: date))
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
        .buttonStyle(LedgerResponsiveButtonStyle())
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
                .stroke(
                    Color.ledgerAccentSoft.opacity(0.85),
                    style: StrokeStyle(lineWidth: 14, dash: budgetLimit == nil ? [8, 6] : []))

            if budgetLimit != nil {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.ledgerAccent, .ledgerMint, .ledgerGold],
                            center: .center),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))
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
                            endPoint: .trailing))
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 14)
    }
}

struct TransactionRow: View {
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

                Text(
                    "\(isSensitiveVisible ? entry.paymentMethod : "支付方式已隐藏") · \(LedgerFormatters.entryTime(for: entry.date))")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            Spacer()

            Text(
                isSensitiveVisible
                    ?
                    (entry
                        .kind == .expense ? "-\(LedgerFormatters.currency(entry.amount))" :
                        "+\(LedgerFormatters.currency(entry.amount))")
                    : (entry.kind == .expense ? "-¥••••" : "+¥••••"))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(entry.kind == .expense ? Color.ledgerExpense : Color.ledgerIncome)
        }
        .padding(14)
        .background(Color.ledgerAccentMuted.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct LedgerEntryDetailSheet: View {
    @ObservedObject var store: LedgerStore
    let entry: LedgerEntry

    @Environment(\.dismiss) private var dismiss
    @State private var activeEditor: LedgerEntryDetailEditor?
    @State private var isDeleteConfirmationPresented = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    private var latestEntry: LedgerEntry {
        store.entry(withID: entry.id) ?? entry
    }

    private var latestBook: LedgerBook? {
        store.book(withID: latestEntry.bookID)
    }

    private var latestAccountName: String {
        store.resolvedPaymentAccountName(for: latestEntry)
    }

    private var screenshotImage: UIImage? {
        guard let imageData = latestEntry.screenshotData else { return nil }
        return UIImage(data: imageData)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    amountHero
                    primaryInfoCard
                    accountAndRulesCard
                    contentCard
                    screenshotCard
                }
                .padding(20)
                .padding(.bottom, 120)
            }
            .background(Color.ledgerCanvas)
            .navigationTitle("记录详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                    .foregroundStyle(Color.ledgerMuted)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                deleteBar
            }
        }
        .sheet(item: $activeEditor) { editor in
            editorSheet(editor)
        }
        .confirmationDialog("删除这条记录？", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                store.deleteEntry(id: latestEntry.id)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后不会进入回收站，这条记录会从首页、历史列表、预算和统计里一起移除。")
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        store.updateEntryScreenshot(latestEntry.id, data: data)
                    }
                }
            }
        }
        .onChange(of: store.entries.map(\.id)) { _, ids in
            guard ids.contains(entry.id) else {
                dismiss()
                return
            }
        }
    }

    private var amountHero: some View {
        Button {
            activeEditor = .amount
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("实付金额")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)

                    Text(latestEntry
                        .kind == .expense ? "-\(LedgerFormatters.currency(latestEntry.amount))" : LedgerFormatters
                        .currency(latestEntry.amount))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(latestEntry.kind == .expense ? Color.ledgerExpense : Color.ledgerIncome)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.ledgerMuted)
                    .padding(.top, 6)
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color.ledgerCard],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)))
        }
        .buttonStyle(.plain)
    }

    private var primaryInfoCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "账单日期", value: LedgerFormatters.shortTimestamp(latestEntry.date)) {
                activeEditor = .date
            }

            Divider().padding(.leading, 54)

            detailRow(label: "所属账本", value: latestBook?.name ?? "当前账本") {
                activeEditor = .book
            }

            Divider().padding(.leading, 54)

            detailRow(label: "类型", value: latestEntry.kind.rawValue) {
                activeEditor = .kind
            }

            Divider().padding(.leading, 54)

            detailRow(label: "分类", value: latestEntry.category.name, valueColor: latestEntry.category.tint) {
                activeEditor = .category
            }
        }
        .padding(.vertical, 6)
        .ledgerCard()
    }

    private var accountAndRulesCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "付款账户", value: latestAccountName) {
                activeEditor = .account
            }

            Divider().padding(.leading, 54)

            toggleRow(
                label: "不计收支",
                isOn: Binding(
                    get: { latestEntry.isExcludedFromStatistics },
                    set: { newValue in
                        store.updateEntry(latestEntry.id) { entry in
                            entry.isExcludedFromStatistics = newValue
                            if newValue {
                                entry.isExcludedFromBudget = true
                            }
                        }
                    }))

            Divider().padding(.leading, 54)

            toggleRow(
                label: "不计预算",
                isOn: Binding(
                    get: { latestEntry.isExcludedFromBudget },
                    set: { newValue in
                        store.updateEntry(latestEntry.id) { entry in
                            entry.isExcludedFromBudget = entry.isExcludedFromStatistics ? true : newValue
                        }
                    }),
                disabled: latestEntry.isExcludedFromStatistics)
        }
        .padding(.vertical, 6)
        .ledgerCard()
    }

    private var contentCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "交易方", value: latestEntry.title) {
                activeEditor = .title
            }

            Divider().padding(.leading, 54)

            detailRow(
                label: "标签",
                value: latestEntry.tags.isEmpty ? "添加" : latestEntry.tags.joined(separator: " · "),
                valueColor: latestEntry.tags.isEmpty ? Color.ledgerMuted : Color.ledgerText) {
                    activeEditor = .tags
                }

            Divider().padding(.leading, 54)

            detailRow(
                label: "备注",
                value: latestEntry.note.isEmpty ? "添加" : latestEntry.note,
                valueColor: latestEntry.note.isEmpty ? Color.ledgerMuted : Color.ledgerText) {
                    activeEditor = .note
                }
        }
        .padding(.vertical, 6)
        .ledgerCard()
    }

    private var screenshotCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("截图附件", systemImage: "photo.on.rectangle")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Spacer()

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Text(screenshotImage == nil ? "添加" : "替换")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerAccent)
                }
                .buttonStyle(.plain)
            }

            if let screenshotImage {
                Image(uiImage: screenshotImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Button("删除截图", role: .destructive) {
                    store.updateEntryScreenshot(latestEntry.id, data: nil)
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
            } else {
                Text(store.appSettings.showRecordImages
                    ? "这条记录还没有截图。你可以在这里手动补图，自动入账也会按设置决定是否保存截图。"
                    : "自动入账当前不保留截图，但你仍然可以在详情页手动补一张。")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ledgerAccentMuted.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .padding(20)
        .ledgerCard()
    }

    private var deleteBar: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                isDeleteConfirmationPresented = true
            } label: {
                Text("删除")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white)
            }
            .buttonStyle(.plain)
        }
    }

    private func detailRow(
        label: String,
        value: String,
        valueColor: Color = Color.ledgerText,
        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
                    .frame(width: 84, alignment: .leading)

                Spacer(minLength: 8)

                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.ledgerMuted.opacity(0.8))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(label: String, isOn: Binding<Bool>, disabled: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .frame(width: 84, alignment: .leading)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.ledgerAccent)
                .disabled(disabled)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .opacity(disabled ? 0.55 : 1)
    }

    @ViewBuilder
    private func editorSheet(_ editor: LedgerEntryDetailEditor) -> some View {
        switch editor {
        case .amount:
            LedgerAmountEditorSheet(initialAmount: latestEntry.amount) { amount in
                store.updateEntry(latestEntry.id) { entry in
                    entry.amount = amount
                }
            }
        case .date:
            LedgerDateEditorSheet(initialDate: latestEntry.date) { date in
                store.updateEntry(latestEntry.id) { entry in
                    entry.date = date
                }
            }
        case .book:
            LedgerBookPickerSheet(store: store, selectedBookID: latestEntry.bookID) { bookID in
                store.updateEntry(latestEntry.id) { entry in
                    entry.bookID = bookID
                }
            }
        case .account:
            LedgerAccountPickerSheet(
                store: store,
                selectedAccountID: latestEntry.accountID,
                fallbackPaymentMethod: latestEntry.paymentMethod) { accountID, paymentMethod in
                    store.updateEntry(latestEntry.id) { entry in
                        entry.accountID = accountID
                        entry.paymentMethod = paymentMethod
                    }
                }
        case .kind:
            LedgerKindPickerSheet(initialKind: latestEntry.kind) { kind in
                store.updateEntry(latestEntry.id) { entry in
                    entry.kind = kind
                    if entry.category.kind != kind {
                        entry.category = store.categories(for: kind).first ?? LedgerCategory.defaultCategory(for: kind)
                    }
                }
            }
        case .category:
            LedgerCategoryPickerSheet(
                categories: store.categories(for: latestEntry.kind),
                selectedCategoryID: latestEntry.category.id) { category in
                    store.updateEntry(latestEntry.id) { entry in
                        entry.category = category
                    }
                }
        case .title:
            LedgerTextEditorSheet(
                title: "交易方",
                placeholder: "例如 KFC Hong Kong",
                initialText: latestEntry.title,
                axis: .vertical) { text in
                    store.updateEntry(latestEntry.id) { entry in
                        entry.title = text
                    }
                }
        case .tags:
            LedgerTagsEditorSheet(
                initialTags: latestEntry.tags,
                suggestions: store.recentTags) { tags in
                    store.updateEntry(latestEntry.id) { entry in
                        entry.tags = tags
                    }
                }
        case .note:
            LedgerTextEditorSheet(
                title: "备注",
                placeholder: "补充说明、汇率、订单信息等",
                initialText: latestEntry.note,
                axis: .vertical) { text in
                    store.updateEntry(latestEntry.id) { entry in
                        entry.note = text
                    }
                }
        }
    }
}

private enum LedgerEntryDetailEditor: String, Identifiable {
    case amount
    case date
    case book
    case account
    case kind
    case category
    case title
    case tags
    case note

    var id: String { rawValue }
}

private struct LedgerAmountEditorSheet: View {
    let initialAmount: Double
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String

    init(initialAmount: Double, onSave: @escaping (Double) -> Void) {
        self.initialAmount = initialAmount
        self.onSave = onSave
        _amountText = State(initialValue: String(format: "%.2f", initialAmount))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("实付金额")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let normalized = amountText.replacingOccurrences(of: ",", with: "")
                        if let amount = Double(normalized), amount > 0 {
                            onSave(amount)
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

private struct LedgerDateEditorSheet: View {
    let initialDate: Date
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(initialDate: Date, onSave: @escaping (Date) -> Void) {
        self.initialDate = initialDate
        self.onSave = onSave
        _date = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("账单日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }
            .navigationTitle("账单日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave(date)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

private struct LedgerBookPickerSheet: View {
    @ObservedObject var store: LedgerStore
    let selectedBookID: UUID
    let onSave: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftBookID: UUID

    init(store: LedgerStore, selectedBookID: UUID, onSave: @escaping (UUID) -> Void) {
        self.store = store
        self.selectedBookID = selectedBookID
        self.onSave = onSave
        _draftBookID = State(initialValue: selectedBookID)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.books) { book in
                    Button {
                        draftBookID = book.id
                    } label: {
                        HStack {
                            Text(book.name)
                            Spacer()
                            if draftBookID == book.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("所属账本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave(draftBookID)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

private struct LedgerAccountPickerSheet: View {
    @ObservedObject var store: LedgerStore
    let selectedAccountID: UUID?
    let fallbackPaymentMethod: String
    let onSave: (UUID?, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftAccountID: UUID?
    @State private var paymentMethodText: String

    init(
        store: LedgerStore,
        selectedAccountID: UUID?,
        fallbackPaymentMethod: String,
        onSave: @escaping (UUID?, String) -> Void) {
        self.store = store
        self.selectedAccountID = selectedAccountID
        self.fallbackPaymentMethod = fallbackPaymentMethod
        self.onSave = onSave
        _draftAccountID = State(initialValue: selectedAccountID)
        _paymentMethodText = State(initialValue: fallbackPaymentMethod)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("账户列表") {
                    Button {
                        draftAccountID = nil
                    } label: {
                        HStack {
                            Text("仅保留文本")
                            Spacer()
                            if draftAccountID == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(store.paymentAccounts) { account in
                        Button {
                            draftAccountID = account.id
                            paymentMethodText = account.name
                        } label: {
                            HStack {
                                Text(account.name)
                                Spacer()
                                if draftAccountID == account.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("显示文本") {
                    TextField("例如：微信余额", text: $paymentMethodText)
                }
            }
            .navigationTitle("付款账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let finalText = paymentMethodText.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(draftAccountID, finalText.isEmpty ? "待确认" : finalText)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

private struct LedgerKindPickerSheet: View {
    let initialKind: LedgerKind
    let onSave: (LedgerKind) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: LedgerKind

    init(initialKind: LedgerKind, onSave: @escaping (LedgerKind) -> Void) {
        self.initialKind = initialKind
        self.onSave = onSave
        _kind = State(initialValue: initialKind)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("类型", selection: $kind) {
                    ForEach(LedgerKind.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle("类型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave(kind)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

private struct LedgerCategoryPickerSheet: View {
    let categories: [LedgerCategory]
    let selectedCategoryID: String
    let onSave: (LedgerCategory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftCategoryID: String

    init(categories: [LedgerCategory], selectedCategoryID: String, onSave: @escaping (LedgerCategory) -> Void) {
        self.categories = categories
        self.selectedCategoryID = selectedCategoryID
        self.onSave = onSave
        _draftCategoryID = State(initialValue: selectedCategoryID)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Button {
                        draftCategoryID = category.id
                    } label: {
                        HStack {
                            Label(category.name, systemImage: category.icon)
                                .foregroundStyle(category.tint, Color.ledgerText)
                            Spacer()
                            if draftCategoryID == category.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let selected = categories.first(where: { $0.id == draftCategoryID }) ?? categories
                            .first ?? LedgerCategory.defaultCategory(for: .expense)
                        onSave(selected)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

private struct LedgerTextEditorSheet: View {
    let title: String
    let placeholder: String
    let initialText: String
    let axis: Axis
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(
        title: String,
        placeholder: String,
        initialText: String,
        axis: Axis,
        onSave: @escaping (String) -> Void) {
        self.title = title
        self.placeholder = placeholder
        self.initialText = initialText
        self.axis = axis
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(placeholder, text: $text, axis: axis)
                    .lineLimit(axis == .vertical ? 4...8 : 1...1)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

private struct LedgerTagsEditorSheet: View {
    let initialTags: [String]
    let suggestions: [String]
    let onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var input: String

    init(initialTags: [String], suggestions: [String], onSave: @escaping ([String]) -> Void) {
        self.initialTags = initialTags
        self.suggestions = suggestions
        self.onSave = onSave
        _input = State(initialValue: initialTags.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("例如：出差, 港币, 便利店", text: $input, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("最近标签")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ledgerMuted)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                                ForEach(suggestions.prefix(12), id: \.self) { tag in
                                    Button(tag) {
                                        let existing = parsedTags
                                        if !existing.contains(tag) {
                                            let updated = existing + [tag]
                                            input = updated.joined(separator: ", ")
                                        }
                                    }
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.ledgerAccent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.ledgerAccentSoft.opacity(0.6))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.ledgerCanvas)
            .navigationTitle("标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave(parsedTags)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private var parsedTags: [String] {
        var seen = Set<String>()
        return input
            .components(separatedBy: CharacterSet(charactersIn: ",，|、"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }
}
