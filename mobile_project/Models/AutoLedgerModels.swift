import Foundation

enum AutoLedgerCenterTab: String, CaseIterable, Identifiable {
    case automatic = "自动记账"
    case voice = "语音记账"

    var id: String { rawValue }

    var localizedTitle: String {
        rawValue.localized
    }
}

enum AutoLedgerShortcutSetupState: String, Codable, Equatable {
    case notInstalled
    case installGuideShown
    case installedAwaitingValidation
    case ready
    case lastRunFailed

    var title: String {
        switch self {
        case .notInstalled:
            "还没有添加快捷指令".localized
        case .installGuideShown:
            "已打开安装引导".localized
        case .installedAwaitingValidation:
            "已添加，待检查动作链".localized
        case .ready:
            "自动记账已就绪".localized
        case .lastRunFailed:
            "最近一次运行失败".localized
        }
    }

    var summary: String {
        switch self {
        case .notInstalled:
            "先完成快捷指令添加，再继续编辑动作链和绑定触发方式。".localized
        case .installGuideShown:
            "系统快捷指令入口已经准备好了。结构搭好后，就可以直接触发自动识别。".localized
        case .installedAwaitingValidation:
            "建议先检查动作链是否为“截图 -> 从截图获取图像 -> 自动记账”，再做一次真实验证。".localized
        case .ready:
            "快捷指令、动作链和触发方式都已经就位，可以直接开始使用。".localized
        case .lastRunFailed:
            "先回到动作链检查和排障，再重新触发一次自动记账。".localized
        }
    }
}

enum AutoLedgerPreferredTriggerMode: String, CaseIterable, Identifiable, Codable {
    case assistiveTouch
    case actionButton

    var id: String { rawValue }

    var title: String {
        switch self {
        case .assistiveTouch:
            "辅助触控（小白点）".localized
        case .actionButton:
            "操作按钮".localized
        }
    }

    var subtitle: String {
        switch self {
        case .assistiveTouch:
            "适合大多数机型，单击/双击/长按都能绑定。".localized
        case .actionButton:
            "适合支持操作按钮的机型，按一下即可触发。".localized
        }
    }
}

enum AutoLedgerShortcutEducationState: String, CaseIterable, Identifiable, Codable {
    case install
    case edit
    case usage
    case troubleshoot

    var id: String { rawValue }
}

enum AutoLedgerFlowState: String {
    case idle
    case awaitingShortcut
    case uploading
    case parsing
    case review
    case confirmed
    case saved
    case failed
}

struct AutoLedgerParseContext {
    let currencyCode: String
    let localeIdentifier: String
    let categoryCandidates: [String]
    let paymentMethodCandidates: [String]
}

struct VoiceLedgerPromptContext {
    let currencyCode: String
    let localeIdentifier: String
    let categoryCandidates: [String]
    let paymentMethodCandidates: [String]
}

struct AutoLedgerParseRequest {
    let imageData: Data?
    let context: AutoLedgerParseContext
    let ocrTextHint: String?
}

struct VoiceLedgerParseRequest {
    let audioData: Data
    let audioMimeType: String
    let context: VoiceLedgerPromptContext
    let transcriptHint: String?
}

struct AutoLedgerParseEntry: Codable {
    let amount: Double?
    let kind: String?
    let category: String?
    let paymentMethod: String?
    let time: String?
    let merchant: String?
    let note: String?
    let rawText: String
    let confidence: Double
    let reason: String
    let recognizedEntryCount: Int?

    var normalizedKind: LedgerKind? {
        guard let kind else { return nil }

        switch kind.lowercased() {
        case "expense", "支出":
            return .expense
        case "income", "收入":
            return .income
        default:
            return nil
        }
    }

    var occurredAt: Date {
        guard let time else { return Date() }

        if let date = ISO8601DateFormatter().date(from: time) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = LedgerFormatters.locale
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: time) ?? Date()
    }
}

struct AutoLedgerParseEnvelope: Codable {
    let entries: [AutoLedgerParseEntry]
    let recognizedEntryCount: Int?
    let primaryIndex: Int?

    var primaryEntry: AutoLedgerParseEntry? {
        guard !entries.isEmpty else { return nil }
        if let primaryIndex, entries.indices.contains(primaryIndex) {
            return entries[primaryIndex]
        }
        return entries.first
    }

    var totalRecognizedCount: Int {
        recognizedEntryCount ?? entries.count
    }
}

struct AutoLedgerReviewDraft: Identifiable {
    let id = UUID()
    var bookID: UUID?
    var amountText: String
    var kind: LedgerKind
    var categoryID: String
    var accountID: UUID?
    var paymentMethod: String
    var occurredAt: Date
    var merchant: String
    var tags: [String]
    var note: String
    var rawText: String
    var confidence: Double
    var reason: String
    var recognizedEntryCount: Int
    var isExcludedFromStatistics: Bool
    var isExcludedFromBudget: Bool

    var parsedAmount: Double? {
        var cleaned = amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard !cleaned.isEmpty else { return nil }

        let commaCount = cleaned.filter { $0 == "," }.count
        let dotCount = cleaned.filter { $0 == "." }.count

        if commaCount > 0 && dotCount > 0 {
            let lastComma = cleaned.lastIndex(of: ",") ?? cleaned.startIndex
            let lastDot = cleaned.lastIndex(of: ".") ?? cleaned.startIndex
            let decimalSeparator: Character = lastComma > lastDot ? "," : "."
            let groupingSeparator: Character = decimalSeparator == "," ? "." : ","

            cleaned.removeAll { $0 == groupingSeparator }
            if decimalSeparator == "," {
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            }
        } else if commaCount > 0 && dotCount == 0 {
            if commaCount > 1 {
                cleaned.removeAll { $0 == "," }
            } else {
                let parts = cleaned.split(separator: ",")
                if parts.count == 2, parts[1].count != 3 {
                    cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
                } else {
                    cleaned.removeAll { $0 == "," }
                }
            }
        }

        return Double(cleaned)
    }
}

struct AutoLedgerShortcutStatusPresentation {
    let title: String
    let detail: String
    let tint: String
}

struct AutoLedgerDebugSnapshot: Codable {
    let timestamp: Date
    let engine: String
    let endpoint: String?
    let model: String?
    let requestSummary: String
    let rawOCRPreview: String?
    let rawResponse: String?
    let parsedResult: AutoLedgerParseEnvelope?
    let errorMessage: String?
}

struct AutoLedgerOpenAIRequestBody: Encodable {
    let model: String
    let messages: [AutoLedgerOpenAIChatMessage]
    let responseFormat: AutoLedgerOpenAIResponseFormat?
    let extraBody: AutoLedgerOpenAIExtraBody?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
        case extraBody = "extra_body"
    }
}

struct AutoLedgerOpenAIResponseFormat: Encodable {
    let type: String
}

struct AutoLedgerOpenAIExtraBody: Encodable {
    let enableThinking: Bool

    enum CodingKeys: String, CodingKey {
        case enableThinking = "enable_thinking"
    }
}

struct AutoLedgerOpenAIChatMessage: Encodable {
    let role: String
    let content: AutoLedgerOpenAIMessageContent
}

enum AutoLedgerOpenAIMessageContent: Encodable {
    case text(String)
    case parts([AutoLedgerOpenAIContentPart])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value):
            try container.encode(value)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

extension AutoLedgerOpenAIMessageContent {
    var partsValue: [AutoLedgerOpenAIContentPart]? {
        guard case .parts(let parts) = self else { return nil }
        return parts
    }
}

struct AutoLedgerOpenAIContentPart: Encodable {
    let type: String
    let text: String?
    let imageURL: AutoLedgerOpenAIImageURL?
    let inputAudio: AutoLedgerOpenAIInputAudio?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
        case inputAudio = "input_audio"
    }
}

struct AutoLedgerOpenAIImageURL: Encodable {
    let url: String
}

struct AutoLedgerOpenAIInputAudio: Encodable {
    let data: String
    let format: String
}

struct AutoLedgerOpenAIChatResponse: Decodable {
    let choices: [AutoLedgerOpenAIChatChoice]
}

struct AutoLedgerOpenAIChatChoice: Decodable {
    let message: AutoLedgerOpenAIChatMessageResponse
}

struct AutoLedgerOpenAIChatMessageResponse: Decodable {
    let content: String?
}

struct AutoLedgerOpenAIEntryWrapper: Decodable {
    let result: AutoLedgerParseEntry
}

struct AutoLedgerOpenAIEnvelopeWrapper: Decodable {
    let result: AutoLedgerParseEnvelope
}
