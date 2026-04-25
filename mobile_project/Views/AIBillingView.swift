import AVFoundation
import Combine
import Speech
import SwiftUI
import Vision

// MARK: - AI Parse Result

struct AIParseResult {
    var amount: Double?
    var kind: LedgerKind
    var categoryHint: String
    var merchant: String
    var note: String
    var paymentMethod: String
    var rawText: String

    init(
        amount: Double? = nil,
        kind: LedgerKind = .expense,
        categoryHint: String = "",
        merchant: String = "",
        note: String = "",
        paymentMethod: String = "",
        rawText: String = "") {
        self.amount = amount
        self.kind = kind
        self.categoryHint = categoryHint
        self.merchant = merchant
        self.note = note
        self.paymentMethod = paymentMethod
        self.rawText = rawText
    }
}

// MARK: - AI Parser

enum AIParser {
    // Regex for Chinese currency amounts
    private static let amountPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"[¥￥]\s*(\d+(?:[.,]\d{1,2})?)"#),
        try! NSRegularExpression(pattern: #"(?:合计|总计|金额|实付|支付|消费|到账|转账)[：:]\s*[¥￥]?\s*(\d+(?:[.,]\d{1,2})?)"#),
        try! NSRegularExpression(pattern: #"(\d+(?:\.\d{1,2})?)元"#),
        try! NSRegularExpression(pattern: #"Amount[:\s]+\$?(\d+(?:\.\d{1,2})?)"#, options: .caseInsensitive)
    ]

    private static let incomeKeywords = [
        "工资",
        "到账",
        "收入",
        "报销",
        "转入",
        "salary",
        "income",
        "received",
        "refund",
        "退款",
        "奖金"
    ]
    private static let paymentKeywords: [String: String] = [
        "微信": "微信", "wechat": "微信",
        "支付宝": "支付宝", "alipay": "支付宝",
        "银联": "银行卡", "银行": "银行卡", "储蓄卡": "银行卡",
        "信用卡": "信用卡", "visa": "信用卡", "mastercard": "信用卡",
        "现金": "现金", "cash": "现金"
    ]
    private static let categoryMap: [(keywords: [String], category: String)] = [
        (
            ["餐厅", "外卖", "美食", "早餐", "午餐", "晚餐", "奶茶", "咖啡", "food", "restaurant", "meal", "lunch", "dinner",
             "mcdonald",
             "kfc", "starbucks"],
            "餐饮"),
        (["超市", "便利店", "购物", "淘宝", "京东", "天猫", "amazon", "mall", "shop"], "购物"),
        (["滴滴", "地铁", "公交", "打车", "高铁", "机票", "taxi", "uber", "grab", "mrt", "bus", "train", "flight"], "交通"),
        (["租金", "水电", "物业", "房", "rent", "utilities", "housing"], "住房"),
        (["电影", "游戏", "娱乐", "ktv", "cinema", "game", "entertainment"], "休闲娱乐"),
        (["医院", "药店", "体检", "诊所", "hospital", "pharmacy", "clinic", "health"], "医疗健康"),
        (["书", "课程", "培训", "教育", "book", "course", "study", "tuition"], "学习办公"),
        (["宠物", "pet", "cat", "dog"], "宠物"),
        (["工资", "salary", "wage"], "工资"),
        (["理财", "基金", "股票", "invest", "fund"], "理财收益")
    ]

    static func parseText(_ text: String, scheme: LedgerCategoryScheme) -> AIParseResult {
        let lower = text.lowercased()
        var result = AIParseResult(rawText: text)

        // Amount
        for pattern in amountPatterns {
            let range = NSRange(text.startIndex..., in: text)
            if let match = pattern.firstMatch(in: text, range: range),
               let r = Range(match.range(at: 1), in: text),
               let value = Double(text[r].replacingOccurrences(of: ",", with: "")) {
                result.amount = value
                break
            }
        }

        // Kind
        if incomeKeywords.contains(where: { lower.contains($0) }) {
            result.kind = .income
        }

        // Payment method
        for (keyword, method) in paymentKeywords {
            if lower.contains(keyword) {
                result.paymentMethod = method
                break
            }
        }

        // Category hint
        for (keywords, categoryName) in categoryMap {
            if keywords.contains(where: { lower.contains($0) }) {
                result.categoryHint = categoryName
                break
            }
        }

        // Merchant / note — first non-empty line that isn't just a number
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for line in lines {
            let stripped = line
                .replacingOccurrences(of: "[¥￥\\d.,元]", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            if stripped.count >= 2, stripped.count <= 20 {
                result.merchant = stripped
                result.note = stripped
                break
            }
        }

        return result
    }

    /// Match categoryHint to actual LedgerCategory in the current scheme
    static func resolvedCategory(for result: AIParseResult, scheme: LedgerCategoryScheme) -> LedgerCategory {
        let allCats = result.kind == .expense ? scheme.expenseCategories : scheme.incomeCategories
        let hint = result.categoryHint.lowercased()
        return allCats.first(where: { $0.name.lowercased().contains(hint) || hint.contains($0.name.lowercased()) })
            ?? LedgerCategory.defaultCategory(for: result.kind)
    }
}

// MARK: - Screenshot OCR

@MainActor
final class ScreenshotOCRViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var recognizedText = ""
    @Published var parseResult: AIParseResult?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showImagePicker = false
    @Published var showCamera = false
    @Published var confidence: Float = 0

    func recognizeImage(_ image: UIImage, scheme: LedgerCategoryScheme) {
        selectedImage = image
        isProcessing = true
        errorMessage = nil
        recognizedText = ""
        parseResult = nil
        confidence = 0

        guard let cgImage = image.cgImage else {
            errorMessage = "无法处理该图片"
            isProcessing = false
            return
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self else { return }

            if let error {
                Task { @MainActor in
                    self.errorMessage = "识别失败：\(error.localizedDescription)"
                    self.isProcessing = false
                }
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                Task { @MainActor in
                    self.errorMessage = "未识别到文字"
                    self.isProcessing = false
                }
                return
            }

            let allText = observations.compactMap { $0.topCandidates(1).first }
            let fullText = allText.map(\.string).joined(separator: "\n")
            let avgConfidence = allText.isEmpty ? 0 : allText.reduce(0) { $0 + $1.confidence } / Float(allText.count)

            Task { @MainActor in
                self.recognizedText = fullText
                self.confidence = avgConfidence
                self.parseResult = AIParser.parseText(fullText, scheme: scheme)
                self.isProcessing = false
            }
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}

// MARK: - Voice Recognition

@MainActor
final class VoiceRecognitionViewModel: ObservableObject {
    @Published var transcript = ""
    @Published var isListening = false
    @Published var parseResult: AIParseResult?
    @Published var errorMessage: String?
    @Published var authStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-Hans-CN"))
        authStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                self?.authStatus = status
            }
        }
    }

    func startListening(scheme: LedgerCategoryScheme) {
        guard authStatus == .authorized else {
            errorMessage = "请在设置中允许麦克风和语音识别权限"
            return
        }
        guard !isListening else { return }

        stopListening()
        transcript = ""
        parseResult = nil
        errorMessage = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "麦克风初始化失败"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation

        let inputNode = audioEngine.inputNode
        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor [weak self] in
                    self?.transcript = text
                    self?.resetSilenceTimer(text: text, scheme: scheme)
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor [weak self] in
                    self?.finalize(scheme: scheme)
                }
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            errorMessage = "无法启动录音引擎"
        }
    }

    func stopListening() {
        silenceTimer?.invalidate()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func resetSilenceTimer(text: String, scheme: LedgerCategoryScheme) {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.finalize(scheme: scheme)
            }
        }
    }

    private func finalize(scheme: LedgerCategoryScheme) {
        stopListening()
        guard !transcript.isEmpty else { return }
        parseResult = AIParser.parseText(transcript, scheme: scheme)
    }
}

// MARK: - Main AI Billing View

struct AIBillingView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    @State private var activeTab: AITab = .screenshot
    @StateObject private var ocrVM = ScreenshotOCRViewModel()
    @StateObject private var voiceVM = VoiceRecognitionViewModel()
    @State private var pendingDraft: QuickEntryDraft?
    @State private var showEntryEditor = false

    private enum AITab: String, CaseIterable {
        case screenshot = "截图识别"
        case voice = "语音记账"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Hero pill tabs
                    HStack(spacing: 0) {
                        ForEach(AITab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                                    activeTab = tab
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: tab == .screenshot ? "camera.viewfinder" : "waveform.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(tab.rawValue)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(activeTab == tab ? .white : Color.ledgerMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    activeTab == tab
                                        ? RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.ledgerAccent)
                                        : RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.clear))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.ledgerAccentMuted))
                    .padding(.top, 4)

                    if activeTab == .screenshot {
                        screenshotTab
                    } else {
                        voiceTab
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.ledgerCanvas.ignoresSafeArea())
            .navigationTitle("AI 智能记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LedgerToolbarBackButton { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showEntryEditor) {
            if let draft = pendingDraft {
                AIEntryConfirmSheet(draft: draft, store: store) {
                    pendingDraft = nil
                    showEntryEditor = false
                }
            }
        }
        .sheet(isPresented: $ocrVM.showImagePicker) {
            ImagePickerRepresentable(sourceType: .photoLibrary) { image in
                ocrVM.recognizeImage(image, scheme: store.currentCategoryScheme)
            }
        }
        .sheet(isPresented: $ocrVM.showCamera) {
            ImagePickerRepresentable(sourceType: .camera) { image in
                ocrVM.recognizeImage(image, scheme: store.currentCategoryScheme)
            }
        }
    }

    // MARK: Screenshot Tab

    private var screenshotTab: some View {
        VStack(spacing: 16) {
            // Image preview or upload prompt
            if let image = ocrVM.selectedImage {
                imagePreviewCard(image)
            } else {
                screenshotUploadArea
            }

            // Loading
            if ocrVM.isProcessing {
                aiProcessingCard(message: "正在识别图片文字…")
            }

            // Error
            if let err = ocrVM.errorMessage {
                aiErrorCard(err)
            }

            // Result
            if let result = ocrVM.parseResult {
                aiResultCard(result: result, onUse: {
                    pendingDraft = makeDraft(from: result)
                    showEntryEditor = true
                }, onRetry: {
                    ocrVM.selectedImage = nil
                    ocrVM.parseResult = nil
                })
            }

            // Tips
            screenshotTipsCard
        }
    }

    private var screenshotUploadArea: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.ledgerAccentMuted)
                    .frame(width: 80, height: 80)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.ledgerAccent)
            }
            VStack(spacing: 4) {
                Text("上传支付截图")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                Text("支持微信、支付宝、银行 App 等截图")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            HStack(spacing: 12) {
                Button {
                    ocrVM.showImagePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                        Text("从相册选择")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ledgerAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.ledgerAccentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    ocrVM.showCamera = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera")
                        Text("拍照识别")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.ledgerAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.ledgerAccent.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.ledgerAccentMuted.opacity(0.3))))
    }

    private func imagePreviewCard(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(maxHeight: 280)

            Button {
                ocrVM.selectedImage = nil
                ocrVM.parseResult = nil
                ocrVM.recognizedText = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.ledgerMuted)
                    .background(Circle().fill(Color.ledgerSurface))
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }

    private var screenshotTipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("识别效果最佳的截图类型", systemImage: "sparkles")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerAccent)
            ForEach([
                ("微信支付成功页", "checkmark.circle"),
                ("支付宝收付款记录", "checkmark.circle"),
                ("银行 App 转账/消费通知", "checkmark.circle"),
                ("收款码金额截图", "checkmark.circle")
            ], id: \.0) { tip, icon in
                Label(tip, systemImage: icon)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ledgerCard()
    }

    // MARK: Voice Tab

    private var voiceTab: some View {
        VStack(spacing: 16) {
            voiceMicArea
            if voiceVM.isListening || !voiceVM.transcript.isEmpty {
                voiceTranscriptCard
            }
            if voiceVM.isListening {
                aiProcessingCard(message: "正在聆听，说完后自动识别…")
            }
            if let err = voiceVM.errorMessage {
                aiErrorCard(err)
            }
            if let result = voiceVM.parseResult {
                aiResultCard(result: result, onUse: {
                    pendingDraft = makeDraft(from: result)
                    showEntryEditor = true
                }, onRetry: {
                    voiceVM.transcript = ""
                    voiceVM.parseResult = nil
                })
            }
            voiceTipsCard
        }
        .onAppear { voiceVM.requestPermissions() }
        .onDisappear { voiceVM.stopListening() }
    }

    private var voiceMicArea: some View {
        VStack(spacing: 20) {
            // Pulse animation when listening
            ZStack {
                if voiceVM.isListening {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.ledgerAccent.opacity(0.15 - Double(i) * 0.04))
                            .frame(width: 120 + CGFloat(i) * 30, height: 120 + CGFloat(i) * 30)
                            .scaleEffect(voiceVM.isListening ? 1.1 : 0.9)
                            .animation(
                                .easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(Double(i) * 0.2),
                                value: voiceVM.isListening)
                    }
                }

                Button {
                    if voiceVM.isListening {
                        voiceVM.stopListening()
                    } else {
                        voiceVM.startListening(scheme: store.currentCategoryScheme)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(voiceVM.isListening ? Color.ledgerExpense : Color.ledgerAccent)
                            .frame(width: 88, height: 88)
                            .shadow(
                                color: (voiceVM.isListening ? Color.ledgerExpense : Color.ledgerAccent).opacity(0.4),
                                radius: 16,
                                x: 0,
                                y: 8)
                        Image(systemName: voiceVM.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 160)

            VStack(spacing: 4) {
                Text(voiceVM.isListening ? "正在录音…点击停止" : "点击开始语音记账")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerText)
                Text(voiceVM.isListening ? "说出金额和消费类型" : "支持普通话和粤语")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerMuted)
            }

            if voiceVM.authStatus == .denied || voiceVM.authStatus == .restricted {
                Label("请在系统设置中开启语音识别权限", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ledgerExpense)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .ledgerCard()
    }

    private var voiceTranscriptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("识别内容", systemImage: "text.quote")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
            Text(voiceVM.transcript.isEmpty ? "等待语音输入…" : voiceVM.transcript)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(voiceVM.transcript.isEmpty ? Color.ledgerMuted : Color.ledgerText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .ledgerCard()
    }

    private var voiceTipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("语音示例", systemImage: "text.bubble.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ledgerAccent)
            ForEach([
                "「今天吃饭花了 58 元」",
                "「打车花了 32 块，用支付宝」",
                "「工资到账 15000 元」",
                "「超市购物 120.5 元，微信支付」"
            ], id: \.self) { tip in
                HStack(spacing: 6) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ledgerAccent.opacity(0.6))
                    Text(tip)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ledgerCard()
    }

    // MARK: Shared Components

    private func aiProcessingCard(message: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Color.ledgerAccent)
            Text(message)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .ledgerCard()
    }

    private func aiErrorCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.ledgerExpense)
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ledgerExpense.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func aiResultCard(result: AIParseResult, onUse: @escaping () -> Void,
                              onRetry: @escaping () -> Void) -> some View {
        let category = AIParser.resolvedCategory(for: result, scheme: store.currentCategoryScheme)

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("AI 识别结果", systemImage: "sparkle")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ledgerAccent)
                Spacer()
                Button(action: onRetry) {
                    Text("重新识别")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ledgerMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            // Fields
            VStack(spacing: 0) {
                aiResultRow(
                    label: "金额",
                    value: result.amount.map { LedgerFormatters.currency($0) } ?? "未识别",
                    accent: result
                        .amount != nil ? (result.kind == .expense ? .ledgerExpense : .ledgerIncome) : .ledgerMuted)
                Divider().padding(.leading, 16)
                aiResultRow(label: "类型", value: result.kind == .expense ? "支出" : "收入", accent: .ledgerText)
                Divider().padding(.leading, 16)
                aiResultRow(label: "分类", value: category.name, accent: category.tint)
                if !result.paymentMethod.isEmpty {
                    Divider().padding(.leading, 16)
                    aiResultRow(label: "支付", value: result.paymentMethod, accent: .ledgerText)
                }
                if !result.merchant.isEmpty {
                    Divider().padding(.leading, 16)
                    aiResultRow(label: "备注", value: result.merchant, accent: .ledgerText)
                }
            }

            // Use button
            Divider()
            Button(action: onUse) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(result.amount != nil ? "确认记账" : "手动补充后记账")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.ledgerAccent)
                .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
                .clipShape(
                    .rect(bottomLeadingRadius: 22, bottomTrailingRadius: 22, style: .continuous))
            }
            .buttonStyle(LedgerResponsiveButtonStyle())
        }
        .background(Color.ledgerElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
    }

    private func aiResultRow(label: String, value: String, accent: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ledgerMuted)
                .frame(width: 44, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Draft builder

    private func makeDraft(from result: AIParseResult) -> QuickEntryDraft {
        var draft = store.makeDraft()
        draft.kind = result.kind
        draft.titleText = result.merchant
        draft.amountText = result.amount.map { String(format: "%.2f", $0) } ?? ""
        draft.selectedCategory = AIParser.resolvedCategory(for: result, scheme: store.currentCategoryScheme)
        draft.paymentMethod = result.paymentMethod.isEmpty ? draft.paymentMethod : result.paymentMethod
        draft.note = result.merchant
        return draft
    }
}

// MARK: - Entry Confirm Sheet

/// Wraps QuickAddSheet and pre-fills it from an AI parse result.
/// Presented via sheet(item:) from AIBillingView.
struct AIEntryConfirmSheet: View, Identifiable {
    let id = UUID()
    let draft: QuickEntryDraft
    let store: LedgerStore
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // We present QuickAddSheet and the store's onAppear will call makeDraft().
        // We patch the draft by pre-populating the store's pending draft.
        QuickAddSheet(store: store)
            .onAppear {
                // Signal the store to use our AI-filled draft on next sheet open
                store.pendingAIDraft = draft
            }
            .onDisappear {
                store.pendingAIDraft = nil
                onDismiss()
            }
    }
}

// MARK: - Image Picker Bridge

struct ImagePickerRepresentable: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onSelect: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onSelect: (UIImage) -> Void
        init(onSelect: @escaping (UIImage) -> Void) {
            self.onSelect = onSelect
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onSelect(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
