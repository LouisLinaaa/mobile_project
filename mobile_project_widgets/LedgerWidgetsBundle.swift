import SwiftUI
import WidgetKit

private enum LedgerWidgetKind {
    static let todayExpense = "com.github.louislinaa.ledgerlab.widget.today-expense"
    static let budgetProgress = "com.github.louislinaa.ledgerlab.widget.budget-progress"
    static let quickAction = "com.github.louislinaa.ledgerlab.widget.quick-action"
    static let accountOverview = "com.github.louislinaa.ledgerlab.widget.account-overview"
    static let autoLedgerStatus = "com.github.louislinaa.ledgerlab.widget.auto-ledger-status"
}

private enum WidgetShared {
    static let defaultAppGroupID = "group.com.github.louislinaa.ledgerlab"
    static let appGroupID: String = {
        guard let configured = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String,
              !configured.isEmpty,
              !configured.contains("$(") else {
            return defaultAppGroupID
        }
        return configured
    }()
    static let snapshotDefaultsKey = "ledger.widget.snapshot.v1"
    static let deepLinkScheme = "ledgerapp"
}

private struct LedgerWidgetCategorySnapshot: Codable, Identifiable {
    let id: String
    let name: String
    let amount: Double
    let tintHex: String
}

private struct LedgerWidgetSnapshot: Codable {
    let generatedAt: Date
    let todayExpenseTotal: Double
    let todayExpenseItems: [LedgerWidgetCategorySnapshot]
    let budgetLimit: Double?
    let currentMonthExpense: Double
    let budgetProgress: Double
    let totalAssets: Double
    let totalLiabilities: Double
    let netWorth: Double
    let autoLedgerPendingCount: Int
    let autoLedgerPostedCount: Int
    let autoLedgerFailedCount: Int
    let autoLedgerUpdatedAt: Date

    static let fallback = LedgerWidgetSnapshot(
        generatedAt: Date(),
        todayExpenseTotal: 0,
        todayExpenseItems: [],
        budgetLimit: nil,
        currentMonthExpense: 0,
        budgetProgress: 0,
        totalAssets: 0,
        totalLiabilities: 0,
        netWorth: 0,
        autoLedgerPendingCount: 1,
        autoLedgerPostedCount: 0,
        autoLedgerFailedCount: 0,
        autoLedgerUpdatedAt: Date())
}

private enum LedgerWidgetStore {
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func load() -> LedgerWidgetSnapshot {
        let defaults = UserDefaults(suiteName: WidgetShared.appGroupID) ?? .standard
        guard let data = defaults.data(forKey: WidgetShared.snapshotDefaultsKey),
              let snapshot = try? decoder.decode(LedgerWidgetSnapshot.self, from: data) else {
            return .fallback
        }
        return snapshot
    }
}

private struct LedgerWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: LedgerWidgetSnapshot
}

private struct LedgerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LedgerWidgetEntry {
        LedgerWidgetEntry(date: Date(), snapshot: .fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (LedgerWidgetEntry) -> Void) {
        completion(LedgerWidgetEntry(date: Date(), snapshot: LedgerWidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LedgerWidgetEntry>) -> Void) {
        let now = Date()
        let entry = LedgerWidgetEntry(date: now, snapshot: LedgerWidgetStore.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now
            .addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

@main
struct LedgerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayExpenseWidget()
        BudgetProgressWidget()
        QuickActionWidget()
        AccountOverviewWidget()
        AutoLedgerStatusWidget()
    }
}

struct TodayExpenseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LedgerWidgetKind.todayExpense, provider: LedgerTimelineProvider()) { entry in
            TodayExpenseWidgetView(entry: entry)
        }
        .configurationDisplayName("今日消费")
        .description("快速查看今天支出和主要分类。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct TodayExpenseWidgetView: View {
    let entry: LedgerWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("今日消费", systemImage: "banknote")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.widgetAccent)
                Spacer()
                Text("更新于 \(WidgetFormatters.time(entry.snapshot.generatedAt))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.widgetMuted)
            }

            Text(WidgetFormatters.currency(entry.snapshot.todayExpenseTotal))
                .font(.system(size: family == .systemLarge ? 34 : 30, weight: .black, design: .rounded))
                .foregroundStyle(Color.widgetText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            VStack(alignment: .leading, spacing: 7) {
                if entry.snapshot.todayExpenseItems.isEmpty {
                    Text("今天还没有支出记录")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.widgetMuted)
                } else {
                    ForEach(entry.snapshot.todayExpenseItems.prefix(family == .systemLarge ? 4 : 3)) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: item.tintHex))
                                .frame(width: 7, height: 7)
                            Text(item.name.localized)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.widgetMuted)
                                .lineLimit(1)
                            Spacer()
                            Text(WidgetFormatters.currency(item.amount))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.widgetText)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .containerBackground(for: .widget) {
            WidgetBackground()
        }
        .widgetURL(deepLink("quick-add"))
    }
}

struct BudgetProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LedgerWidgetKind.budgetProgress, provider: LedgerTimelineProvider()) { entry in
            BudgetProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("月预算")
        .description("查看预算使用进度和本月支出。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct BudgetProgressWidgetView: View {
    let entry: LedgerWidgetEntry

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.widgetAccentSoft, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(0.06, entry.snapshot.budgetProgress))
                    .stroke(Color.widgetIncome, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(entry.snapshot.budgetProgress * 100))%")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.widgetText)
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 7) {
                Label("月预算", systemImage: "chart.pie.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.widgetAccent)

                Text("预算 \(WidgetFormatters.currency(entry.snapshot.budgetLimit ?? 0))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.widgetText)
                    .lineLimit(1)

                Text("已用 \(WidgetFormatters.currency(entry.snapshot.currentMonthExpense))")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.widgetMuted)
                    .lineLimit(1)

                Text((entry.snapshot.budgetLimit ?? 0) > 0 ? "控制节奏，避免超支。" : "点进 App 设置预算。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.widgetMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .containerBackground(for: .widget) {
            WidgetBackground()
        }
        .widgetURL(deepLink("statistics"))
    }
}

struct QuickActionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LedgerWidgetKind.quickAction, provider: LedgerTimelineProvider()) { _ in
            QuickActionWidgetView()
        }
        .configurationDisplayName("快捷入口")
        .description("一键进入记账、统计、资产和自动记账。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct QuickActionWidgetView: View {
    @Environment(\.widgetFamily) private var family

    private var actions: [(title: String, icon: String, action: String)] {
        [
            ("记一笔", "plus.circle.fill", "quick-add"),
            ("图表", "chart.pie.fill", "statistics"),
            ("资产", "creditcard.fill", "assets"),
            ("自动记账", "doc.text.viewfinder", "auto-ledger")
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("快捷入口", systemImage: "square.grid.2x2")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.widgetAccent)

            if family == .systemSmall {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(actions, id: \.action) { item in
                        ActionChip(title: item.title, icon: item.icon, url: deepLink(item.action))
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(actions, id: \.action) { item in
                        ActionChip(title: item.title, icon: item.icon, url: deepLink(item.action))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            WidgetBackground()
        }
    }
}

private struct ActionChip: View {
    let title: String
    let icon: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(title.localized)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(Color.widgetText)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct AccountOverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LedgerWidgetKind.accountOverview, provider: LedgerTimelineProvider()) { entry in
            AccountOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("账户总览")
        .description("查看资产、负债和净资产变化。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct AccountOverviewWidgetView: View {
    let entry: LedgerWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("账户总览", systemImage: "creditcard.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.widgetAccent)

            Text("净资产 \(WidgetFormatters.currency(entry.snapshot.netWorth))")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Color.widgetText)
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            HStack(spacing: 8) {
                MetricCard(title: "资产", value: entry.snapshot.totalAssets, color: .widgetIncome)
                MetricCard(title: "负债", value: entry.snapshot.totalLiabilities, color: .widgetExpense)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .containerBackground(for: .widget) {
            WidgetBackground()
        }
        .widgetURL(deepLink("assets"))
    }
}

private struct MetricCard: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.localized)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.widgetMuted)
            Text(WidgetFormatters.currency(value))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

struct AutoLedgerStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LedgerWidgetKind.autoLedgerStatus, provider: LedgerTimelineProvider()) { entry in
            AutoLedgerStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("自动记账")
        .description("查看自动识别处理状态。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct AutoLedgerStatusWidgetView: View {
    let entry: LedgerWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("自动记账处理", systemImage: "bolt.horizontal.circle.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.widgetAccent)

            HStack(spacing: 6) {
                statusTag("待审核 \(entry.snapshot.autoLedgerPendingCount)", color: .widgetGold)
                statusTag("已入账 \(entry.snapshot.autoLedgerPostedCount)", color: .widgetIncome)
                if family != .systemSmall {
                    statusTag("失败 \(entry.snapshot.autoLedgerFailedCount)", color: .widgetMuted)
                }
            }

            Text("最近更新 \(WidgetFormatters.time(entry.snapshot.autoLedgerUpdatedAt))")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.widgetMuted)
                .lineLimit(1)

            if family == .systemLarge {
                Text("点进自动记账中心可继续审核并确认入账。")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.widgetMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(15)
        .containerBackground(for: .widget) {
            WidgetBackground()
        }
        .widgetURL(deepLink("auto-ledger"))
    }

    private func statusTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.74))
            .clipShape(Capsule())
    }
}

private struct WidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.white, Color.widgetAccentSoft.opacity(0.45)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
    }
}

private enum WidgetFormatters {
    private static let locale = Locale(identifier: "zh_Hans_CN")

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = locale
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func currency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "¥0.00"
    }

    static func time(_ value: Date) -> String {
        timeFormatter.string(from: value)
    }
}

private extension Color {
    static let widgetText = Color(red: 0.12, green: 0.14, blue: 0.18)
    static let widgetMuted = Color(red: 0.48, green: 0.52, blue: 0.60)
    static let widgetAccent = Color(red: 0.31, green: 0.51, blue: 0.98)
    static let widgetAccentSoft = Color(red: 0.85, green: 0.90, blue: 1.00)
    static let widgetIncome = Color(red: 0.29, green: 0.68, blue: 0.52)
    static let widgetExpense = Color(red: 0.96, green: 0.48, blue: 0.38)
    static let widgetGold = Color(red: 0.96, green: 0.76, blue: 0.35)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

private func deepLink(_ action: String) -> URL {
    URL(string: "\(WidgetShared.deepLinkScheme)://\(action)")!
}
