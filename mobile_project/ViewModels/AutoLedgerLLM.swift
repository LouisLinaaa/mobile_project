import Foundation

struct AutoLedgerLLMConfiguration {
    enum Key {
        static let endpoint = "AUTO_LEDGER_LLM_ENDPOINT"
        static let apiKey = "AUTO_LEDGER_LLM_API_KEY"
        static let model = "AUTO_LEDGER_LLM_MODEL"
        static let systemPrompt = "AUTO_LEDGER_LLM_SYSTEM_PROMPT"
        static let userPromptTemplate = "AUTO_LEDGER_LLM_USER_PROMPT_TEMPLATE"

        // Backward compatibility with the earlier API-only keys.
        static let legacyEndpoint = "AUTO_LEDGER_API_BASE_URL"
        static let legacyAPIKey = "AUTO_LEDGER_API_KEY"
    }

    let endpoint: URL
    let apiKey: String?
    let model: String
    let systemPrompt: String
    let userPromptTemplate: String

    static func load(bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) -> AutoLedgerLLMConfiguration? {
        let endpointValue = resolvedValue(
            primaryKey: Key.endpoint,
            fallbackKey: Key.legacyEndpoint,
            bundle: bundle,
            processInfo: processInfo)
        let apiKeyValue = resolvedValue(
            primaryKey: Key.apiKey,
            fallbackKey: Key.legacyAPIKey,
            bundle: bundle,
            processInfo: processInfo)
        let modelValue = resolvedValue(
            primaryKey: Key.model,
            bundle: bundle,
            processInfo: processInfo)
        let systemPromptValue = resolvedValue(
            primaryKey: Key.systemPrompt,
            bundle: bundle,
            processInfo: processInfo)
        let userPromptTemplateValue = resolvedValue(
            primaryKey: Key.userPromptTemplate,
            bundle: bundle,
            processInfo: processInfo)

        guard let endpointValue,
              let endpoint = URL(string: endpointValue),
              let modelValue,
              let systemPromptValue,
              let userPromptTemplateValue else {
            return nil
        }

        return AutoLedgerLLMConfiguration(
            endpoint: endpoint,
            apiKey: apiKeyValue,
            model: modelValue,
            systemPrompt: systemPromptValue,
            userPromptTemplate: userPromptTemplateValue)
    }

    func makeRequestBody(for request: AutoLedgerParseRequest, rawOCR: String?) -> AutoLedgerGatewayRequestBody {
        AutoLedgerGatewayRequestBody(
            model: model,
            systemPrompt: systemPrompt,
            userPrompt: renderUserPrompt(for: request, rawOCR: rawOCR),
            rawOCR: normalizedRawOCR(rawOCR),
            imageBase64: request.imageData?.base64EncodedString())
    }

    func renderUserPrompt(for request: AutoLedgerParseRequest, rawOCR: String?) -> String {
        let normalizedRawOCR = normalizedRawOCR(rawOCR) ?? ""
        let replacements: [String: String] = [
            "{{currencyCode}}": request.context.currencyCode,
            "{{localeIdentifier}}": request.context.localeIdentifier,
            "{{categoryCandidates}}": request.context.categoryCandidates.joined(separator: ", "),
            "{{paymentMethodCandidates}}": request.context.paymentMethodCandidates.joined(separator: ", "),
            "{{rawOCR}}": normalizedRawOCR,
            "{{hasImage}}": request.imageData == nil ? "false" : "true"
        ]

        return replacements.reduce(userPromptTemplate) { partial, pair in
            partial.replacingOccurrences(of: pair.key, with: pair.value)
        }
    }

    private func normalizedRawOCR(_ rawOCR: String?) -> String? {
        rawOCR?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private static func resolvedValue(
        primaryKey: String,
        fallbackKey: String? = nil,
        bundle: Bundle,
        processInfo: ProcessInfo) -> String? {
        let candidates = [primaryKey, fallbackKey].compactMap { $0 }

        for key in candidates {
            if let envValue = processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !envValue.isEmpty {
                return envValue
            }

            if let plistValue = bundle.object(forInfoDictionaryKey: key) as? String {
                let trimmedValue = plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedValue.isEmpty {
                    return trimmedValue
                }
            }
        }

        return nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
