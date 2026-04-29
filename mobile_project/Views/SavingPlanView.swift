import SwiftUI

struct SavingPlanView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var isCreateSheetPresented = false
    @State private var editingPlan: SavingPlan?
    @State private var depositTarget: SavingPlan?
    @State private var withdrawTarget: SavingPlan?
    @State private var deleteTarget: SavingPlan?

    private var activePlans: [SavingPlan] {
        store.savingPlans
            .filter { !$0.isCompleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var completedPlans: [SavingPlan] {
        store.savingPlans
            .filter { $0.isCompleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var totalTarget: Double {
        store.savingPlans.reduce(0) { $0 + $1.targetAmount }
    }

    private var totalSaved: Double {
        store.savingPlans.reduce(0) { $0 + $1.savedAmount }
    }

    private var totalRemaining: Double {
        store.savingPlans.reduce(0) { $0 + max($1.targetAmount - $1.savedAmount, 0) }
    }

    private var totalEffectiveSaved: Double {
        store.savingPlans.reduce(0) { $0 + min($1.savedAmount, $1.targetAmount) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if store.savingPlans.isEmpty {
                    emptyState
                } else {
                    overviewCard

                    if !activePlans.isEmpty {
                        planSection(title: "进行中".localized, plans: activePlans)
                    }

                    if !completedPlans.isEmpty {
                        planSection(title: "已完成".localized, plans: completedPlans)
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
                Text("攒钱计划".localized)
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
            SavingPlanEditorSheet(mode: .create) { plan in
                store.addSavingPlan(plan)
            }
        }
        .sheet(item: $editingPlan) { plan in
            SavingPlanEditorSheet(mode: .edit(plan)) { updated in
                store.updateSavingPlan(updated)
            }
        }
        .sheet(item: $depositTarget) { plan in
            SavingPlanAmountSheet(plan: plan, mode: .deposit) { amount in
                store.depositToSavingPlan(plan, amount: amount)
            }
        }
        .sheet(item: $withdrawTarget) { plan in
            SavingPlanAmountSheet(plan: plan, mode: .withdraw) { amount in
                store.withdrawFromSavingPlan(plan, amount: amount)
            }
        }
        .alert("确认删除".localized, isPresented: deleteAlertBinding) {
            Button("删除".localized, role: .destructive) {
                if let plan = deleteTarget {
                    store.deleteSavingPlan(plan)
                }
            }
            Button("取消".localized, role: .cancel) {}
        } message: {
            Text("删除后无法恢复，已存入的金额记录也会清除。".localized)
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
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.ledgerAccent)

            Text("还没有攒钱计划".localized)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Text("设定一个目标金额，记录每次存入，看着进度条一步步填满。".localized)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .multilineTextAlignment(.center)

            Button {
                isCreateSheetPresented = true
            } label: {
                Text("创建第一个计划".localized)
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

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("总览".localized)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)

                Spacer()

                Text(L10n.format("%d 个计划", store.savingPlans.count))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            HStack(spacing: 16) {
                overviewMetric(title: "目标总额".localized, value: LedgerFormatters.currency(totalTarget))
                overviewMetric(title: "已存入".localized, value: LedgerFormatters.currency(totalSaved))
                overviewMetric(
                    title: "还需要".localized,
                    value: LedgerFormatters.currency(totalRemaining))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.ledgerAccentMuted)
                        .frame(height: 10)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.ledgerIncome)
                        .frame(
                            width: max(
                                geo.size.width * (totalTarget > 0 ? min(totalEffectiveSaved / totalTarget, 1) : 0),
                                0),
                            height: 10)
                }
            }
            .frame(height: 10)
        }
        .padding(18)
        .ledgerCard()
    }

    private func overviewMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Plan Sections

    private func planSection(title: String, plans: [SavingPlan]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)

            ForEach(plans) { plan in
                planCard(plan)
            }
        }
    }

    private func planCard(_ plan: SavingPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: plan.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(plan.tintStyle.color)
                    .frame(width: 44, height: 44)
                    .background(plan.tintStyle.color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    if let deadline = plan.deadline {
                        Text(L10n.format("目标日期 %@", LedgerFormatters.bookDate(deadline)))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ledgerMuted)
                    }
                }

                Spacer()

                if plan.isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.ledgerIncome)
                }

                Menu {
                    if !plan.isCompleted {
                        Button { depositTarget = plan } label: {
                            Label("存入".localized, systemImage: "plus.circle")
                        }
                        Button { withdrawTarget = plan } label: {
                            Label("取出".localized, systemImage: "minus.circle")
                        }
                    }
                    Button { editingPlan = plan } label: {
                        Label("编辑".localized, systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) { deleteTarget = plan } label: {
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

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(LedgerFormatters.currency(plan.savedAmount))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerIncome)

                    Text("/ \(LedgerFormatters.currency(plan.targetAmount))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)

                    Spacer()

                    Text("\(Int(plan.progress * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(plan.isCompleted ? Color.ledgerIncome : Color.ledgerAccent)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.ledgerAccentMuted)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(plan.isCompleted ? Color.ledgerIncome : Color.ledgerAccent)
                            .frame(width: max(geo.size.width * plan.progress, 0), height: 8)
                    }
                }
                .frame(height: 8)
            }

            if !plan.note.isEmpty {
                Text(plan.note)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .ledgerCard()
    }
}

// MARK: - Editor Sheet

private enum SavingPlanEditorMode: Identifiable {
    case create
    case edit(SavingPlan)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let plan): "edit-\(plan.id)"
        }
    }
}

private struct SavingPlanEditorSheet: View {
    let mode: SavingPlanEditorMode
    let onSave: (SavingPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var name: String
    @State private var targetAmountText: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var note: String
    @State private var selectedTint: LedgerTintStyle
    @State private var selectedIcon: String

    private let existingPlan: SavingPlan?

    private static let iconOptions = [
        "dollarsign.circle.fill",
        "star.circle.fill",
        "heart.circle.fill",
        "airplane.circle.fill",
        "house.circle.fill",
        "car.circle.fill",
        "gift.circle.fill",
        "graduationcap.circle.fill"
    ]

    init(mode: SavingPlanEditorMode, onSave: @escaping (SavingPlan) -> Void) {
        self.mode = mode
        self.onSave = onSave

        switch mode {
        case .create:
            existingPlan = nil
            _name = State(initialValue: "")
            _targetAmountText = State(initialValue: "")
            _hasDeadline = State(initialValue: false)
            _deadline = State(initialValue: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date())
            _note = State(initialValue: "")
            _selectedTint = State(initialValue: .income)
            _selectedIcon = State(initialValue: "dollarsign.circle.fill")
        case .edit(let plan):
            existingPlan = plan
            _name = State(initialValue: plan.name)
            _targetAmountText = State(initialValue: String(format: "%.2f", plan.targetAmount))
            _hasDeadline = State(initialValue: plan.deadline != nil)
            _deadline = State(
                initialValue: plan.deadline
                    ?? (Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()))
            _note = State(initialValue: plan.note)
            _selectedTint = State(initialValue: plan.tintStyle)
            _selectedIcon = State(initialValue: plan.icon)
        }
    }

    private var isCreateMode: Bool {
        if case .create = mode { return true }
        return false
    }

    private var parsedAmount: Double? {
        Double(targetAmountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (parsedAmount ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    fieldSection(title: "名称".localized) {
                        TextField("例如：旅行基金、应急储备".localized, text: $name)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    }

                    fieldSection(title: "目标金额".localized) {
                        HStack {
                            Text("¥")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ledgerAccent)
                            TextField("0.00", text: $targetAmountText)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .keyboardType(.decimalPad)
                        }
                    }

                    fieldSection(title: "图标".localized) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                            ForEach(Self.iconOptions, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(
                                            selectedIcon == icon ? selectedTint.color : Color.ledgerMuted)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            selectedIcon == icon
                                                ? selectedTint.color.opacity(0.14) : Color.ledgerAccentMuted
                                                    .opacity(0.5))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    fieldSection(title: "颜色".localized) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 10) {
                            ForEach(LedgerTintStyle.allCases) { tint in
                                Button {
                                    selectedTint = tint
                                } label: {
                                    Circle()
                                        .fill(tint.color)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle().stroke(Color.white, lineWidth: selectedTint == tint ? 3 : 0))
                                        .shadow(
                                            color: selectedTint == tint ? tint.color.opacity(0.4) : .clear,
                                            radius: 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    fieldSection(title: "目标日期".localized) {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("设置截止日期".localized, isOn: $hasDeadline)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .tint(Color.ledgerAccent)

                            if hasDeadline {
                                DatePicker(
                                    "截止日期".localized,
                                    selection: $deadline,
                                    in: min(deadline, Date())...,
                                    displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
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
                    Text(isCreateMode ? "新建计划".localized : "编辑计划".localized)
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
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = existingPlan {
            var updated = existing
            updated.name = trimmedName
            updated.targetAmount = amount
            updated.icon = selectedIcon
            updated.tintStyle = selectedTint
            updated.deadline = hasDeadline ? deadline : nil
            updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            onSave(updated)
        } else {
            let plan = SavingPlan(
                name: trimmedName,
                icon: selectedIcon,
                tintStyle: selectedTint,
                targetAmount: amount,
                deadline: hasDeadline ? deadline : nil,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines))
            onSave(plan)
        }
        dismiss()
    }
}

// MARK: - Deposit / Withdraw Sheet

private enum SavingPlanAmountMode {
    case deposit
    case withdraw

    var title: String {
        switch self {
        case .deposit: "存入".localized
        case .withdraw: "取出".localized
        }
    }
}

private struct SavingPlanAmountSheet: View {
    let plan: SavingPlan
    let mode: SavingPlanAmountMode
    let onConfirm: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var amountText = ""

    private var parsedAmount: Double? {
        let value = Double(amountText.replacingOccurrences(of: ",", with: "."))
        guard let value, value > 0 else { return nil }
        if case .withdraw = mode {
            return value <= plan.savedAmount ? value : nil
        }
        return value
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: plan.icon)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(plan.tintStyle.color)

                    Text(plan.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Text(
                        L10n.format(
                            "当前 %@ / 目标 %@",
                            LedgerFormatters.currency(plan.savedAmount),
                            LedgerFormatters.currency(plan.targetAmount)))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
                .padding(.top, 16)

                HStack {
                    Text("¥")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerAccent)
                    TextField("0.00", text: $amountText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .foregroundStyle(Color.ledgerText)
                }
                .padding(16)
                .background(Color.ledgerElevated.opacity(colorScheme == .dark ? 0.88 : 0.94))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.ledgerCardStroke, lineWidth: 1))

                if case .withdraw = mode {
                    Text(L10n.format("可取出 %@", LedgerFormatters.currency(plan.savedAmount)))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }

                Button {
                    guard let amount = parsedAmount else { return }
                    onConfirm(amount)
                    dismiss()
                } label: {
                    Text(mode.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(parsedAmount != nil ? Color.ledgerAccent : Color.ledgerMuted.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(LedgerResponsiveButtonStyle())
                .disabled(parsedAmount == nil)

                Spacer()
            }
            .padding(.horizontal, 16)
            .background(Color.ledgerCanvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消".localized) { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.ledgerMuted)
                }
                ToolbarItem(placement: .principal) {
                    Text(mode.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)
                }
            }
        }
    }
}
