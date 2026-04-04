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
                    .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 10)
            )
    }
}

extension View {
    func ledgerCard() -> some View {
        modifier(LedgerCardModifier())
    }
}

enum LedgerFormatters {
    static let locale = Locale(identifier: "zh_Hans_CN")

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
        formatter.dateFormat = "M月"
        return formatter
    }()

    private static let monthDrawerFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy年MM月"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEE"
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
        formatter.dateFormat = "yyyy.MM.dd"
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
        "今天 \(dateFormatter.string(from: date)) (\(weekdayFormatter.string(from: date)))"
    }

    static func entryTime(for date: Date) -> String {
        shortTimeFormatter.string(from: date)
    }

    static func bookDate(_ date: Date) -> String {
        bookDateFormatter.string(from: date)
    }
}
