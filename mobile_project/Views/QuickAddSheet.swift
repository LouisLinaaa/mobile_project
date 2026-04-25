import SwiftUI

struct QuickAddSheet: View {
    @ObservedObject var store: LedgerStore

    @Environment(\.dismiss) private var dismiss
    @State private var draft = QuickEntryDraft()

    var body: some View {
        LedgerEntryEditorForm(
            title: "快速记一笔",
            store: store,
            draft: $draft,
            showsPrivacyCard: true,
            shouldAutoFocusAmount: true) {
                store.addEntry(from: draft)
                dismiss()
            }
            .onAppear {
                draft = store.makeDraftWithAI()
            }
    }
}

struct LedgerEntryEditorSheet: View {
    @ObservedObject var store: LedgerStore
    let entry: LedgerEntry

    @Environment(\.dismiss) private var dismiss
    @State private var draft = QuickEntryDraft()

    var body: some View {
        LedgerEntryEditorForm(
            title: "编辑记录",
            store: store,
            draft: $draft,
            showsPrivacyCard: false,
            shouldAutoFocusAmount: false) {
                store.updateEntry(entry.id, from: draft)
                dismiss()
            }
            .presentationDetents([.large])
            .onAppear {
                draft = store.makeDraft(from: entry)
            }
    }
}

private struct LedgerEntryEditorForm: View {
    let title: String
    @ObservedObject var store: LedgerStore
    @Binding var draft: QuickEntryDraft
    let showsPrivacyCard: Bool
    let shouldAutoFocusAmount: Bool
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isAmountFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    kindPicker
                    titleField
                    amountField
                    categoryGrid
                    paymentPicker
                    dateField
                    noteField
                    if showsPrivacyCard {
                        privacyCard
                    }
                }
                .padding(20)
            }
            .background(Color.ledgerCanvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(Color.ledgerMuted)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave()
                    }
                    .fontWeight(.bold)
                    .disabled((draft.parsedAmount ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.fraction(0.82), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.ledgerCanvas)
        .onChange(of: draft.kind) { _, _ in
            draft.selectedCategory = store.categories(for: draft.kind)
                .first(where: { $0.id == draft.selectedCategory.id })
                ?? store.categories(for: draft.kind).first
                ?? LedgerCategory.defaultCategory(for: draft.kind)
        }
        .onAppear {
            guard shouldAutoFocusAmount else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isAmountFocused = true
            }
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("类型")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Picker("类型", selection: $draft.kind) {
                ForEach(LedgerKind.allCases) { kind in
                    Text(kind.localizedTitle).tag(kind)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("标题")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            TextField("例如：午饭、滴滴、工资到账", text: $draft.titleText)
                .padding(18)
                .background(Color.ledgerElevated)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.ledgerCardStroke, lineWidth: 1))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerText)
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("金额")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("¥")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                TextField("0.00", text: $draft.amountText)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
            }
            .padding(18)
            .background(Color.ledgerElevated)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isAmountFocused ? Color.ledgerAccent : Color.ledgerCardStroke, lineWidth: 1.2))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.04), radius: 12, x: 0, y: 8)
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("分类")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 12) {
                ForEach(store.categories(for: draft.kind)) { category in
                    Button {
                        draft.selectedCategory = category
                    } label: {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(category.tint.opacity(draft.selectedCategory.id == category.id ? 0.24 : 0.14))
                                    .frame(width: 50, height: 50)

                                Image(systemName: category.icon)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(category.tint)
                            }

                            Text(category.name.localized)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ledgerText)
                        }
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(draft.selectedCategory.id == category.id ? category.tint.opacity(0.14) : Color
                                    .ledgerElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(
                                            draft.selectedCategory.id == category.id ? category.tint : Color.clear,
                                            lineWidth: 1.4)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var paymentPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支付方式")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Menu {
                ForEach(store.paymentMethods, id: \.self) { method in
                    Button(method.localized) {
                        draft.paymentMethod = method
                    }
                }
            } label: {
                HStack {
                    Text(draft.paymentMethod.localized)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerText)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.ledgerMuted)
                }
                .padding(18)
                .background(Color.ledgerElevated)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.ledgerCardStroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("时间")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            DatePicker(
                "记账时间",
                selection: $draft.date,
                displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color.ledgerElevated)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.ledgerCardStroke, lineWidth: 1))
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("备注")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            TextField("例如：午饭、打车、四月工资", text: $draft.note, axis: .vertical)
                .lineLimit(2...4)
                .padding(18)
                .background(Color.ledgerElevated)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.ledgerCardStroke, lineWidth: 1))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerText)
        }
    }

    private var privacyCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.ledgerAccent)

            VStack(alignment: .leading, spacing: 4) {
                Text("当前原型默认本地处理")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Text("现在这版不会接第三方记账服务，先把你的数据入口掌握在自己手里。")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }
        }
        .padding(18)
        .background(Color.ledgerAccentSoft.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
