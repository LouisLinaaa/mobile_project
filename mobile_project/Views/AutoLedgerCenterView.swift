import SwiftUI

struct AutoLedgerCenterView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var viewModel = AutoLedgerViewModel()
    @State private var helperMessage: String?
    @State private var isBlueprintPresented = false
    @State private var isDebugExpanded = false
    @State private var activeSheetScreen: ManagementScreen?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                aiEntryCard
                summaryCard
                shortcutCard
                triggerCard
                statusCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(backgroundView.ignoresSafeArea())
        .navigationTitle("自动记账")
        .navigationBarTitleDisplayMode(.inline)
        .alert("提示", isPresented: helperAlertBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(helperMessage ?? "")
        }
        .task {
            store.refreshAutoLedgerShortcutState()
            viewModel.refreshShortcutStatus()
            await viewModel.processPendingLaunchIfNeeded(store: store)
        }
        .onChange(of: store.autoLedgerPendingLaunch) { _, _ in
            Task {
                await viewModel.processPendingLaunchIfNeeded(store: store)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            store.refreshAutoLedgerShortcutState()
            viewModel.refreshShortcutStatus()
            Task {
                await viewModel.processPendingLaunchIfNeeded(store: store)
            }
        }
        .sheet(isPresented: $isBlueprintPresented) {
            AutoLedgerBlueprintSheet(
                onOpenEditor: openShortcutEditor,
                onOpenShortcutsApp: openShortcutsApp)
        }
        .sheet(item: $activeSheetScreen) { screen in
            ManagementSheetView(screen: screen)
                .environmentObject(store)
        }
    }

    // MARK: - AI Entry Card

    private var aiEntryCard: some View {
        Button { activeSheetScreen = .aiBilling } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.ledgerMint.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.ledgerMint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("AI 智能记账")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ledgerText)
                        Text("截图 · 语音")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.ledgerMint)
                            .clipShape(Capsule())
                    }
                    Text("上传支付截图或说一句话，自动识别金额和分类")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.ledgerMuted.opacity(0.5))
            }
            .padding(16)
            .background(Color.ledgerElevated)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(LedgerResponsiveButtonStyle())
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [Color.ledgerAccentSoft.opacity(0.58), Color.ledgerCanvas, Color.ledgerCanvas],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("系统动作已经准备好")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Text("安装 App 后，系统里可以直接搜到 Monee 提供的“识别账单”动作。快捷指令会直接接收截图、完成识别并自动入账，不需要再跳回 App。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerText.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                VStack(spacing: 10) {
                    statusBadgeView(title: "识别账单", tint: .ledgerAccent)
                    statusBadgeView(title: viewModel.recognitionEngineTitle, tint: engineTint)
                }
            }

            if viewModel.recognitionEngine == .local {
                Text(
                    "当前还没配置截图识别的大模型。把 `.env.template` 里的 `AUTO_LEDGER_OPENAI_*` 变量填到 Scheme 环境变量或 Info.plist 后，会自动切到 API 识别。语音记账保持本地语音识别。")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerGold)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ledgerGold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(22)
        .ledgerCard()
    }

    private var shortcutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "怎么用",
                subtitle: "在快捷指令里新建一条捷径，然后把 Monee 的“识别账单”接到截图后面。")

            shortcutPreview

            VStack(alignment: .leading, spacing: 10) {
                guideLine("新建快捷指令，建议命名成“Monee-自动记账”。")
                guideLine("按顺序添加：截图 -> 从截图获取图像 -> 识别账单。")
                guideLine("“识别账单”的“图片”参数接上一步结果，“运行时显示”建议关闭。")
            }

            HStack(spacing: 12) {
                primaryActionButton(title: "查看结构") {
                    isBlueprintPresented = true
                }

                secondaryActionButton(title: "打开快捷指令编辑器") {
                    openShortcutEditor()
                }
            }
        }
        .padding(20)
        .ledgerCard()
    }

    private var shortcutPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                chainNode(title: "截图", tint: .ledgerAccent)
                chainArrow
                chainNode(title: "从截图获取图像", tint: .ledgerMint)
                chainArrow
                chainNode(title: "识别账单", tint: .ledgerGold)
            }

            HStack(spacing: 10) {
                settingPill(label: "图片", value: "接截图结果")
                settingPill(label: "内容", value: "可留空")
                settingPill(label: "显示", value: "关闭")
            }
        }
        .padding(18)
        .background(Color(red: 0.10, green: 0.12, blue: 0.18))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var triggerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "绑定触发方式",
                subtitle: "快捷指令搭好后，再把它绑到一个顺手的系统入口。")

            VStack(alignment: .leading, spacing: 12) {
                triggerBlock(
                    title: "辅助触控（小白点）",
                    steps: [
                        "设置 -> 辅助功能 -> 触控 -> 辅助触控。",
                        "在单击 / 轻点两下 / 长按里绑定你的自动记账捷径。",
                        "支付页截图后触发即可。"
                    ])

                triggerBlock(
                    title: "操作按钮",
                    steps: [
                        "设置 -> 操作按钮。",
                        "选择“快捷指令”，再选中你的自动记账捷径。",
                        "截图后按一下即可触发。"
                    ])
            }
        }
        .padding(20)
        .ledgerCard()
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "最近状态",
                subtitle: statusSummaryText)

            VStack(alignment: .leading, spacing: 10) {
                supportRow(label: "识别引擎", value: viewModel.recognitionEngineTitle)

                if let lastTriggeredAt = viewModel.shortcutStatus.lastTriggeredAt {
                    supportRow(label: "最近触发", value: LedgerFormatters.shortTimestamp(lastTriggeredAt))
                }

                if let lastSource = viewModel.shortcutStatus.lastSource {
                    supportRow(label: "触发来源", value: lastSource.displayName)
                }

                if let lastCompletedAt = viewModel.shortcutStatus.lastCompletedAt {
                    supportRow(label: "最近完成", value: LedgerFormatters.shortTimestamp(lastCompletedAt))
                }
            }

            if let successMessage = viewModel.successMessage {
                messageBox(text: successMessage, tint: .ledgerIncome)
            }

            if let errorMessage = viewModel.errorMessage ?? viewModel.shortcutStatus.lastErrorMessage {
                messageBox(text: errorMessage, tint: .ledgerExpense)
            }

            HStack(spacing: 12) {
                primaryActionButton(
                    title: shouldShowRetry ? "重试最近一次" : "打开快捷指令 App",
                    accent: shouldShowRetry ? .ledgerExpense : .ledgerAccent) {
                        if shouldShowRetry {
                            Task {
                                await viewModel.retryLastRecognition(store: store)
                            }
                        } else {
                            openShortcutsApp()
                        }
                    }

                secondaryActionButton(title: "查看结构") {
                    isBlueprintPresented = true
                }
            }

            if let debugSnapshot = viewModel.debugSnapshot {
                debugCard(debugSnapshot)
            }
        }
        .padding(20)
        .ledgerCard()
    }

    private var shouldShowRetry: Bool {
        viewModel.flowState == .failed || !(viewModel.shortcutStatus.lastErrorMessage?.isEmpty ?? true)
    }

    private var statusSummaryText: String {
        if shouldShowRetry {
            return "最近一次处理失败。先确认截图来源，再检查快捷指令是不是三步结构。"
        }

        if viewModel.shortcutStatus.lastTriggeredAt != nil {
            return "结构跑通后，后续就是截图 -> 触发 -> 快捷指令内完成识别并自动入账。"
        }

        return "还没有跑过完整闭环。建议先用一张真实支付截图验证一次。"
    }

    private var engineTint: Color {
        viewModel.recognitionEngine == .gateway ? .ledgerIncome : .ledgerGold
    }

    private func debugCard(_ snapshot: AutoLedgerDebugSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isDebugExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("最近调用")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ledgerText)

                    Spacer()

                    Text(LedgerFormatters.shortTimestamp(snapshot.timestamp))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)

                    Image(systemName: isDebugExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.ledgerAccent)
                }
            }
            .buttonStyle(.plain)

            debugRow(label: "引擎", value: snapshot.engine)

            if let model = snapshot.model {
                debugRow(label: "模型", value: model)
            }

            if let endpoint = snapshot.endpoint {
                debugRow(label: "端点", value: endpoint)
            }

            if isDebugExpanded {
                debugSection(title: "请求摘要", content: snapshot.requestSummary)

                if let rawOCRPreview = snapshot.rawOCRPreview {
                    debugSection(title: "OCR 摘要", content: rawOCRPreview)
                }

                if let rawResponse = snapshot.rawResponse {
                    debugSection(title: "原始返回全文", content: rawResponse)
                }

                if let parsedResult = snapshot.parsedResult,
                   let parsedData = try? JSONEncoder().encode(parsedResult),
                   let parsedText = String(data: parsedData, encoding: .utf8) {
                    debugSection(title: "解析结果", content: parsedText)
                }

                if let errorMessage = snapshot.errorMessage {
                    debugSection(title: "错误", content: errorMessage, tint: .ledgerExpense)
                }
            }
        }
        .padding(14)
        .background(Color.ledgerAccentSoft.opacity(0.32))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func openShortcutEditor() {
        guard let url = URL(string: "shortcuts://create-shortcut") else {
            helperMessage = "无法打开快捷指令编辑器，请手动前往快捷指令 App。"
            return
        }

        openURL(url) { accepted in
            if !accepted {
                openShortcutsApp()
            }
        }
    }

    private func openShortcutsApp() {
        guard let url = URL(string: "shortcuts://") else {
            helperMessage = "无法打开快捷指令 App，请手动前往系统快捷指令。"
            return
        }

        openURL(url) { accepted in
            if !accepted {
                helperMessage = "系统没有成功打开快捷指令 App，请手动前往快捷指令。"
            }
        }
    }

    private var helperAlertBinding: Binding<Bool> {
        Binding(
            get: { helperMessage != nil },
            set: { newValue in
                if !newValue {
                    helperMessage = nil
                }
            })
    }
}

private func debugRow(label: String, value: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Text(label)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ledgerMuted)
            .frame(width: 44, alignment: .leading)

        Text(value)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(Color.ledgerText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func debugSection(title: String, content: String, tint: Color = .ledgerText) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ledgerMuted)

        Text(content)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.ledgerElevated.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .textSelection(.enabled)
    }
}

private struct AutoLedgerBlueprintSheet: View {
    let onOpenEditor: () -> Void
    let onOpenShortcutsApp: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("结构示意")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ledgerText)

                        Text("只保留一条最短可用路径。不要再做多余的安装跳转。")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ledgerMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ledgerElevated.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: Color.ledgerAccent.opacity(0.10), radius: 18, x: 0, y: 10)

                    blueprintSection(title: "三步结构") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                blueprintNode("截图", tint: .ledgerAccent)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.white.opacity(0.55))
                                blueprintNode("从截图获取图像", tint: .ledgerMint)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.white.opacity(0.55))
                                blueprintNode("识别账单", tint: .ledgerGold)
                            }

                            Text("最后一步搜索“Monee”，添加系统已经暴露出来的“识别账单”动作。")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.74))
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.10, green: 0.12, blue: 0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }

                    blueprintSection(title: "参数设置") {
                        VStack(alignment: .leading, spacing: 10) {
                            blueprintBullet("图片：接“从截图获取图像”的输出。")
                            blueprintBullet("内容：先留空即可。")
                            blueprintBullet("运行时显示：建议关闭。")
                            blueprintBullet("整条捷径建议命名成“Monee-自动记账”。")
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            onOpenEditor()
                        } label: {
                            Text("打开快捷指令编辑器")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.ledgerAccent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            onOpenShortcutsApp()
                        } label: {
                            Text("打开快捷指令 App")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ledgerAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.ledgerAccentSoft)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(
                LinearGradient(
                    colors: [Color.ledgerAccentSoft.opacity(0.55), Color.ledgerCanvas, Color.ledgerCanvas],
                    startPoint: .topLeading,
                    endPoint: .bottom)
                    .ignoresSafeArea())
            .navigationTitle("快捷指令结构")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LedgerToolbarBackButton {
                        dismiss()
                    }
                }
            }
        }
    }
}

private func sectionHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.system(size: 24, weight: .black, design: .rounded))
            .foregroundStyle(Color.ledgerText)

        Text(subtitle)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(Color.ledgerMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func guideLine(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Image(systemName: "circle.fill")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(Color.ledgerAccent)
            .padding(.top, 7)

        Text(text)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(Color.ledgerText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func statusBadgeView(title: String, tint: Color) -> some View {
    Text(title)
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint)
        .clipShape(Capsule())
}

private func chainNode(title: String, tint: Color) -> some View {
    Text(title)
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(tint.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
}

private var chainArrow: some View {
    Image(systemName: "arrow.right")
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(.white.opacity(0.58))
}

private func settingPill(label: String, value: String) -> some View {
    VStack(spacing: 4) {
        Text(label)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.64))

        Text(value)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(.white.opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
}

private func triggerBlock(title: String, steps: [String]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        Text(title)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ledgerText)

        ForEach(steps, id: \.self) { step in
            Text(step)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.ledgerAccentSoft.opacity(0.55))
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
}

private func supportRow(label: String, value: String) -> some View {
    HStack {
        Text(label)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ledgerMuted)

        Spacer()

        Text(value)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.ledgerText)
    }
}

private func messageBox(text: String, tint: Color) -> some View {
    Text(text)
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(tint)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
}

private func primaryActionButton(title: String, accent: Color = .ledgerAccent,
                                 action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(accent)
            .clipShape(Capsule())
    }
    .buttonStyle(.plain)
}

private func secondaryActionButton(title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ledgerAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.ledgerAccentSoft)
            .clipShape(Capsule())
    }
    .buttonStyle(.plain)
}

private func blueprintSection(title: String, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(.system(size: 22, weight: .black, design: .rounded))
            .foregroundStyle(Color.ledgerText)

        content()
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.ledgerElevated)
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 10)
}

private func blueprintBullet(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Image(systemName: "circle.fill")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(Color.ledgerAccent)
            .padding(.top, 7)

        Text(text)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(Color.ledgerText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func blueprintNode(_ title: String, tint: Color) -> some View {
    Text(title)
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
}
