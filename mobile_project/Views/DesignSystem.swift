import SwiftUI
import UIKit

extension Color {
    static let ledgerCanvas = ledgerAdaptive(light: (0.97, 0.98, 0.99), dark: (0.05, 0.06, 0.08))
    static let ledgerSurface = ledgerAdaptive(light: (1.00, 1.00, 1.00), dark: (0.11, 0.13, 0.17))
    static let ledgerCard = ledgerAdaptive(light: (0.94, 0.97, 1.00), dark: (0.13, 0.16, 0.22))
    static let ledgerElevated = ledgerAdaptive(light: (1.00, 1.00, 1.00), dark: (0.15, 0.17, 0.22))
    static let ledgerAccent = ledgerAdaptive(light: (0.23, 0.43, 0.92), dark: (0.48, 0.64, 1.00))
    static let ledgerAccentSoft = ledgerAdaptive(light: (0.84, 0.90, 1.00), dark: (0.14, 0.22, 0.40))
    static let ledgerAccentMuted = ledgerAdaptive(light: (0.91, 0.95, 1.00), dark: (0.12, 0.17, 0.27))
    static let ledgerText = ledgerAdaptive(light: (0.11, 0.13, 0.17), dark: (0.93, 0.95, 0.98))
    static let ledgerMuted = ledgerAdaptive(light: (0.45, 0.49, 0.57), dark: (0.66, 0.70, 0.78))
    static let ledgerDivider = ledgerAdaptive(light: (0.88, 0.91, 0.95), dark: (0.24, 0.28, 0.36))
    static let ledgerCardStroke = ledgerAdaptive(light: (0.90, 0.93, 0.97), dark: (0.22, 0.27, 0.36))
    static let ledgerScrim = ledgerAdaptive(light: (0.00, 0.00, 0.00), dark: (0.00, 0.00, 0.00))
    static let ledgerExpense = ledgerAdaptive(light: (0.90, 0.32, 0.27), dark: (1.00, 0.55, 0.49))
    static let ledgerIncome = ledgerAdaptive(light: (0.20, 0.60, 0.43), dark: (0.43, 0.82, 0.64))
    static let ledgerGold = ledgerAdaptive(light: (0.84, 0.56, 0.13), dark: (1.00, 0.78, 0.35))
    static let ledgerMint = ledgerAdaptive(light: (0.28, 0.66, 0.62), dark: (0.53, 0.86, 0.82))
    static let ledgerLavender = ledgerAdaptive(light: (0.56, 0.50, 0.93), dark: (0.72, 0.68, 1.00))
    static let ledgerCoral = ledgerAdaptive(light: (0.88, 0.45, 0.40), dark: (1.00, 0.66, 0.61))

    private static func ledgerAdaptive(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)) -> Color {
        Color(UIColor { trait in
            let value = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat(value.0),
                green: CGFloat(value.1),
                blue: CGFloat(value.2),
                alpha: 1)
        })
    }
}

struct LedgerCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.ledgerSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.ledgerCardStroke, lineWidth: 1))
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.05),
                        radius: colorScheme == .dark ? 10 : 18,
                        x: 0,
                        y: colorScheme == .dark ? 4 : 10))
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
    @Environment(\.colorScheme) private var colorScheme

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.ledgerText)
                .frame(width: 44, height: 44)
                .background(Color.ledgerElevated.opacity(colorScheme == .dark ? 0.88 : 0.94))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.ledgerCardStroke, lineWidth: 1))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.04), radius: 8, x: 0, y: 4)
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
