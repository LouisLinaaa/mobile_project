import SwiftUI

struct QuickAddSheet: View {
    @ObservedObject var store: LedgerStore

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isAmountFocused: Bool
    @State private var draft = QuickEntryDraft()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    kindPicker
                    amountField
                    categoryGrid
                    paymentPicker
                    noteField
                    privacyCard
                }
                .padding(20)
            }
            .background(Color.ledgerCanvas)
            .navigationTitle("快速记一笔")
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
                        store.addEntry(from: draft)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled((draft.parsedAmount ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.fraction(0.78), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.ledgerCanvas)
        .onAppear {
            draft = store.makeDraftWithAI()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isAmountFocused = true
            }
        }
        .onChange(of: draft.kind) { _, _ in
            draft.selectedCategory = store.categories(for: draft.kind).first ?? LedgerCategory
                .defaultCategory(for: draft.kind)
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("类型")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Picker("类型", selection: $draft.kind) {
                ForEach(LedgerKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
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
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 8)
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

                            Text(category.name)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ledgerText)
                        }
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(draft.selectedCategory.id == category.id ? category.tint.opacity(0.12) : Color
                                    .white)
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
                    Button(method) {
                        draft.paymentMethod = method
                    }
                }
            } label: {
                HStack {
                    Text(draft.paymentMethod)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerText)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.ledgerMuted)
                }
                .padding(18)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
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
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
