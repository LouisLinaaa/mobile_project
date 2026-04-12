import AppIntents
import SwiftUI

struct AutoLedgerCenterView: View {
    @EnvironmentObject private var store: LedgerStore

    @StateObject private var viewModel = AutoLedgerViewModel()
    @State private var helperMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                tabSwitcher

                if viewModel.selectedTab == .automatic {
                    setupCard
                    triggerGuideCard
                    flowCard
                } else {
                    voicePlaceholderCard
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(Color.ledgerCanvas.ignoresSafeArea())
        .navigationTitle("自动记账")
        .navigationBarTitleDisplayMode(.inline)
        .alert("提示", isPresented: helperAlertBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(helperMessage ?? "")
        }
        .task {
            viewModel.refreshShortcutStatus()
            await viewModel.processPendingLaunchIfNeeded(store: store)
        }
        .onChange(of: store.autoLedgerPendingLaunch) { _, _ in
            Task {
                await viewModel.processPendingLaunchIfNeeded(store: store)
            }
        }
    }

    private var tabSwitcher: some View {
        HStack(spacing: 10) {
            ForEach(AutoLedgerCenterTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab == .automatic ? "iphone.gen3.circle" : "waveform")
                            .font(.system(size: 15, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(viewModel.selectedTab == tab ? Color.white : Color.ledgerAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(viewModel.selectedTab == tab ? Color.ledgerAccent : Color.ledgerAccentSoft)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("第一步：添加快捷指令", systemImage: "swirl.circle.righthalf.filled")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(Color.ledgerAccent)

            Text("添加你的“自动记账”快捷动作；若已存在同名动作，请选择替换旧版本。")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerText)
                .fixedSize(horizontal: false, vertical: true)

            shortcutStatusBanner

            HStack(spacing: 12) {
                Button {
                    openVideoTutorial()
                } label: {
                    Label("查看视频教程", systemImage: "play.circle.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.ledgerAccentSoft)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                VStack(spacing: 6) {
                    ShortcutsLink {
                        viewModel.beginShortcutGuide()
                    }
                    .shortcutsLinkStyle(.automatic)
                    .frame(maxWidth: .infinity, minHeight: 50)

                    Text("打开系统快捷指令页")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
            }
        }
        .padding(20)
        .ledgerCard()
    }

    private var shortcutStatusBanner: some View {
        let presentation = viewModel.shortcutStatusPresentation

        return VStack(alignment: .leading, spacing: 6) {
            Text(presentation.title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(statusTint(for: presentation.tint))

            Text(presentation.detail)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusTint(for: presentation.tint).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var triggerGuideCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("第二步：设置触发方式", systemImage: "swirl.circle")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(Color.ledgerAccent)

            Text("确认系统快捷指令页里已经出现“自动记账”后，再根据你的习惯绑定触发方式。V1 优先支持小白点与操作按钮。")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            TriggerGuideRow(
                title: "① 通过“辅助触控（小白点）”触发",
                isExpanded: $viewModel.isAssistiveTouchExpanded,
                steps: [
                    "打开手机「设置」-「辅助功能」-「触控」-「辅助触控」",
                    "打开「辅助触控」开关",
                    "在单击/轻点两下/长按动作中绑定“自动记账”",
                    "支付完成后触发对应动作，即可回到 App 审核自动记账结果"
                ]
            )

            TriggerGuideRow(
                title: "② 通过“操作按钮”触发",
                isExpanded: $viewModel.isActionButtonExpanded,
                steps: [
                    "在 iPhone 设置中进入「操作按钮」",
                    "将动作配置为运行“自动记账”",
                    "按下后会直接打开 App 进入自动记账审核页"
                ]
            )

            TriggerGuideRow(
                title: "③ 通过“轻敲手机背面”触发（后续支持）",
                isExpanded: $viewModel.isBackTapExpanded,
                steps: ["入口已预留，后续版本会补充稳定的配置与回流方案"]
            )

            TriggerGuideRow(
                title: "④ 通过“控制中心”触发（后续支持）",
                isExpanded: $viewModel.isControlCenterExpanded,
                steps: ["入口已预留，后续版本会补充系统级快捷入口支持"]
            )
        }
        .padding(20)
        .ledgerCard()
    }

    private var flowCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("识别与审核")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Spacer()

                Text(flowStateLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.ledgerAccentSoft)
                    .clipShape(Capsule())
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerExpense)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ledgerExpense.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if let successMessage = viewModel.successMessage {
                Text(successMessage)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerIncome)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ledgerIncome.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            switch viewModel.flowState {
            case .idle:
                idleFlowView
            case .awaitingShortcut:
                awaitingFlowView
            case .uploading, .parsing, .confirmed:
                processingFlowView
            case .review:
                reviewFlowView
            case .saved:
                savedFlowView
            case .failed:
                failedFlowView
            }
        }
        .padding(20)
        .ledgerCard()
    }

    private var idleFlowView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("先完成快捷指令配置，然后可以用下方按钮模拟一次“截图回传 -> AI识别 -> 人工确认入账”的闭环。")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                viewModel.beginShortcutGuide()
            } label: {
                Text("开始自动记账")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.ledgerAccent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var awaitingFlowView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("完成快捷指令截图后，点“开始识别截图”。当前原型会走 mock API，后续可切网关服务。")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    await viewModel.triggerMockShortcutParse(store: store)
                }
            } label: {
                Text("开始识别截图")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.ledgerAccent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var processingFlowView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.ledgerAccent)

            Text(viewModel.flowState == .confirmed ? "正在保存账单..." : "正在上传并解析账单...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var reviewFlowView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.reviewDraft == nil {
                Text("暂未拿到识别结果，请重试。")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            } else {
                reviewForm
            }
        }
    }

    private var savedFlowView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这笔账已经写入账本，你可以继续识别下一张。")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)

            HStack(spacing: 12) {
                Button {
                    viewModel.beginShortcutGuide()
                } label: {
                    Text("继续识别")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.ledgerAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.resetToIdle()
                } label: {
                    Text("完成")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.ledgerAccentSoft)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var failedFlowView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("识别失败了，但不会丢单。你可以立即重试，或回到待机状态稍后继续。")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)

            HStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.triggerMockShortcutParse(store: store)
                    }
                } label: {
                    Text("重试")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.ledgerAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.resetToIdle()
                } label: {
                    Text("返回")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.ledgerAccentSoft)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var reviewForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("识别结果审核")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                Spacer()

                Text(confidenceLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerAccent)
            }

            Picker("收支类型", selection: draftBinding(\.kind, default: .expense)) {
                ForEach(LedgerKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            HStack(alignment: .center, spacing: 10) {
                Text("¥")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)

                TextField("0.00", text: draftBinding(\.amountText, default: ""))
                    .keyboardType(.decimalPad)
                    .font(.system(size: 32, weight: .black, design: .rounded))
            }
            .padding(14)
            .background(Color.ledgerAccentSoft.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Picker("分类", selection: draftBinding(\.categoryID, default: LedgerCategory.defaultCategory(for: .expense).id)) {
                ForEach(currentCategories) { category in
                    Text(category.name).tag(category.id)
                }
            }
            .pickerStyle(.menu)

            Picker("支付方式", selection: draftBinding(\.paymentMethod, default: "待确认")) {
                ForEach(viewModel.paymentMethodOptions(in: store), id: \.self) { method in
                    Text(method).tag(method)
                }
            }
            .pickerStyle(.menu)

            DatePicker(
                "交易时间",
                selection: draftBinding(\.occurredAt, default: Date()),
                displayedComponents: [.date, .hourAndMinute]
            )

            TextField("商户", text: draftBinding(\.merchant, default: ""))
                .textFieldStyle(.roundedBorder)
            TextField("备注", text: draftBinding(\.note, default: ""), axis: .vertical)
                .lineLimit(2 ... 4)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("原文摘要")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)

                Text(viewModel.reviewDraft?.rawText ?? "")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ledgerAccentMuted.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Text(viewModel.reviewDraft?.reason ?? "")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)

            Button {
                viewModel.confirmAndSave(store: store)
            } label: {
                Text("确认并入账")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.ledgerAccent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.ledgerAccentSoft.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var voicePlaceholderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("语音记账（即将支持）")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Color.ledgerText)

            Text("V1 先聚焦截图识别闭环。后续版本会接入语音采集 + 结构化解析 + 入账审核。")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .ledgerCard()
    }

    private var flowStateLabel: String {
        switch viewModel.flowState {
        case .idle:
            "待机"
        case .awaitingShortcut:
            "等待触发"
        case .uploading:
            "上传中"
        case .parsing:
            "识别中"
        case .review:
            "待审核"
        case .confirmed:
            "保存中"
        case .saved:
            "已保存"
        case .failed:
            "失败"
        }
    }

    private var confidenceLabel: String {
        let score = viewModel.reviewDraft?.confidence ?? 0
        return "置信度 \(Int(score * 100))%"
    }

    private var currentCategories: [LedgerCategory] {
        let kind = viewModel.reviewDraft?.kind ?? .expense
        return store.categories(for: kind)
    }

    private func draftBinding<T>(_ keyPath: WritableKeyPath<AutoLedgerReviewDraft, T>, default defaultValue: T) -> Binding<T> {
        Binding(
            get: {
                viewModel.reviewDraft?[keyPath: keyPath] ?? defaultValue
            },
            set: { newValue in
                viewModel.updateDraft(store: store) { draft in
                    draft[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func openVideoTutorial() {
        helperMessage = "教程入口已预留。你可以在内部帮助中心配置正式教程链接。"
    }

    private func statusTint(for tint: String) -> Color {
        switch tint {
        case "success":
            .ledgerIncome
        case "error":
            .ledgerExpense
        default:
            .ledgerAccent
        }
    }

    private var helperAlertBinding: Binding<Bool> {
        Binding(
            get: { helperMessage != nil },
            set: { newValue in
                if !newValue {
                    helperMessage = nil
                }
            }
        )
    }
}

private struct TriggerGuideRow: View {
    let title: String
    @Binding var isExpanded: Bool
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerAccent)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 8)

                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.ledgerAccent)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        Text("\(index + 1). \(step)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ledgerText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ledgerAccentSoft.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
