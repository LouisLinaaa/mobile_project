import SwiftUI

extension Color {
    static let ledgerCanvas = Color(red: 0.98, green: 0.98, blue: 0.99)
    static let ledgerCard = Color(red: 0.95, green: 0.97, blue: 1.00)
    static let ledgerAccent = Color(red: 0.31, green: 0.51, blue: 0.98)
    static let ledgerAccentSoft = Color(red: 0.85, green: 0.90, blue: 1.00)
    static let ledgerAccentMuted = Color(red: 0.92, green: 0.95, blue: 1.00)
    static let ledgerText = Color(red: 0.12, green: 0.14, blue: 0.18)
    static let ledgerMuted = Color(red: 0.48, green: 0.52, blue: 0.60)
    static let ledgerDivider = Color(red: 0.90, green: 0.92, blue: 0.96)
    static let ledgerExpense = Color(red: 0.96, green: 0.48, blue: 0.38)
    static let ledgerIncome = Color(red: 0.29, green: 0.68, blue: 0.52)
    static let ledgerGold = Color(red: 0.96, green: 0.76, blue: 0.35)
    static let ledgerMint = Color(red: 0.46, green: 0.79, blue: 0.76)
    static let ledgerLavender = Color(red: 0.67, green: 0.63, blue: 0.97)
    static let ledgerCoral = Color(red: 0.95, green: 0.63, blue: 0.58)
}

struct LedgerCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 10))
    }
}

struct LedgerResponsiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct LedgerToolbarBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.ledgerText)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.92))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(LedgerResponsiveButtonStyle())
    }
}

extension View {
    func ledgerCard() -> some View {
        modifier(LedgerCardModifier())
    }

    func ledgerTapTarget(minSize: CGFloat = 44, alignment: Alignment = .center) -> some View {
        frame(minWidth: minSize, minHeight: minSize, alignment: alignment)
            .contentShape(Rectangle())
    }
}

enum LedgerFormatters {
    static let locale = Locale.autoupdatingCurrent

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

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()

    private static let monthDrawerFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let bookDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMdd")
        return formatter
    }()

    private static let historyTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MdEEEE")
        return formatter
    }()

    static func currency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "¥0.00"
    }

    static func monthTitle(for date: Date) -> String {
        monthFormatter.string(from: date)
    }

    static func drawerMonthTitle(for date: Date) -> String {
        monthDrawerFormatter.string(from: date)
    }

    static func todayHeadline(for date: Date) -> String {
        L10n.format("今天 %@ (%@)", dateFormatter.string(from: date), weekdayFormatter.string(from: date))
    }

    static func entryTime(for date: Date) -> String {
        shortTimeFormatter.string(from: date)
    }

    static func bookDate(_ date: Date) -> String {
        bookDateFormatter.string(from: date)
    }

    static func shortTimestamp(_ date: Date) -> String {
        L10n.format("%@ %@", bookDate(date), entryTime(for: date))
    }

    static func historyTitle(for date: Date) -> String {
        historyTitleFormatter.string(from: date)
    }
}
