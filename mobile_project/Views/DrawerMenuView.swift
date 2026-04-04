import SwiftUI

struct DrawerMenuView: View {
    let width: CGFloat
    let recordedDays: Set<Int>
    let totalRecordDays: Int
    let totalRecords: Int
    let streak: Int
    let onShortcutTap: (String) -> Void
    let onClose: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                monthCard
                ShortcutSectionCard(title: "常用功能", items: DrawerShortcut.commonTools, onTap: onShortcutTap)
                ShortcutSectionCard(title: "快捷记账", items: DrawerShortcut.quickTools, onTap: onShortcutTap)
                linkCard
            }
            .padding(20)
            .frame(width: width, alignment: .leading)
        }
        .frame(minWidth: width, maxWidth: width, maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 34,
                topTrailingRadius: 34
            )
            .fill(.white)
            .shadow(color: Color.black.opacity(0.08), radius: 30, x: 10, y: 0)
        )
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.ledgerMuted)
                    .frame(width: 34, height: 34)
                    .background(Color.ledgerCanvas)
                    .clipShape(Circle())
                    .padding(.top, 14)
                    .padding(.trailing, 14)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.ledgerAccentSoft)
                    .frame(width: 60, height: 60)

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.ledgerAccent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("我的账本")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Text("本机存储 · 简洁记账")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.ledgerMuted)
        }
        .padding(.top, 24)
    }

    private var monthCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(LedgerFormatters.drawerMonthTitle(for: Date()))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1...daysInCurrentMonth, id: \.self) { day in
                    let isToday = day == Calendar.current.component(.day, from: Date())
                    let hasRecord = recordedDays.contains(day)

                    Text(isToday ? "今" : "\(day)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(hasRecord || isToday ? Color.ledgerAccent : Color.ledgerMuted.opacity(0.65))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(hasRecord ? Color.ledgerAccentSoft : Color.ledgerCanvas)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(isToday ? Color.ledgerAccent : Color.clear, lineWidth: 1.5)
                                )
                        )
                }
            }

            HStack {
                DrawerStatView(value: "\(totalRecordDays)天", title: "坚持记录")
                Spacer()
                DrawerStatView(value: "\(totalRecords)条", title: "总记录")
                Spacer()
                DrawerStatView(value: "\(streak)天", title: "连续记录")
            }
        }
        .padding(20)
        .ledgerCard()
    }

    private var linkCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(DrawerLinkItem.settingsItems.enumerated()), id: \.element.id) { index, item in
                Button {
                    onShortcutTap(item.title)
                } label: {
                    HStack(spacing: 14) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: item.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(item.accent)
                                .frame(width: 34)

                            if item.showsBadge {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                    .offset(x: 4, y: -4)
                            }
                        }

                        Text(item.title)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ledgerText)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.ledgerMuted)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 18)
                }
                .buttonStyle(.plain)

                if index < DrawerLinkItem.settingsItems.count - 1 {
                    Divider()
                        .padding(.leading, 66)
                }
            }
        }
        .ledgerCard()
    }

    private var daysInCurrentMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
    }
}

private struct DrawerStatView: View {
    let value: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
        }
    }
}

private struct ShortcutSectionCard: View {
    let title: String
    let items: [DrawerShortcut]
    let onTap: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(items) { item in
                    Button {
                        onTap(item.title)
                    } label: {
                        VStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(item.accent.opacity(0.14))
                                    .frame(width: 64, height: 64)

                                Image(systemName: item.icon)
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(item.accent)
                            }

                            Text(item.title)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ledgerText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .ledgerCard()
    }
}
