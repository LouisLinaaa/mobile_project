import SwiftUI

struct DrawerMenuView: View {
    let width: CGFloat
    let topSafeInset: CGFloat
    let selectedDestination: DrawerDestination?
    let onShortcutTap: (DrawerDestination) -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    ShortcutSectionCard(
                        title: "常用功能",
                        items: DrawerShortcut.commonTools,
                        selectedDestination: selectedDestination,
                        onTap: onShortcutTap
                    )
                    ShortcutSectionCard(
                        title: "快捷记账",
                        items: DrawerShortcut.quickTools,
                        selectedDestination: selectedDestination,
                        onTap: onShortcutTap
                    )
                    linkCard
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(.top, max(6, min(20, topSafeInset * 0.35)))
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .frame(width: width, height: proxy.size.height, alignment: .topLeading)
        }
        .frame(minWidth: width, maxWidth: width, maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 40,
                topTrailingRadius: 40
            )
            .fill(.white)
            .shadow(color: Color.black.opacity(0.08), radius: 24, x: 10, y: 0)
        )
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.ledgerMuted)
                    .frame(width: 30, height: 30)
                    .background(Color.ledgerCanvas)
                    .clipShape(Circle())
                    .padding(.top, max(8, min(22, topSafeInset * 0.35)))
                    .padding(.trailing, 12)
            }
        }
        .clipped()
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.ledgerAccentSoft)
                    .frame(width: 52, height: 52)

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.ledgerAccent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("我的账本")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Text("本机存储 · 简洁记账")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.ledgerMuted)
        }
        .padding(.horizontal, 2)
    }

    private var linkCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(DrawerLinkItem.settingsItems.enumerated()), id: \.element.id) { index, item in
                let isSelected = selectedDestination == item.destination
                Button {
                    onShortcutTap(item.destination)
                } label: {
                    HStack(spacing: 14) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: item.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : item.accent)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(isSelected ? item.accent : item.accent.opacity(0.14))
                                )

                            if item.showsBadge {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                    .offset(x: 4, y: -4)
                            }
                        }

                        Text(item.title)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ledgerText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.92)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.ledgerMuted)
                    }
                    .padding(.vertical, 13)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? item.accent.opacity(0.12) : .clear)
                    )
                    .contentShape(Rectangle())
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
}

private struct ShortcutSectionCard: View {
    let title: String
    let items: [DrawerShortcut]
    let selectedDestination: DrawerDestination?
    let onTap: (DrawerDestination) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    let isSelected = selectedDestination == item.destination
                    Button {
                        onTap(item.destination)
                    } label: {
                        VStack(spacing: 7) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSelected ? item.accent.opacity(0.24) : item.accent.opacity(0.14))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(isSelected ? item.accent : .clear, lineWidth: 1.5)
                                    )

                                Image(systemName: item.icon)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(item.accent)
                            }

                            Text(item.title)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ledgerText)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(minHeight: 28)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .ledgerCard()
    }
}
