import Foundation

protocol AutoLedgerServiceProtocol {
    func parseReceipt(_ request: AutoLedgerParseRequest) async throws -> AutoLedgerParseResult
}

enum AutoLedgerServiceEnvironment {
    case mock
    case gateway(baseURL: URL, apiKey: String?)
}

enum AutoLedgerServiceError: LocalizedError {
    case invalidResponse
    case networkFailure(Int)
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务返回数据格式不正确，请稍后重试。"
        case .networkFailure(let status):
            return "网络请求失败（\(status)），请检查后重试。"
        case .parseFailed:
            return "识别结果缺少关键字段，请手动补全后保存。"
        }
    }
}

struct AutoLedgerServiceFactory {
    static func make(environment: AutoLedgerServiceEnvironment = .mock) -> any AutoLedgerServiceProtocol {
        switch environment {
        case .mock:
            return MockAutoLedgerService()
        case .gateway(let baseURL, let apiKey):
            return GatewayAutoLedgerService(baseURL: baseURL, apiKey: apiKey)
        }
    }
}

struct MockAutoLedgerService: AutoLedgerServiceProtocol {
    func parseReceipt(_ request: AutoLedgerParseRequest) async throws -> AutoLedgerParseResult {
        try await Task.sleep(nanoseconds: 650_000_000)

        let hints = request.ocrTextHint ?? ""
        let isIncome = hints.contains("退款") || hints.contains("回款")
        let now = ISO8601DateFormatter().string(from: Date())

        if isIncome {
            return AutoLedgerParseResult(
                amount: 36.80,
                kind: "income",
                category: "退款",
                paymentMethod: "待确认",
                time: now,
                merchant: "平台退款",
                note: "自动识别：商品退货退款",
                rawText: "商户: 平台退款 金额:36.80 支付方式:电子支付",
                confidence: 0.85,
                reason: "识别到退款关键词和正向金额"
            )
        }

        return AutoLedgerParseResult(
            amount: 18.50,
            kind: "expense",
            category: "餐饮",
            paymentMethod: "待确认",
            time: now,
            merchant: "便利店",
            note: "自动识别：晚餐补给",
            rawText: "商户: 便利店 金额:18.50 支付方式:电子支付",
            confidence: 0.81,
            reason: "识别到消费场景和支付方式"
        )
    }
}

final class GatewayAutoLedgerService: AutoLedgerServiceProtocol {
    private let baseURL: URL
    private let apiKey: String?

    init(baseURL: URL, apiKey: String?) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    func parseReceipt(_ request: AutoLedgerParseRequest) async throws -> AutoLedgerParseResult {
        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey, !apiKey.isEmpty {
            urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let payload = AutoLedgerGatewayRequestBody(
            prompt: AutoLedgerPromptTemplate.userPrompt(for: request),
            rawOCR: request.ocrTextHint,
            imageBase64: request.imageData.base64EncodedString()
        )
        urlRequest.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw AutoLedgerServiceError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            throw AutoLedgerServiceError.networkFailure(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(AutoLedgerGatewayResponse.self, from: data)
        return try decoded.normalizedResult()
    }
}

enum AutoLedgerPromptTemplate {
    static let systemPrompt = """
你是记账结构化助手。请把账单信息提取为严格 JSON，字段必须包含：amount, kind, category, paymentMethod, time, merchant, note, rawText, confidence, reason。
kind 仅允许 expense 或 income。无法确定时也要给出最可能值，并在 reason 说明。
"""

    static func userPrompt(for request: AutoLedgerParseRequest) -> String {
        """
\(systemPrompt)

上下文：
- currency: \(request.context.currencyCode)
- locale: \(request.context.localeIdentifier)
- categoryCandidates: \(request.context.categoryCandidates.joined(separator: ", "))
- paymentMethodCandidates: \(request.context.paymentMethodCandidates.joined(separator: ", "))

请基于 OCR 或图像内容输出严格 JSON。
"""
    }
}

actor AutoLedgerScreenshotCache {
    static let shared = AutoLedgerScreenshotCache()

    private let fileManager: FileManager
    private let folderURL: URL
    private let retentionInterval: TimeInterval = 24 * 60 * 60

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.folderURL = baseURL.appendingPathComponent("AutoLedgerCache", isDirectory: true)

        if !fileManager.fileExists(atPath: folderURL.path) {
            try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
    }

    func save(_ data: Data) throws -> URL {
        try purgeExpired()

        let fileURL = folderURL.appendingPathComponent("capture-\(UUID().uuidString).bin")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func purgeExpired() throws {
        let urls = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.contentModificationDateKey])
        let now = Date()

        for url in urls {
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modified = values.contentModificationDate else { continue }
            if now.timeIntervalSince(modified) > retentionInterval {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    func remove(_ fileURL: URL?) {
        guard let fileURL else { return }
        try? fileManager.removeItem(at: fileURL)
    }
}

@MainActor
final class AutoLedgerViewModel: ObservableObject {
    @Published var selectedTab: AutoLedgerCenterTab = .automatic
    @Published var flowState: AutoLedgerFlowState = .idle
    @Published var reviewDraft: AutoLedgerReviewDraft?
    @Published var errorMessage: String?
    @Published var successMessage: String?

    @Published var isAssistiveTouchExpanded = true
    @Published var isActionButtonExpanded = false
    @Published var isBackTapExpanded = false
    @Published var isControlCenterExpanded = false

    private let service: any AutoLedgerServiceProtocol
    private let screenshotCache: AutoLedgerScreenshotCache
    private var cachedURL: URL?

    init(
        service: any AutoLedgerServiceProtocol = AutoLedgerServiceFactory.make(),
        screenshotCache: AutoLedgerScreenshotCache = .shared
    ) {
        self.service = service
        self.screenshotCache = screenshotCache
    }

    func beginShortcutGuide() {
        errorMessage = nil
        successMessage = nil
        flowState = .awaitingShortcut
    }

    func resetToIdle() {
        flowState = .idle
        reviewDraft = nil
        errorMessage = nil
        successMessage = nil
    }

    func triggerMockShortcutParse(store: LedgerStore) async {
        errorMessage = nil
        successMessage = nil
        flowState = .uploading

        do {
            let fakeReceiptText = "商户:便利店 金额:18.50 支付方式:电子支付"
            let imageData = Data(fakeReceiptText.utf8)
            cachedURL = try await screenshotCache.save(imageData)

            flowState = .parsing
            let request = AutoLedgerParseRequest(
                imageData: imageData,
                context: makeContext(from: store),
                ocrTextHint: fakeReceiptText
            )

            let result = try await service.parseReceipt(request)
            reviewDraft = makeReviewDraft(from: result, store: store)

            if result.amount == nil || result.normalizedKind == nil {
                errorMessage = AutoLedgerServiceError.parseFailed.errorDescription
            } else if result.confidence < 0.65 {
                errorMessage = "识别置信度较低，建议你确认后再保存。"
            }

            flowState = .review
        } catch {
            flowState = .failed
            errorMessage = error.localizedDescription
        }
    }

    func updateDraft(store: LedgerStore, mutate: (inout AutoLedgerReviewDraft) -> Void) {
        guard var draft = reviewDraft else { return }

        mutate(&draft)

        let categories = store.categories(for: draft.kind)
        if !categories.contains(where: { $0.id == draft.categoryID }) {
            draft.categoryID = fallbackCategory(from: categories, kind: draft.kind).id
        }

        let paymentOptions = paymentMethodOptions(in: store)
        if !paymentOptions.contains(draft.paymentMethod) {
            draft.paymentMethod = "待确认"
        }

        reviewDraft = draft
    }

    func paymentMethodOptions(in store: LedgerStore) -> [String] {
        uniqueStrings(store.paymentMethods + ["待确认"])
    }

    func confirmAndSave(store: LedgerStore) {
        guard let draft = reviewDraft else {
            errorMessage = "请先完成识别。"
            return
        }

        guard let amount = draft.parsedAmount, amount > 0 else {
            errorMessage = "金额不合法，请先修正。"
            return
        }

        let categories = store.categories(for: draft.kind)
        let category = categories.first(where: { $0.id == draft.categoryID })
            ?? fallbackCategory(from: categories, kind: draft.kind)

        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let merchant = draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = merchant.isEmpty ? (note.isEmpty ? category.name : note) : merchant

        flowState = .confirmed

        store.addEntry(
            kind: draft.kind,
            amount: amount,
            category: category,
            paymentMethod: draft.paymentMethod,
            note: note,
            title: title,
            date: draft.occurredAt
        )

        flowState = .saved
        successMessage = "已自动入账，可以在首页今日流水查看。"
        errorMessage = nil

        Task { @MainActor in
            await screenshotCache.remove(cachedURL)
            cachedURL = nil
        }
    }

    private func makeContext(from store: LedgerStore) -> AutoLedgerParseContext {
        let categories = LedgerKind.allCases.flatMap { kind in
            store.categories(for: kind).map { "\(kind.rawValue):\($0.name)" }
        }

        return AutoLedgerParseContext(
            currencyCode: "CNY",
            localeIdentifier: LedgerFormatters.locale.identifier,
            categoryCandidates: categories,
            paymentMethodCandidates: store.paymentMethods
        )
    }

    private func makeReviewDraft(from result: AutoLedgerParseResult, store: LedgerStore) -> AutoLedgerReviewDraft {
        let kind = result.normalizedKind ?? .expense
        let categories = store.categories(for: kind)
        let category = mapCategory(from: result.category, categories: categories, kind: kind)

        let paymentMethod = mapPaymentMethod(from: result.paymentMethod, store: store)

        return AutoLedgerReviewDraft(
            amountText: formattedAmountText(result.amount),
            kind: kind,
            categoryID: category.id,
            paymentMethod: paymentMethod,
            occurredAt: result.occurredAt,
            merchant: result.merchant ?? "",
            note: result.note ?? "",
            rawText: result.rawText,
            confidence: result.confidence,
            reason: result.reason
        )
    }

    private func mapCategory(from hint: String?, categories: [LedgerCategory], kind: LedgerKind) -> LedgerCategory {
        guard let hint, !hint.isEmpty else {
            return fallbackCategory(from: categories, kind: kind)
        }

        if let byID = categories.first(where: { $0.id.caseInsensitiveCompare(hint) == .orderedSame }) {
            return byID
        }

        if let byName = categories.first(where: { $0.name.caseInsensitiveCompare(hint) == .orderedSame }) {
            return byName
        }

        return fallbackCategory(from: categories, kind: kind)
    }

    private func fallbackCategory(from categories: [LedgerCategory], kind: LedgerKind) -> LedgerCategory {
        if kind == .expense,
           let expenseOther = categories.first(where: { $0.id == "expense.other" }) {
            return expenseOther
        }

        return categories.first ?? LedgerCategory.defaultCategory(for: kind)
    }

    private func mapPaymentMethod(from hint: String?, store: LedgerStore) -> String {
        guard let hint, !hint.isEmpty else { return "待确认" }

        if let exact = store.paymentMethods.first(where: { $0.caseInsensitiveCompare(hint) == .orderedSame }) {
            return exact
        }

        return "待确认"
    }

    private func formattedAmountText(_ amount: Double?) -> String {
        guard let amount else { return "" }
        return String(format: "%.2f", amount)
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var result: [String] = []

        for value in values where !result.contains(value) {
            result.append(value)
        }

        return result
    }
}
