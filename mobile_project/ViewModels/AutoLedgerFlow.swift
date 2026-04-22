import Foundation
import Vision

enum AutoLedgerRecognitionEngine {
    case gateway
    case local
}

protocol AutoLedgerServiceProtocol {
    var recognitionEngine: AutoLedgerRecognitionEngine { get }
    func parseReceipt(_ request: AutoLedgerParseRequest) async throws -> AutoLedgerParseEnvelope
}

enum AutoLedgerServiceEnvironment {
    case local
    case gateway(AutoLedgerOpenAIConfiguration)
}

enum AutoLedgerServiceError: LocalizedError {
    case invalidResponse
    case networkFailure(Int)
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "服务返回数据格式不正确，请稍后重试。"
        case .networkFailure(let status):
            "网络请求失败（\(status)），请检查后重试。"
        case .parseFailed:
            "识别结果缺少关键字段，暂时还不能自动入账。"
        }
    }
}

struct AutoLedgerServiceFactory {
    static func make(environment: AutoLedgerServiceEnvironment? = nil) -> any AutoLedgerServiceProtocol {
        let resolvedEnvironment = environment ?? configuredEnvironment() ?? .local

        return switch resolvedEnvironment {
        case .local:
            LocalAutoLedgerService()
        case .gateway(let configuration):
            GatewayAutoLedgerService(configuration: configuration)
        }
    }

    private static func configuredEnvironment(bundle: Bundle = .main) -> AutoLedgerServiceEnvironment? {
        guard let configuration = AutoLedgerOpenAIConfiguration.load(bundle: bundle) else {
            return nil
        }

        return .gateway(configuration)
    }
}

struct LocalAutoLedgerService: AutoLedgerServiceProtocol {
    let recognitionEngine: AutoLedgerRecognitionEngine = .local

    func parseReceipt(_ request: AutoLedgerParseRequest) async throws -> AutoLedgerParseEnvelope {
        if let localResult = try await AutoLedgerLocalRecognizer.parse(request) {
            return localResult
        }
        throw AutoLedgerServiceError.parseFailed
    }
}

private struct AutoLedgerDetectedTextLine {
    let text: String
    let midY: CGFloat
    let minX: CGFloat
}

private struct AutoLedgerAmountCandidate {
    let amount: Double
    let lineIndex: Int
    let lineText: String
    let score: Int
}

private enum AutoLedgerOCRTextExtractor {
    static func mergedText(from request: AutoLedgerParseRequest) async -> String {
        var parts: [String] = []

        if let ocrTextHint = request.ocrTextHint?.trimmingCharacters(in: .whitespacesAndNewlines),
           !ocrTextHint.isEmpty {
            parts.append(ocrTextHint)
        }

        if let imageData = request.imageData,
           let recognizedText = await recognizeText(in: imageData),
           !recognizedText.isEmpty {
            parts.append(recognizedText)
        }

        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func recognizeText(in imageData: Data) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = false
                    request.recognitionLanguages = ["zh-Hans", "en-US"]

                    let handler = VNImageRequestHandler(data: imageData, options: [:])
                    try handler.perform([request])

                    let observations = (request.results ?? [])
                        .compactMap { observation -> AutoLedgerDetectedTextLine? in
                            guard let candidate = observation.topCandidates(1).first else { return nil }
                            return AutoLedgerDetectedTextLine(
                                text: candidate.string,
                                midY: observation.boundingBox.midY,
                                minX: observation.boundingBox.minX)
                        }
                        .sorted {
                            let verticalDelta = abs($0.midY - $1.midY)
                            if verticalDelta > 0.025 {
                                return $0.midY > $1.midY
                            }
                            return $0.minX < $1.minX
                        }

                    continuation.resume(returning: observations.map(\.text).joined(separator: "\n"))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

private enum AutoLedgerLocalRecognizer {
    private static let amountRegex = try! NSRegularExpression(
        pattern: "(?:[¥￥]\\s*)?([0-9]+(?:,[0-9]{3})*(?:\\.[0-9]{1,2})|[0-9]+(?:\\.[0-9]{1,2}))")
    private static let fullDateTimeFormats = [
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy/M/d HH:mm:ss",
        "yyyy/M/d HH:mm",
        "yyyy年M月d日 HH:mm:ss",
        "yyyy年M月d日 HH:mm"
    ]

    static func parse(_ request: AutoLedgerParseRequest) async throws -> AutoLedgerParseEnvelope? {
        let mergedText = await AutoLedgerOCRTextExtractor.mergedText(from: request)
        let lines = normalizedLines(from: mergedText)

        guard !lines.isEmpty else { return nil }

        let amountCandidates = amountCandidates(from: lines)
        let primaryCandidate = amountCandidates.sorted {
            if $0.score == $1.score {
                return $0.lineIndex < $1.lineIndex
            }
            return $0.score > $1.score
        }.first

        let fullText = lines.joined(separator: "\n")
        let kind = detectKind(in: fullText)
        let recognizedEntryCount = max(1, amountCandidates.filter { $0.score >= 3 }.count)
        let merchant = detectMerchant(around: primaryCandidate?.lineIndex, lines: lines)
        let paymentMethod = detectPaymentMethod(in: fullText)
        let category = detectCategory(in: [merchant, fullText].compactMap { $0 }.joined(separator: "\n"), kind: kind)
        let occurredAt = detectOccurredAt(around: primaryCandidate?.lineIndex, lines: lines) ?? Date()
        let reason = buildReason(
            amountCandidate: primaryCandidate,
            merchant: merchant,
            paymentMethod: paymentMethod,
            recognizedEntryCount: recognizedEntryCount)
        let note = buildNote(
            merchant: merchant,
            kind: kind,
            recognizedEntryCount: recognizedEntryCount)
        let confidence = buildConfidence(
            amountCandidate: primaryCandidate,
            merchant: merchant,
            paymentMethod: paymentMethod,
            category: category,
            recognizedEntryCount: recognizedEntryCount)

        guard let primaryCandidate else { return nil }

        let entry = AutoLedgerParseEntry(
            amount: primaryCandidate.amount,
            kind: kind.rawValue,
            category: category,
            paymentMethod: paymentMethod,
            time: ISO8601DateFormatter().string(from: occurredAt),
            merchant: merchant,
            note: note,
            rawText: lines.prefix(24).joined(separator: "\n"),
            confidence: confidence,
            reason: reason,
            recognizedEntryCount: recognizedEntryCount)

        return AutoLedgerParseEnvelope(
            entries: [entry],
            recognizedEntryCount: recognizedEntryCount,
            primaryIndex: 0)
    }

    private static func normalizedLines(from text: String) -> [String] {
        var lines: [String] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let normalized = rawLine
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
                .replacingOccurrences(of: "：", with: ":")
                .replacingOccurrences(of: "￥", with: "¥")
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard normalized.count >= 2 else { continue }
            guard lines.last != normalized else { continue }
            lines.append(normalized)
        }

        return lines
    }

    private static func amountCandidates(from lines: [String]) -> [AutoLedgerAmountCandidate] {
        var candidates: [AutoLedgerAmountCandidate] = []

        for (lineIndex, lineText) in lines.enumerated() {
            guard shouldInspectAmount(in: lineText) else { continue }

            for amount in extractAmounts(from: lineText) {
                let score = scoreAmountLine(lineText, amount: amount)
                guard score >= 2 else { continue }

                candidates.append(
                    AutoLedgerAmountCandidate(
                        amount: amount,
                        lineIndex: lineIndex,
                        lineText: lineText,
                        score: score))
            }
        }

        return deduplicatedAmountCandidates(candidates)
    }

    private static func deduplicatedAmountCandidates(_ candidates: [AutoLedgerAmountCandidate])
        -> [AutoLedgerAmountCandidate] {
        var seenKeys = Set<String>()
        var result: [AutoLedgerAmountCandidate] = []

        for candidate in candidates {
            let key = "\(candidate.lineIndex)-\(String(format: "%.2f", candidate.amount))"
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            result.append(candidate)
        }

        return result
    }

    private static func shouldInspectAmount(in line: String) -> Bool {
        let ignoredKeywords = [
            "汇率", "市场汇率", "交易汇率", "港币", "人民币", "1港币", "HKD", "CNY",
            "优惠", "折扣", "标价", "关于此快捷指令", "添加快捷指令", "自动记账", "允许"
        ]

        return ignoredKeywords.allSatisfy { !line.localizedCaseInsensitiveContains($0) }
    }

    private static func extractAmounts(from line: String) -> [Double] {
        let range = NSRange(line.startIndex..., in: line)
        let matches = amountRegex.matches(in: line, options: [], range: range)

        return matches.compactMap { match in
            guard match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: line) else { return nil }
            let rawValue = line[valueRange]
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "¥", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let amount = Double(rawValue), amount >= 1 else { return nil }
            return amount
        }
    }

    private static func scoreAmountLine(_ line: String, amount: Double) -> Int {
        var score = 0

        if line.contains("¥") || line.contains("￥") {
            score += 4
        }

        if ["支付", "收款", "付款", "账单详情", "总计", "合计", "实付", "支出", "收入"].contains(where: line.contains) {
            score += 3
        }

        if line.count <= 18 {
            score += 1
        }

        if amount >= 1, amount <= 50000 {
            score += 1
        }

        if ["汇率", "港币", "人民币", "优惠", "标价", "折扣", "="].contains(where: line.contains) {
            score -= 4
        }

        return score
    }

    private static func detectKind(in text: String) -> LedgerKind {
        if ["退款", "退回", "回款", "收入", "退款成功"].contains(where: text.localizedCaseInsensitiveContains) {
            return .income
        }

        return .expense
    }

    private static func detectPaymentMethod(in text: String) -> String {
        if ["微信零钱", "微信支付", "微信"].contains(where: text.localizedCaseInsensitiveContains) {
            return "微信"
        }

        if ["支付宝", "Alipay"].contains(where: text.localizedCaseInsensitiveContains) {
            return "支付宝"
        }

        if ["银行卡", "信用卡", "储蓄卡", "Mastercard", "Visa"].contains(where: text.localizedCaseInsensitiveContains) {
            return "银行卡"
        }

        if ["现金", "Cash"].contains(where: text.localizedCaseInsensitiveContains) {
            return "现金"
        }

        return "待确认"
    }

    private static func detectCategory(in text: String, kind: LedgerKind) -> String? {
        if kind == .income, text.localizedCaseInsensitiveContains("退款") {
            return "退款"
        }

        let categoryMappings: [(String, [String])] = [
            ("餐饮", ["KFC", "麦当劳", "星巴克", "奶茶", "咖啡", "餐", "外卖", "饮品", "面", "饭"]),
            ("交通", ["地铁", "打车", "公交", "滴滴", "高铁", "火车", "停车", "加油"]),
            ("购物", ["淘宝", "京东", "商场", "购物", "超市", "便利店"]),
            ("住房", ["房租", "物业", "水费", "电费", "燃气"]),
            ("娱乐", ["电影", "游戏", "门票", "演出"]),
            ("医疗", ["医院", "诊所", "药房", "药店"])
        ]

        for (category, keywords) in categoryMappings {
            if keywords.contains(where: text.localizedCaseInsensitiveContains) {
                return category
            }
        }

        return nil
    }

    private static func detectMerchant(around lineIndex: Int?, lines: [String]) -> String? {
        let anchor = lineIndex ?? 0
        let candidateIndexes = Array(max(0, anchor - 4)...min(lines.count - 1, anchor + 3))

        let candidates = candidateIndexes.compactMap { index -> (text: String, score: Int)? in
            let line = lines[index]
            guard isMerchantCandidate(line) else { return nil }

            var score = 6 - abs(index - anchor)
            if containsReadableMerchantCharacters(line) {
                score += 2
            }

            if index < anchor {
                score += 1
            }

            return (line, score)
        }

        return candidates.sorted {
            if $0.score == $1.score {
                return $0.text.count < $1.text.count
            }
            return $0.score > $1.score
        }.first?.text
    }

    private static func isMerchantCandidate(_ line: String) -> Bool {
        if line.count < 2 || line.count > 36 {
            return false
        }

        if extractAmounts(from: line).isEmpty == false || detectExplicitTime(in: line) != nil {
            return false
        }

        let ignoredKeywords = [
            "微信支付", "支付宝", "账单详情", "标价", "交易汇率", "市场汇率",
            "自动记账", "完成", "查看更多", "全球有礼", "支付服务", "我的账单"
        ]

        return ignoredKeywords.allSatisfy { !line.localizedCaseInsensitiveContains($0) }
    }

    private static func containsReadableMerchantCharacters(_ line: String) -> Bool {
        line.unicodeScalars.contains { scalar in
            CharacterSet.letters.contains(scalar)
                || (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }

    private static func detectOccurredAt(around lineIndex: Int?, lines: [String]) -> Date? {
        let anchor = lineIndex ?? 0
        let candidateIndexes = Array(max(0, anchor - 5)...min(lines.count - 1, anchor + 2))

        for index in candidateIndexes {
            if let date = detectExplicitTime(in: lines[index]) {
                return date
            }
        }

        return nil
    }

    private static func detectExplicitTime(in line: String) -> Date? {
        if let fullDate = firstMatch(
            pattern: "(20\\d{2}[-/年.]\\d{1,2}[-/月.]\\d{1,2}(?:日)?\\s+\\d{1,2}:\\d{2}(?::\\d{2})?)",
            in: line) {
            return parseDateTime(fullDate)
        }

        guard let timeString = firstMatch(pattern: "(\\b\\d{1,2}:\\d{2}(?::\\d{2})?\\b)", in: line) else {
            return nil
        }

        return mergeToday(with: timeString)
    }

    private static func parseDateTime(_ rawValue: String) -> Date? {
        let cleaned = rawValue
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: "日", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")

        for format in fullDateTimeFormats {
            let formatter = DateFormatter()
            formatter.locale = LedgerFormatters.locale
            formatter.timeZone = .current
            formatter.dateFormat = format

            if let date = formatter.date(from: rawValue) ?? formatter.date(from: cleaned) {
                return date
            }
        }

        return nil
    }

    private static func mergeToday(with rawTime: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = LedgerFormatters.locale
        formatter.timeZone = .current
        formatter.dateFormat = rawTime.count > 5 ? "HH:mm:ss" : "HH:mm"

        guard let time = formatter.date(from: rawTime) else { return nil }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: time)
        return calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            of: Date())
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let matchedRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[matchedRange])
    }

    private static func buildReason(
        amountCandidate: AutoLedgerAmountCandidate?,
        merchant: String?,
        paymentMethod: String,
        recognizedEntryCount: Int) -> String {
        var parts: [String] = []

        if let amountCandidate {
            parts.append("命中金额行“\(amountCandidate.lineText)”")
        }

        if let merchant, !merchant.isEmpty {
            parts.append("推断商户为“\(merchant)”")
        }

        if paymentMethod != "待确认" {
            parts.append("支付方式识别为\(paymentMethod)")
        }

        if recognizedEntryCount > 1 {
            parts.append("截图中疑似存在\(recognizedEntryCount)笔候选记录，当前优先带出最可信的一笔")
        }

        return parts.isEmpty ? "已根据截图文本生成待确认草稿。" : parts.joined(separator: "，")
    }

    private static func buildNote(merchant: String?, kind: LedgerKind, recognizedEntryCount: Int) -> String {
        if kind == .income {
            return recognizedEntryCount > 1 ? "自动识别：截图中存在多笔记录，当前优先处理一笔收入" : "自动识别：截图收入记录"
        }

        if let merchant, !merchant.isEmpty {
            return recognizedEntryCount > 1 ? "自动识别：\(merchant) 等 \(recognizedEntryCount) 笔候选记录" : "自动识别：\(merchant)"
        }

        return recognizedEntryCount > 1 ? "自动识别：截图中存在多笔候选记录" : "自动识别：支付截图"
    }

    private static func buildConfidence(
        amountCandidate: AutoLedgerAmountCandidate?,
        merchant: String?,
        paymentMethod: String,
        category: String?,
        recognizedEntryCount: Int) -> Double {
        var score = 0.42

        if let amountCandidate {
            score += min(Double(amountCandidate.score) * 0.05, 0.28)
        }

        if let merchant, !merchant.isEmpty {
            score += 0.12
        }

        if paymentMethod != "待确认" {
            score += 0.08
        }

        if category != nil {
            score += 0.06
        }

        if recognizedEntryCount > 1 {
            score += 0.04
        }

        return min(score, 0.96)
    }
}

final class GatewayAutoLedgerService: AutoLedgerServiceProtocol {
    private let configuration: AutoLedgerOpenAIConfiguration
    let recognitionEngine: AutoLedgerRecognitionEngine = .gateway
    var debugEndpoint: String { configuration.endpoint.absoluteString }
    var debugModel: String { configuration.model }

    init(configuration: AutoLedgerOpenAIConfiguration) {
        self.configuration = configuration
    }

    func parseReceipt(_ request: AutoLedgerParseRequest) async throws -> AutoLedgerParseEnvelope {
        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let mergedOCRText = await AutoLedgerOCRTextExtractor.mergedText(from: request)
        let payload = configuration.makeRequestBody(
            for: request,
            rawOCR: mergedOCRText.isEmpty ? nil : mergedOCRText)
        urlRequest.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let rawResponseText = String(data: data, encoding: .utf8)

        guard let http = response as? HTTPURLResponse else {
            AutoLedgerHandoffStore.saveDebugSnapshot(
                AutoLedgerDebugSnapshot(
                    timestamp: Date(),
                    engine: "openai",
                    endpoint: configuration.endpoint.absoluteString,
                    model: configuration.model,
                    requestSummary: "status=invalid-http-response",
                    rawOCRPreview: mergedOCRText.isEmpty ? nil : String(mergedOCRText.prefix(800)),
                    rawResponse: rawResponseText,
                    parsedResult: nil,
                    errorMessage: AutoLedgerServiceError.invalidResponse.localizedDescription))
            throw AutoLedgerServiceError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            AutoLedgerHandoffStore.saveDebugSnapshot(
                AutoLedgerDebugSnapshot(
                    timestamp: Date(),
                    engine: "openai",
                    endpoint: configuration.endpoint.absoluteString,
                    model: configuration.model,
                    requestSummary: "status=\(http.statusCode)",
                    rawOCRPreview: mergedOCRText.isEmpty ? nil : String(mergedOCRText.prefix(800)),
                    rawResponse: rawResponseText,
                    parsedResult: nil,
                    errorMessage: AutoLedgerServiceError.networkFailure(http.statusCode).localizedDescription))
            throw AutoLedgerServiceError.networkFailure(http.statusCode)
        }

        if let decoded = try? JSONDecoder().decode(AutoLedgerOpenAIChatResponse.self, from: data),
           let messageContent = decoded.choices.first?.message.content,
           let result = parseOpenAIResult(from: messageContent) {
            AutoLedgerHandoffStore.saveDebugSnapshot(
                AutoLedgerDebugSnapshot(
                    timestamp: Date(),
                    engine: "openai",
                    endpoint: configuration.endpoint.absoluteString,
                    model: configuration.model,
                    requestSummary: "status=\(http.statusCode)",
                    rawOCRPreview: mergedOCRText.isEmpty ? nil : String(mergedOCRText.prefix(800)),
                    rawResponse: rawResponseText,
                    parsedResult: result,
                    errorMessage: nil))
            return result
        }

        if let directResult = try? JSONDecoder().decode(AutoLedgerParseEnvelope.self, from: data) {
            AutoLedgerHandoffStore.saveDebugSnapshot(
                AutoLedgerDebugSnapshot(
                    timestamp: Date(),
                    engine: "openai",
                    endpoint: configuration.endpoint.absoluteString,
                    model: configuration.model,
                    requestSummary: "status=\(http.statusCode)",
                    rawOCRPreview: mergedOCRText.isEmpty ? nil : String(mergedOCRText.prefix(800)),
                    rawResponse: rawResponseText,
                    parsedResult: directResult,
                    errorMessage: nil))
            return directResult
        }

        AutoLedgerHandoffStore.saveDebugSnapshot(
            AutoLedgerDebugSnapshot(
                timestamp: Date(),
                engine: "openai",
                endpoint: configuration.endpoint.absoluteString,
                model: configuration.model,
                requestSummary: "status=\(http.statusCode)",
                rawOCRPreview: mergedOCRText.isEmpty ? nil : String(mergedOCRText.prefix(800)),
                rawResponse: rawResponseText,
                parsedResult: nil,
                errorMessage: AutoLedgerServiceError.invalidResponse.localizedDescription))
        throw AutoLedgerServiceError.invalidResponse
    }

    private func parseOpenAIResult(from messageContent: String) -> AutoLedgerParseEnvelope? {
        let trimmed = messageContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return nil }

        if let parsed = try? JSONDecoder().decode(AutoLedgerParseEnvelope.self, from: data) {
            return parsed
        }

        if let wrapped = try? JSONDecoder().decode(AutoLedgerOpenAIEnvelopeWrapper.self, from: data) {
            return wrapped.result
        }

        if let wrapped = try? JSONDecoder().decode(AutoLedgerOpenAIEntryWrapper.self, from: data) {
            return AutoLedgerParseEnvelope(
                entries: [wrapped.result],
                recognizedEntryCount: wrapped.result.recognizedEntryCount,
                primaryIndex: 0)
        }

        if let parsed = try? JSONDecoder().decode(AutoLedgerParseEntry.self, from: data) {
            return AutoLedgerParseEnvelope(
                entries: [parsed],
                recognizedEntryCount: parsed.recognizedEntryCount,
                primaryIndex: 0)
        }

        return nil
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
        let urls = try fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey])
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
    @Published var shortcutStatus: AutoLedgerShortcutRunStatus = AutoLedgerHandoffStore.loadStatus()
    @Published var debugSnapshot: AutoLedgerDebugSnapshot? = AutoLedgerHandoffStore.loadDebugSnapshot()

    private let service: any AutoLedgerServiceProtocol
    private let screenshotCache: AutoLedgerScreenshotCache
    private var cachedURL: URL?
    private var activeFlowSource: AutoLedgerShortcutSource?
    private var lastParseEnvelope: AutoLedgerParseEnvelope?
    private var lastRecognizedImageData: Data?
    private var lastRecognizedOCRTextHint: String?

    init(
        service: any AutoLedgerServiceProtocol = AutoLedgerServiceFactory.make(),
        screenshotCache: AutoLedgerScreenshotCache = .shared) {
        self.service = service
        self.screenshotCache = screenshotCache
    }

    var recognitionEngine: AutoLedgerRecognitionEngine {
        service.recognitionEngine
    }

    var recognitionEngineTitle: String {
        switch recognitionEngine {
        case .gateway:
            "大模型 API 识别"
        case .local:
            "本地识别兜底"
        }
    }

    var recognitionEngineSubtitle: String {
        switch recognitionEngine {
        case .gateway:
            "快捷指令会直接完成识别与自动入账，截图和 OCR 会一起交给 OpenAI 接口。"
        case .local:
            "当前还没配置大模型识别，先使用本地 OCR 兜底。把 OPENAI 配置补齐后会优先切到 API 识别。"
        }
    }

    func beginShortcutGuide() {
        refreshShortcutStatus()
        errorMessage = nil
        successMessage = nil
        reviewDraft = nil
        flowState = .awaitingShortcut
    }

    func resetToIdle() {
        flowState = .idle
        reviewDraft = nil
        errorMessage = nil
        successMessage = nil
        activeFlowSource = nil
        lastParseEnvelope = nil
    }

    func processPendingLaunchIfNeeded(store: LedgerStore) async {
        guard let payload = store.consumeAutoLedgerPendingLaunch() else {
            refreshShortcutStatus()
            return
        }

        let normalizedOCRText = payload.ocrTextHint?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasConsumableInput = payload.imageFilename != nil || !(normalizedOCRText?.isEmpty ?? true)

        if !hasConsumableInput, let educationState = payload.educationState {
            presentEducationState(educationState, from: payload.source, store: store)
            refreshShortcutStatus()
            return
        }

        do {
            let imageData = try AutoLedgerHandoffStore.consumeImageData(for: payload)
            try await startReviewFlow(
                imageData: imageData,
                ocrTextHint: normalizedOCRText,
                source: payload.source,
                store: store)
            try persistRecognizedDraft(store: store)
        } catch {
            flowState = .failed
            errorMessage = error.localizedDescription
            AutoLedgerHandoffStore.markLastRunFailed(error.localizedDescription)
            refreshShortcutStatus()
        }
    }

    func retryLastRecognition(store: LedgerStore) async {
        guard lastRecognizedImageData != nil || !(lastRecognizedOCRTextHint?.isEmpty ?? true) else {
            flowState = .idle
            errorMessage = "还没有可重试的截图。请先回到支付页截图并运行自动记账。"
            return
        }

        do {
            try await startReviewFlow(
                imageData: lastRecognizedImageData,
                ocrTextHint: lastRecognizedOCRTextHint,
                source: activeFlowSource ?? .shortcutsApp,
                store: store)
            try persistRecognizedDraft(store: store)
        } catch {
            flowState = .failed
            errorMessage = error.localizedDescription
            AutoLedgerHandoffStore.markLastRunFailed(error.localizedDescription)
            refreshShortcutStatus()
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
        do {
            try persistRecognizedDraft(store: store)
        } catch {
            flowState = .failed
            errorMessage = error.localizedDescription
            AutoLedgerHandoffStore.markLastRunFailed(error.localizedDescription)
            refreshShortcutStatus()
        }
    }

    func refreshShortcutStatus() {
        shortcutStatus = AutoLedgerHandoffStore.loadStatus()
        debugSnapshot = AutoLedgerHandoffStore.loadDebugSnapshot()
    }

    func shortcutSetupState(in store: LedgerStore) -> AutoLedgerShortcutSetupState {
        if let lastErrorMessage = shortcutStatus.lastErrorMessage, !lastErrorMessage.isEmpty {
            return .lastRunFailed
        }

        if shortcutStatus.lastTriggeredAt != nil {
            return .ready
        }

        if store.appSettings.hasAcknowledgedShortcutInstall {
            return .installedAwaitingValidation
        }

        if store.appSettings.hasSeenShortcutInstallGuide {
            return .installGuideShown
        }

        return .notInstalled
    }

    var shortcutStatusPresentation: AutoLedgerShortcutStatusPresentation {
        if let lastErrorMessage = shortcutStatus.lastErrorMessage, !lastErrorMessage.isEmpty {
            return AutoLedgerShortcutStatusPresentation(
                title: "最近一次触发失败",
                detail: lastErrorMessage,
                tint: "error")
        }

        if let lastTriggeredAt = shortcutStatus.lastTriggeredAt,
           let source = shortcutStatus.lastSource {
            let completionText = if let lastCompletedAt = shortcutStatus.lastCompletedAt,
                                    lastCompletedAt >= lastTriggeredAt {
                "，已完成一次自动入账"
            } else {
                "，正在完成识别"
            }

            return AutoLedgerShortcutStatusPresentation(
                title: "已检测到快捷动作可用",
                detail: "\(LedgerFormatters.shortTimestamp(lastTriggeredAt)) 通过\(source.displayName)触发\(completionText)",
                tint: "success")
        }

        return AutoLedgerShortcutStatusPresentation(
            title: "还没有快捷动作记录",
            detail: "先在快捷指令里按“截图 -> 从截图获取图像 -> 识别账单”搭好链路，再绑定到辅助触控或操作按钮。",
            tint: "idle")
    }

    private func makeContext(from store: LedgerStore) -> AutoLedgerParseContext {
        let categories = LedgerKind.allCases.flatMap { kind in
            store.categories(for: kind).map { "\(kind.rawValue):\($0.name)" }
        }

        return AutoLedgerParseContext(
            currencyCode: "CNY",
            localeIdentifier: LedgerFormatters.locale.identifier,
            categoryCandidates: categories,
            paymentMethodCandidates: store.paymentMethods)
    }

    private func makeReviewDraft(
        from entry: AutoLedgerParseEntry,
        recognizedEntryCount: Int,
        store: LedgerStore) -> AutoLedgerReviewDraft {
        let kind = entry.normalizedKind ?? .expense
        let categories = store.categories(for: kind)
        let category = mapCategory(from: entry.category, categories: categories, kind: kind)

        let paymentMethod = mapPaymentMethod(from: entry.paymentMethod, store: store)
        let accountID = store.matchingAccountID(for: paymentMethod)

        return AutoLedgerReviewDraft(
            bookID: store.currentBook.id,
            amountText: formattedAmountText(entry.amount),
            kind: kind,
            categoryID: category.id,
            accountID: accountID,
            paymentMethod: paymentMethod,
            occurredAt: entry.occurredAt,
            merchant: entry.merchant ?? "",
            tags: [],
            note: entry.note ?? "",
            rawText: entry.rawText,
            confidence: entry.confidence,
            reason: entry.reason,
            recognizedEntryCount: max(1, recognizedEntryCount),
            isExcludedFromStatistics: false,
            isExcludedFromBudget: false)
    }

    private func mapCategory(from hint: String?, categories: [LedgerCategory], kind: LedgerKind) -> LedgerCategory {
        guard let hint, !hint.isEmpty else {
            return fallbackCategory(from: categories, kind: kind)
        }

        let normalizedHint = normalizedLookupText(hint)

        if let byID = categories.first(where: { $0.id.caseInsensitiveCompare(hint) == .orderedSame }) {
            return byID
        }

        if let byName = categories.first(where: { $0.name.caseInsensitiveCompare(hint) == .orderedSame }) {
            return byName
        }

        if let fuzzy = categories.first(where: {
            let normalizedCategoryName = normalizedLookupText($0.name)
            return normalizedCategoryName.contains(normalizedHint) || normalizedHint.contains(normalizedCategoryName)
        }) {
            return fuzzy
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

        if hint.localizedCaseInsensitiveContains("微信") {
            return store.paymentMethods.first(where: { $0.localizedCaseInsensitiveContains("微信") }) ?? "微信"
        }

        if hint.localizedCaseInsensitiveContains("支付宝") {
            return store.paymentMethods.first(where: { $0.localizedCaseInsensitiveContains("支付宝") }) ?? "支付宝"
        }

        if ["银行卡", "信用卡", "储蓄卡", "visa", "mastercard"].contains(where: hint.localizedCaseInsensitiveContains) {
            return store.paymentMethods.first(where: {
                ["银行卡", "信用卡", "储蓄卡"].contains(where: $0.localizedCaseInsensitiveContains)
            }) ?? "银行卡"
        }

        if ["现金", "cash"].contains(where: hint.localizedCaseInsensitiveContains) {
            return store.paymentMethods.first(where: { $0.localizedCaseInsensitiveContains("现金") }) ?? "现金"
        }

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

    private func normalizedLookupText(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "类", with: "")
            .replacingOccurrences(of: "消费", with: "")
            .replacingOccurrences(of: "支出", with: "")
            .replacingOccurrences(of: "收入", with: "")
    }

    private func presentEducationState(
        _ educationState: AutoLedgerShortcutEducationState,
        from source: AutoLedgerShortcutSource,
        store: LedgerStore) {
        reviewDraft = nil
        errorMessage = nil
        activeFlowSource = nil
        store.appSettings.hasSeenShortcutInstallGuide = true
        store.appSettings.lastShortcutEducationState = educationState

        switch educationState {
        case .install:
            flowState = .idle
            successMessage = "我已带你回到自动记账中心，先按“截图 -> 从截图获取图像 -> 识别账单”把快捷指令搭好。"
        case .edit:
            flowState = store.appSettings.hasAcknowledgedShortcutInstall ? .awaitingShortcut : .idle
            successMessage = "这个动作必须放在“截图”之后运行。我已带你回到快捷指令结构说明。"
        case .usage:
            flowState = .awaitingShortcut
            successMessage = "下一步是在支付页截图并触发快捷指令，快捷指令会直接完成识别并入账。"
        case .troubleshoot:
            flowState = .failed
            successMessage = nil
            errorMessage = "我已带你回到排障说明，请先检查快捷指令结构和截图输入。"
        }

        if source != .inAppDemo {
            refreshShortcutStatus()
        }
    }

    private func startReviewFlow(
        imageData: Data?,
        ocrTextHint: String?,
        source: AutoLedgerShortcutSource,
        store: LedgerStore) async throws {
        errorMessage = nil
        successMessage = nil
        flowState = .uploading
        activeFlowSource = source

        let normalizedImageData = imageData?.isEmpty == false ? imageData : nil
        let normalizedOCRTextHint = ocrTextHint?.trimmingCharacters(in: .whitespacesAndNewlines)
        lastRecognizedImageData = normalizedImageData
        lastRecognizedOCRTextHint = normalizedOCRTextHint

        if normalizedImageData == nil, normalizedOCRTextHint?.isEmpty ?? true {
            throw AutoLedgerServiceError.parseFailed
        }

        if let normalizedImageData {
            cachedURL = try await screenshotCache.save(normalizedImageData)
        } else {
            cachedURL = nil
        }

        flowState = .parsing
        let request = AutoLedgerParseRequest(
            imageData: normalizedImageData,
            context: makeContext(from: store),
            ocrTextHint: normalizedOCRTextHint)

        let result = try await service.parseReceipt(request)
        lastParseEnvelope = result
        guard let primaryEntry = result.primaryEntry else {
            throw AutoLedgerServiceError.parseFailed
        }

        reviewDraft = makeReviewDraft(
            from: primaryEntry,
            recognizedEntryCount: result.totalRecognizedCount,
            store: store)

        guard primaryEntry.amount != nil else {
            throw AutoLedgerServiceError.parseFailed
        }

        flowState = .review
        refreshShortcutStatus()
    }

    private func persistRecognizedDraft(store: LedgerStore) throws {
        guard let draft = reviewDraft else {
            throw AutoLedgerServiceError.parseFailed
        }

        guard let amount = draft.parsedAmount, amount > 0 else {
            throw AutoLedgerServiceError.parseFailed
        }

        flowState = .confirmed
        let screenshotData = store.appSettings.showRecordImages ? lastRecognizedImageData : nil
        let parsedEntries = lastParseEnvelope?.entries ?? []
        let primaryIndex = lastParseEnvelope?.primaryIndex ?? 0

        var createdEntries: [LedgerEntry] = []

        if parsedEntries.count > 1 {
            var savedCount = 0

            for (index, entry) in parsedEntries.enumerated() {
                if index == primaryIndex {
                    if let createdEntry = saveReviewedDraft(
                        draft,
                        amount: amount,
                        into: store,
                        screenshotData: screenshotData) {
                        createdEntries.append(createdEntry)
                        savedCount += 1
                    }
                    continue
                }

                guard let createdEntry = saveParsedEntry(
                    entry,
                    into: store,
                    screenshotData: screenshotData) else {
                    continue
                }

                createdEntries.append(createdEntry)
                savedCount += 1
            }

            let summaryTitles = createdEntries
                .prefix(3)
                .map(\.title)
                .joined(separator: "、")
            successMessage = summaryTitles.isEmpty
                ? "已自动入账 \(savedCount) 笔。"
                : "已自动入账 \(savedCount) 笔：\(summaryTitles)。"
        } else {
            let category = resolvedCategory(from: draft, store: store)
            let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
            let merchant = draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = merchant.isEmpty ? (note.isEmpty ? category.name : note) : merchant

            let createdEntry = store.addEntry(
                bookID: draft.bookID ?? store.currentBook.id,
                title: title,
                amount: amount,
                kind: draft.kind,
                category: category,
                accountID: draft.accountID ?? store.matchingAccountID(for: draft.paymentMethod),
                paymentMethod: draft.paymentMethod,
                tags: draft.tags,
                note: note,
                date: draft.occurredAt,
                isExcludedFromStatistics: draft.isExcludedFromStatistics,
                isExcludedFromBudget: draft.isExcludedFromBudget,
                screenshotData: screenshotData)
            createdEntries = [createdEntry]

            var savedSummary = "已自动入账：\(LedgerFormatters.currency(amount))"
            if !merchant.isEmpty {
                savedSummary += " · \(merchant)"
            } else {
                savedSummary += " · \(category.name)"
            }

            if draft.recognizedEntryCount > 1 {
                savedSummary += "。这次从多笔候选里优先选了最可信的一笔。"
            } else if draft.confidence < 0.65 {
                savedSummary += "。识别置信度偏低，如有偏差可去流水里修改。"
            } else {
                savedSummary += "。"
            }

            successMessage = savedSummary
        }

        flowState = .saved
        errorMessage = nil
        store.appSettings.hasAcknowledgedShortcutInstall = true
        store.appSettings.lastShortcutEducationState = .usage

        Task { @MainActor in
            await screenshotCache.remove(cachedURL)
            cachedURL = nil
        }

        if let activeFlowSource, activeFlowSource != .inAppDemo {
            AutoLedgerHandoffStore.markLastRunSucceeded()
        }
        refreshShortcutStatus()
    }

    private func saveReviewedDraft(
        _ draft: AutoLedgerReviewDraft,
        amount: Double,
        into store: LedgerStore,
        screenshotData: Data?) -> LedgerEntry? {
        let category = resolvedCategory(from: draft, store: store)
        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let merchant = draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = merchant.isEmpty ? (note.isEmpty ? category.name : note) : merchant

        return store.addEntry(
            bookID: draft.bookID ?? store.currentBook.id,
            title: title,
            amount: amount,
            kind: draft.kind,
            category: category,
            accountID: draft.accountID ?? store.matchingAccountID(for: draft.paymentMethod),
            paymentMethod: draft.paymentMethod,
            tags: draft.tags,
            note: note,
            date: draft.occurredAt,
            isExcludedFromStatistics: draft.isExcludedFromStatistics,
            isExcludedFromBudget: draft.isExcludedFromBudget,
            screenshotData: screenshotData)
    }

    private func saveParsedEntry(
        _ entry: AutoLedgerParseEntry,
        into store: LedgerStore,
        screenshotData: Data?) -> LedgerEntry? {
        guard let amount = entry.amount, amount > 0 else { return nil }

        let kind = entry.normalizedKind ?? .expense
        let categories = store.categories(for: kind)
        let category = mapCategory(from: entry.category, categories: categories, kind: kind)
        let paymentMethod = mapPaymentMethod(from: entry.paymentMethod, store: store)
        let merchant = (entry.merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let note = (entry.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let title = merchant.isEmpty ? (note.isEmpty ? category.name : note) : merchant

        return store.addEntry(
            kind: kind,
            amount: amount,
            category: category,
            accountID: store.matchingAccountID(for: paymentMethod),
            paymentMethod: paymentMethod,
            note: note,
            title: title,
            date: entry.occurredAt,
            screenshotData: screenshotData)
    }

    private func resolvedCategory(from draft: AutoLedgerReviewDraft, store: LedgerStore) -> LedgerCategory {
        let categories = store.categories(for: draft.kind)
        return categories.first(where: { $0.id == draft.categoryID })
            ?? fallbackCategory(from: categories, kind: draft.kind)
    }
}
