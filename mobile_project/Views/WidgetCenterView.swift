import SwiftUI

private enum WidgetTemplateKind: String, CaseIterable, Identifiable {
    case todayExpense = "今日消费"
    case budgetProgress = "月预算"
    case quickAction = "快捷入口"
    case accountOverview = "账户总览"
    case autoLedgerStatus = "自动记账"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .todayExpense:
            return "快速查看今天花了多少钱"
        case .budgetProgress:
            return "跟踪预算使用进度"
        case .quickAction:
            return "一键进入常用功能"
        case .accountOverview:
            return "掌握资产与负债变化"
        case .autoLedgerStatus:
            return "查看自动识别处理状态"
        }
    }

    var supportedSizes: String {
        switch self {
        case .todayExpense, .budgetProgress, .accountOverview:
            return "中/大号"
        case .quickAction:
            return "小/中号"
        case .autoLedgerStatus:
            return "小/中/大号"
        }
    }

    var accent: Color {
        switch self {
        case .todayExpense:
            return .ledgerAccent
        case .budgetProgress:
            return .ledgerIncome
        case .quickAction:
            return .ledgerGold
        case .accountOverview:
            return .ledgerMint
        case .autoLedgerStatus:
            return .ledgerLavender
        }
    }

    var icon: String {
        switch self {
        case .todayExpense:
            return "banknote"
        case .budgetProgress:
            return "chart.pie.fill"
        case .quickAction:
            return "square.grid.2x2"
        case .accountOverview:
            return "creditcard.fill"
        case .autoLedgerStatus:
            return "doc.text.viewfinder"
        }
    }
}

private enum WidgetEntryTarget: Hashable {
    case statistics
    case assets
    case books
    case categories
    case autoLedger
}

struct WidgetCenterView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var selectedTemplate: WidgetTemplateKind = .todayExpense
    @State private var isQuickAddPresented = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                widgetCarousel
                templateList
                entrySection
                setupGuide
                faqSection
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(Color.ledgerCanvas.ignoresSafeArea())
        .navigationTitle("桌面小组件")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isQuickAddPresented) {
            QuickAddSheet(store: store)
        }
        .navigationDestination(for: WidgetEntryTarget.self) { target in
            switch target {
            case .statistics:
                StatisticsView()
            case .assets:
                AssetManagementView()
            case .books:
                BookManagementView()
            case .categories:
                CategoryManagementView()
            case .autoLedger:
                AutoLedgerCenterView()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("常见小组件")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Text("提供消费速览、预算追踪、快捷入口等高频组件，支持不同尺寸。")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var widgetCarousel: some View {
        TabView(selection: $selectedTemplate) {
            ForEach(WidgetTemplateKind.allCases) { kind in
                widgetCard(kind: kind)
                    .tag(kind)
                    .padding(.horizontal, 4)
            }
        }
        .frame(height: 220)
        .tabViewStyle(.page(indexDisplayMode: .automatic))
    }

    private func widgetCard(kind: WidgetTemplateKind) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(kind.rawValue, systemImage: kind.icon)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(kind.accent)
                Spacer()
                Text(kind.supportedSizes)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.8))
                    .clipShape(Capsule())
            }

            switch kind {
            case .todayExpense:
                todayExpensePreview
            case .budgetProgress:
                budgetProgressPreview
            case .quickAction:
                quickActionPreview
            case .accountOverview:
                accountOverviewPreview
            case .autoLedgerStatus:
                autoLedgerPreview
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, kind.accent.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                .shadow(color: kind.accent.opacity(0.18), radius: 16, x: 0, y: 10))
    }

    private var todayExpensePreview: some View {
        let expenseEntries = store.todayStatisticEntries.filter { $0.kind == .expense }
        let todayExpenseTotal = expenseEntries.reduce(0) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: 10) {
            Text("¥\(String(format: "%.2f", todayExpenseTotal))")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(expenseEntries.prefix(3)) { entry in
                    HStack {
                        Circle().fill(entry.category.tint).frame(width: 6, height: 6)
                        Text(entry.category.name)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ledgerMuted)
                        Spacer()
                        Text(LedgerFormatters.currency(entry.amount))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ledgerText)
                    }
                }

                if expenseEntries.isEmpty {
                    Text("今天还没有支出记录")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
            }
        }
    }

    private var budgetProgressPreview: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.ledgerAccentSoft, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(0.08, store.budgetProgress))
                    .stroke(Color.ledgerIncome, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(store.budgetProgress * 100))%")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 8) {
                Text("本月预算")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                Text(LedgerFormatters.currency(store.budgetLimit ?? 0))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ledgerIncome)
                Text("已使用 \(LedgerFormatters.currency(store.currentMonthBudgetExpense))")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }
            Spacer()
        }
    }

    private var quickActionPreview: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                quickPill("记一笔", icon: "plus.circle.fill")
                quickPill("图表", icon: "chart.pie.fill")
                quickPill("自动记账", icon: "doc.text.viewfinder")
            }
            HStack(spacing: 10) {
                quickPill("资产", icon: "creditcard.fill")
                quickPill("账本", icon: "book.closed.fill")
                quickPill("分类", icon: "square.grid.3x1.folder.fill.badge.plus")
            }
        }
    }

    private func quickPill(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .foregroundStyle(Color.ledgerText)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.85))
        .clipShape(Capsule())
    }

    private var accountOverviewPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("净资产 \(LedgerFormatters.currency(store.netWorth))")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            HStack(spacing: 12) {
                metricPill(title: "资产", value: store.totalAssets, color: .ledgerIncome)
                metricPill(title: "负债", value: store.totalLiabilities, color: .ledgerExpense)
            }
        }
    }

    private func metricPill(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
            Text(LedgerFormatters.currency(value))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var autoLedgerPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("自动记账处理", systemImage: "bolt.horizontal.circle.fill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerAccent)

            HStack {
                statusChip("待审核 1", color: .ledgerGold)
                statusChip("已入账 6", color: .ledgerIncome)
                statusChip("失败 0", color: .ledgerMuted)
            }

            Text("最近一次：18:20 识别完成，等待确认")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
        }
    }

    private func statusChip(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.86))
            .clipShape(Capsule())
    }

    private var templateList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("模板清单")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            ForEach(WidgetTemplateKind.allCases) { kind in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTemplate = kind
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(kind.accent.opacity(0.18))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: kind.icon)
                                    .foregroundStyle(kind.accent)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.rawValue)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ledgerText)
                            Text(kind.subtitle)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ledgerMuted)
                        }

                        Spacer()

                        Text(kind.supportedSizes)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ledgerMuted)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selectedTemplate == kind ? kind.accent.opacity(0.14) : Color.white))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .ledgerCard()
    }

    private var entrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("小组件功能入口")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                Button {
                    isQuickAddPresented = true
                } label: {
                    entryCard(title: "快速记一笔", icon: "plus.circle.fill", subtitle: "立即录入")
                }
                .buttonStyle(.plain)

                NavigationLink(value: WidgetEntryTarget.statistics) {
                    entryCard(title: "图表统计", icon: "chart.pie.fill", subtitle: "收支趋势")
                }
                .buttonStyle(.plain)

                NavigationLink(value: WidgetEntryTarget.assets) {
                    entryCard(title: "资产管理", icon: "creditcard.fill", subtitle: "余额概览")
                }
                .buttonStyle(.plain)

                NavigationLink(value: WidgetEntryTarget.books) {
                    entryCard(title: "账本管理", icon: "book.closed.fill", subtitle: "切换账本")
                }
                .buttonStyle(.plain)

                NavigationLink(value: WidgetEntryTarget.categories) {
                    entryCard(title: "分类管理", icon: "square.grid.3x1.folder.fill.badge.plus", subtitle: "维护分类")
                }
                .buttonStyle(.plain)

                NavigationLink(value: WidgetEntryTarget.autoLedger) {
                    entryCard(title: "自动记账", icon: "doc.text.viewfinder", subtitle: "识别审核")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .ledgerCard()
    }

    private func entryCard(title: String, icon: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.ledgerAccent)
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(12)
        .background(Color.ledgerAccentSoft.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var setupGuide: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("如何添加桌面小组件")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            guideStep(index: 1, text: "返回主屏幕后长按空白区域，进入编辑模式。")
            guideStep(index: 2, text: "点击左上角“编辑”并选择“添加小组件”。")
            guideStep(index: 3, text: "在小组件列表中搜索“本地记账”。")
            guideStep(index: 4, text: "选择你喜欢的尺寸后添加并拖动到合适位置。")
        }
        .padding(20)
        .ledgerCard()
    }

    private func guideStep(index: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("STEP \(index)")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.ledgerAccent)
                .clipShape(Capsule())

            Text(text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("常见问题")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            faqItem(question: "为什么找不到桌面小组件？", answer: "请确认系统版本与桌面编辑权限，并在小组件列表中搜索“本地记账”。")
            faqItem(question: "小组件多久刷新一次？", answer: "默认按系统节电策略刷新；手动打开 App 后会立即同步最新数据。")
            faqItem(question: "小组件展示的是实时金额吗？", answer: "展示的是最近同步快照，确保稳定和省电。进入 App 后可查看完整实时明细。")
        }
        .padding(20)
        .ledgerCard()
    }

    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(question)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Text(answer)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.ledgerAccentSoft.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
