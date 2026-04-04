import Foundation

enum AutoLedgerCenterTab: String, CaseIterable, Identifiable {
    case automatic = "自动记账"
    case voice = "语音记账"

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

struct AutoLedgerParseRequest {
    let imageData: Data
    let context: AutoLedgerParseContext
    let ocrTextHint: String?
}

struct AutoLedgerParseResult: Codable {
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

struct AutoLedgerReviewDraft: Identifiable {
    let id = UUID()
    var amountText: String
    var kind: LedgerKind
    var categoryID: String
    var paymentMethod: String
    var occurredAt: Date
    var merchant: String
    var note: String
    var rawText: String
    var confidence: Double
    var reason: String

    var parsedAmount: Double? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}

struct AutoLedgerGatewayRequestBody: Encodable {
    let prompt: String
    let rawOCR: String?
    let imageBase64: String
}

struct AutoLedgerGatewayResponse: Decodable {
    let result: AutoLedgerParseResult?
    let resultJSON: String?

    func normalizedResult() throws -> AutoLedgerParseResult {
        if let result {
            return result
        }

        if let resultJSON,
           let data = resultJSON.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(AutoLedgerParseResult.self, from: data) {
            return parsed
        }

        throw AutoLedgerServiceError.invalidResponse
    }
}
