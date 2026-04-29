import SwiftUI

enum SearchNavigationAction {
    case showEntry(LedgerEntry)
    case openScreen(ManagementScreen)
    case switchBook(LedgerBook)
}

struct SearchView: View {
    @ObservedObject var store: LedgerStore
    let onNavigate: (SearchNavigationAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var query = ""
    @FocusState private var isSearchFieldFocused: Bool

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasQuery: Bool {
        !trimmedQuery.isEmpty
    }

    // MARK: - Search Logic

    private var matchedEntries: [LedgerEntry] {
        guard hasQuery else { return [] }
        let q = trimmedQuery
        return store.entries
            .filter { entry in
                entry.title.localizedCaseInsensitiveContains(q)
                    || entry.note.localizedCaseInsensitiveContains(q)
                    || entry.category.name.localized.localizedCaseInsensitiveContains(q)
                    || entry.category.localizedNameVariants.contains { $0.localizedCaseInsensitiveContains(q) }
                    || entry.paymentMethod.localizedCaseInsensitiveContains(q)
                    || entry.tags.contains { $0.localizedCaseInsensitiveContains(q) }
            }
            .sorted { $0.date > $1.date }
            .prefix(20)
            .map { $0 }
    }

    private var matchedBooks: [LedgerBook] {
        guard hasQuery else { return [] }
        let q = trimmedQuery
        return store.books.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.note.localizedCaseInsensitiveContains(q)
        }
    }

    private var matchedCategories: [LedgerCategory] {
        guard hasQuery else { return [] }
        let q = trimmedQuery
        let all = store.allCategories(for: .expense) + store.allCategories(for: .income)
        var seen = Set<String>()
        return all.filter { cat in
            guard seen.insert(cat.id).inserted else { return false }
            return cat.localizedNameVariants.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    private var matchedActions: [DrawerShortcut] {
        guard hasQuery else { return [] }
        let q = trimmedQuery
        let pool = DrawerShortcut.commonTools + DrawerShortcut.quickTools
        return pool.filter { shortcut in
            guard case .screen = shortcut.destination else { return false }
            return shortcut.title.localized.localizedCaseInsensitiveContains(q)
        }
    }

    private var hasResults: Bool {
        !matchedEntries.isEmpty || !matchedBooks.isEmpty
            || !matchedCategories.isEmpty || !matchedActions.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        if !hasQuery {
                            suggestionsSection
                        } else if hasResults {
                            resultsContent
                        } else {
                            noResultsState
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 64)
                }
            }
            .background(Color.ledgerCanvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LedgerToolbarBackButton { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("搜索".localized)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)
                }
            }
        }
        .onAppear {
            isSearchFieldFocused = true
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ledgerMuted)

            TextField("搜索记录、账本、分类或功能".localized, text: $query)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFieldFocused)

            if hasQuery {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.ledgerMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.ledgerElevated.opacity(colorScheme == .dark ? 0.88 : 0.94))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.ledgerCardStroke, lineWidth: 1))
    }

    // MARK: - Suggestions (empty query)

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("常用功能".localized)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(DrawerShortcut.commonTools) { shortcut in
                    Button {
                        navigateToShortcut(shortcut)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: shortcut.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(shortcut.accent)
                                .frame(width: 48, height: 48)
                                .background(shortcut.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            Text(shortcut.title.localized)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.ledgerText)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(LedgerResponsiveButtonStyle())
                }
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsContent: some View {
        if !matchedActions.isEmpty {
            resultsSection(title: "快捷操作".localized) {
                ForEach(matchedActions) { shortcut in
                    Button { navigateToShortcut(shortcut) } label: {
                        actionRow(shortcut: shortcut)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        if !matchedEntries.isEmpty {
            resultsSection(title: "记录".localized) {
                ForEach(matchedEntries) { entry in
                    Button {
                        dismiss()
                        onNavigate(.showEntry(entry))
                    } label: {
                        TransactionRow(entry: entry, isSensitiveVisible: !store.appSettings.hideSensitiveInfo)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        if !matchedBooks.isEmpty {
            resultsSection(title: "账本".localized) {
                ForEach(matchedBooks) { book in
                    Button {
                        dismiss()
                        onNavigate(.switchBook(book))
                    } label: {
                        bookRow(book: book)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        if !matchedCategories.isEmpty {
            resultsSection(title: "分类".localized) {
                ForEach(matchedCategories) { category in
                    Button {
                        dismiss()
                        onNavigate(.openScreen(.categories))
                    } label: {
                        categoryRow(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - No Results

    private var noResultsState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.ledgerAccent)

            Text("没有找到匹配结果".localized)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Text("试试换个关键词，或检查一下输入是否正确。".localized)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(Color.ledgerAccentMuted.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Row Components

    private func actionRow(shortcut: DrawerShortcut) -> some View {
        HStack(spacing: 14) {
            Image(systemName: shortcut.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(shortcut.accent)
                .frame(width: 40, height: 40)
                .background(shortcut.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(shortcut.title.localized)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.ledgerMuted)
        }
        .padding(12)
        .background(Color.ledgerAccentMuted.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func bookRow(book: LedgerBook) -> some View {
        HStack(spacing: 14) {
            Image(systemName: book.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(book.tintStyle.color)
                .frame(width: 40, height: 40)
                .background(book.tintStyle.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(book.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                if !book.note.isEmpty {
                    Text(book.note)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            if book.id == store.selectedBookID {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ledgerAccent)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.ledgerMuted)
        }
        .padding(12)
        .background(Color.ledgerAccentMuted.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func categoryRow(category: LedgerCategory) -> some View {
        HStack(spacing: 14) {
            Image(systemName: category.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(category.tint)
                .frame(width: 40, height: 40)
                .background(category.tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name.localized)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Text(category.kind.localizedTitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.ledgerMuted)
        }
        .padding(12)
        .background(Color.ledgerAccentMuted.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ledgerMuted)
    }

    private func resultsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title)
            content()
        }
    }

    private func navigateToShortcut(_ shortcut: DrawerShortcut) {
        guard case .screen(let screen) = shortcut.destination else { return }
        dismiss()
        onNavigate(.openScreen(screen))
    }
}
