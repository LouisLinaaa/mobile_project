import SwiftUI

struct ScheduledLedgerView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var isCreateSheetPresented = false
    @State private var editingEntry: ScheduledLedgerEntry?
    @State private var deleteTarget: ScheduledLedgerEntry?

    private var activeEntries: [ScheduledLedgerEntry] {
        store.scheduledEntries
            .filter { $0.isEnabled && !$0.isExpired }
            .sorted { $0.nextDate < $1.nextDate }
    }

    private var inactiveEntries: [ScheduledLedgerEntry] {
        store.scheduledEntries
            .filter { !$0.isEnabled || $0.isExpired }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if store.scheduledEntries.isEmpty {
                    emptyState
                } else {
                    if !store.overdueScheduledEntries.isEmpty {
                        overdueSection
                    }

                    if !activeEntries.isEmpty {
                        entrySection(title: "进行中".localized, entries: activeEntries)
                    }

                    if !inactiveEntries.isEmpty {
                        entrySection(title: "已停用".localized, entries: inactiveEntries)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 64)
        }
        .background(Color.ledgerCanvas.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("定时记账".localized)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreateSheetPresented = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.ledgerAccent)
                }
            }
        }
        .sheet(isPresented: $isCreateSheetPresented) {
            ScheduledLedgerEditorSheet(
                mode: .create,
                store: store) { entry in
                    store.addScheduledEntry(entry)
                }
        }
        .sheet(item: $editingEntry) { entry in
            ScheduledLedgerEditorSheet(
                mode: .edit(entry),
                store: store) { updated in
                    store.updateScheduledEntry(updated)
                }
        }
        .alert("确认删除".localized, isPresented: deleteAlertBinding) {
            Button("删除".localized, role: .destructive) {
                if let entry = deleteTarget {
                    store.deleteScheduledEntry(entry)
                }
            }
            Button("取消".localized, role: .cancel) {}
        } message: {
            Text("删除后该定时记账规则将不再执行。".localized)
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } })
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.ledgerAccent)

            Text("还没有定时记账".localized)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Text("设定周期性的收支规则，到期自动提醒你记账。".localized)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .multilineTextAlignment(.center)

            Button {
                isCreateSheetPresented = true
            } label: {
                Text("创建第一条规则".localized)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.ledgerAccent)
                    .clipShape(Capsule())
            }
            .buttonStyle(LedgerResponsiveButtonStyle())
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(Color.ledgerAccentMuted.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Overdue

    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("待入账".localized)

            ForEach(store.overdueScheduledEntries) { entry in
                overdueCard(entry)
            }
        }
    }

    private func overdueCard(_ entry: ScheduledLedgerEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: entry.category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(entry.category.tint)
                    .frame(width: 40, height: 40)
                    .background(entry.category.tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Text(entry.recurrenceSummary)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerExpense)
                }

                Spacer()

                Text(LedgerFormatters.currency(entry.amount))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.kind == .expense ? Color.ledgerExpense : Color.ledgerIncome)
            }

            Button {
                store.executeScheduledEntry(entry)
            } label: {
                Text("立即入账".localized)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.ledgerAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(LedgerResponsiveButtonStyle())
        }
        .padding(14)
        .background(Color.ledgerExpense.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.ledgerExpense.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Entry Sections

    private func entrySection(title: String, entries: [ScheduledLedgerEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title)

            ForEach(entries) { entry in
                entryCard(entry)
            }
        }
    }

    private func entryCard(_ entry: ScheduledLedgerEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.category.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(entry.isEnabled ? entry.category.tint : Color.ledgerMuted)
                .frame(width: 44, height: 44)
                .background((entry.isEnabled ? entry.category.tint : Color.ledgerMuted).opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.isEnabled ? Color.ledgerText : Color.ledgerMuted)

                Text(entry.recurrenceSummary)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(LedgerFormatters.currency(entry.amount))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        entry.isEnabled
                            ? (entry.kind == .expense ? Color.ledgerExpense : Color.ledgerIncome)
                            : Color.ledgerMuted)

                Text(entry.kind.localizedTitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            Menu {
                Button { editingEntry = entry } label: {
                    Label("编辑".localized, systemImage: "pencil")
                }
                Button {
                    store.toggleScheduledEntry(entry)
                } label: {
                    Label(
                        entry.isEnabled ? "停用".localized : "启用".localized,
                        systemImage: entry.isEnabled ? "pause.circle" : "play.circle")
                }
                if entry.isEnabled && !entry.isExpired {
                    Button {
                        store.executeScheduledEntry(entry)
                    } label: {
                        Label("立即入账".localized, systemImage: "checkmark.circle")
                    }
                }
                Divider()
                Button(role: .destructive) { deleteTarget = entry } label: {
                    Label("删除".localized, systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ledgerMuted)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
        }
        .padding(14)
        .ledgerCard()
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ledgerMuted)
    }
}

// MARK: - Editor Sheet

private enum ScheduledLedgerEditorMode: Identifiable {
    case create
    case edit(ScheduledLedgerEntry)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let entry): "edit-\(entry.id)"
        }
    }
}

private struct ScheduledLedgerEditorSheet: View {
    let mode: ScheduledLedgerEditorMode
    let store: LedgerStore
    let onSave: (ScheduledLedgerEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var title: String
    @State private var amountText: String
    @State private var kind: LedgerKind
    @State private var selectedCategory: LedgerCategory
    @State private var paymentMethod: String
    @State private var note: String
    @State private var recurrence: ScheduledRecurrence
    @State private var nextDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date

    private let existingEntry: ScheduledLedgerEntry?

    init(mode: ScheduledLedgerEditorMode, store: LedgerStore, onSave: @escaping (ScheduledLedgerEntry) -> Void) {
        self.mode = mode
        self.store = store
        self.onSave = onSave

        switch mode {
        case .create:
            existingEntry = nil
            _title = State(initialValue: "")
            _amountText = State(initialValue: "")
            _kind = State(initialValue: .expense)
            _selectedCategory = State(initialValue: LedgerCategory.defaultCategory(for: .expense))
            _paymentMethod = State(initialValue: "支付宝")
            _note = State(initialValue: "")
            _recurrence = State(initialValue: .monthly)
            _nextDate = State(initialValue: Date())
            _hasEndDate = State(initialValue: false)
            _endDate = State(
                initialValue: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
        case .edit(let entry):
            existingEntry = entry
            _title = State(initialValue: entry.title)
            _amountText = State(initialValue: String(format: "%.2f", entry.amount))
            _kind = State(initialValue: entry.kind)
            _selectedCategory = State(initialValue: entry.category)
            _paymentMethod = State(initialValue: entry.paymentMethod)
            _note = State(initialValue: entry.note)
            _recurrence = State(initialValue: entry.recurrence)
            _nextDate = State(initialValue: entry.nextDate)
            _hasEndDate = State(initialValue: entry.endDate != nil)
            _endDate = State(
                initialValue: entry.endDate
                    ?? (Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()))
        }
    }

    private var isCreateMode: Bool {
        if case .create = mode { return true }
        return false
    }

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (parsedAmount ?? 0) > 0
    }

    private var categoryOptions: [LedgerCategory] {
        store.allCategories(for: kind)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    fieldSection(title: "标题".localized) {
                        TextField("例如：房租、工资、会员费".localized, text: $title)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    }

                    fieldSection(title: "金额".localized) {
                        HStack {
                            Text("¥")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ledgerAccent)
                            TextField("0.00", text: $amountText)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .keyboardType(.decimalPad)
                        }
                    }

                    fieldSection(title: "类型".localized) {
                        Picker("", selection: $kind) {
                            ForEach(LedgerKind.allCases) { k in
                                Text(k.localizedTitle).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: kind) { _, newKind in
                            selectedCategory = store.allCategories(for: newKind).first
                                ?? LedgerCategory.defaultCategory(for: newKind)
                        }
                    }

                    fieldSection(title: "分类".localized) {
                        categoryPicker
                    }

                    fieldSection(title: "支付方式".localized) {
                        Picker("", selection: $paymentMethod) {
                            ForEach(store.paymentMethods, id: \.self) { method in
                                Text(method).tag(method)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.ledgerText)
                    }

                    fieldSection(title: "重复周期".localized) {
                        Picker("", selection: $recurrence) {
                            ForEach(ScheduledRecurrence.allCases) { r in
                                Text(r.localizedTitle).tag(r)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    fieldSection(title: "下次执行日期".localized) {
                        DatePicker(
                            "",
                            selection: $nextDate,
                            displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }

                    fieldSection(title: "结束日期".localized) {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("设置结束日期".localized, isOn: $hasEndDate)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .tint(Color.ledgerAccent)

                            if hasEndDate {
                                DatePicker(
                                    "",
                                    selection: $endDate,
                                    in: nextDate...,
                                    displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                            }
                        }
                    }

                    fieldSection(title: "备注".localized) {
                        TextField("可选备注".localized, text: $note, axis: .vertical)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .lineLimit(3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 64)
            }
            .background(Color.ledgerCanvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消".localized) { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.ledgerMuted)
                }
                ToolbarItem(placement: .principal) {
                    Text(isCreateMode ? "新建定时记账".localized : "编辑定时记账".localized)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存".localized) {
                        save()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canSave ? Color.ledgerAccent : Color.ledgerMuted)
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
            ForEach(categoryOptions) { cat in
                Button {
                    selectedCategory = cat
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                selectedCategory.id == cat.id ? cat.tint : Color.ledgerMuted)
                            .frame(width: 36, height: 36)
                            .background(
                                selectedCategory.id == cat.id
                                    ? cat.tint.opacity(0.14) : Color.ledgerAccentMuted.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Text(cat.name.localized)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                selectedCategory.id == cat.id ? Color.ledgerText : Color.ledgerMuted)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func fieldSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)

            content()
                .padding(14)
                .background(Color.ledgerElevated.opacity(colorScheme == .dark ? 0.88 : 0.94))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.ledgerCardStroke, lineWidth: 1))
        }
    }

    private func save() {
        guard canSave, let amount = parsedAmount else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = existingEntry {
            var updated = existing
            updated.title = trimmedTitle
            updated.amount = amount
            updated.kind = kind
            updated.category = selectedCategory
            updated.paymentMethod = paymentMethod
            updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.recurrence = recurrence
            updated.nextDate = nextDate
            updated.endDate = hasEndDate ? endDate : nil
            onSave(updated)
        } else {
            let entry = ScheduledLedgerEntry(
                title: trimmedTitle,
                amount: amount,
                kind: kind,
                category: selectedCategory,
                paymentMethod: paymentMethod,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                recurrence: recurrence,
                nextDate: nextDate,
                endDate: hasEndDate ? endDate : nil,
                bookID: store.currentBook.id)
            onSave(entry)
        }
        dismiss()
    }
}
