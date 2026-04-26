import Foundation

struct AutoLedgerOpenAIConfiguration {
    enum Key {
        static let endpoint = "AUTO_LEDGER_OPENAI_ENDPOINT"
        static let apiKey = "AUTO_LEDGER_OPENAI_API_KEY"
        static let model = "AUTO_LEDGER_OPENAI_MODEL"
        static let systemPrompt = "AUTO_LEDGER_OPENAI_SYSTEM_PROMPT"
        static let userPromptTemplate = "AUTO_LEDGER_OPENAI_USER_PROMPT_TEMPLATE"
        static let enableThinking = "AUTO_LEDGER_OPENAI_ENABLE_THINKING"

        // Backward compatibility with the previous gateway keys.
        static let legacyEndpoint = "AUTO_LEDGER_LLM_ENDPOINT"
        static let legacyAPIKey = "AUTO_LEDGER_LLM_API_KEY"
        static let legacyModel = "AUTO_LEDGER_LLM_MODEL"
        static let legacySystemPrompt = "AUTO_LEDGER_LLM_SYSTEM_PROMPT"
        static let legacyUserPromptTemplate = "AUTO_LEDGER_LLM_USER_PROMPT_TEMPLATE"

        // Older API-only keys.
        static let apiOnlyEndpoint = "AUTO_LEDGER_API_BASE_URL"
        static let apiOnlyAPIKey = "AUTO_LEDGER_API_KEY"
    }

    let endpoint: URL
    let apiKey: String?
    let model: String
    let systemPrompt: String
    let userPromptTemplate: String
    let enableThinking: Bool

    static func load(bundle: Bundle = .main,
                     processInfo: ProcessInfo = .processInfo) -> AutoLedgerOpenAIConfiguration? {
        let endpointValue = resolvedValue(
            primaryKey: Key.endpoint,
            fallbackKeys: [Key.legacyEndpoint, Key.apiOnlyEndpoint],
            bundle: bundle,
            processInfo: processInfo)
        let apiKeyValue = resolvedValue(
            primaryKey: Key.apiKey,
            fallbackKeys: [Key.legacyAPIKey, Key.apiOnlyAPIKey],
            bundle: bundle,
            processInfo: processInfo)
        let modelValue = resolvedValue(
            primaryKey: Key.model,
            fallbackKeys: [Key.legacyModel],
            bundle: bundle,
            processInfo: processInfo)
        let systemPromptValue = resolvedValue(
            primaryKey: Key.systemPrompt,
            fallbackKeys: [Key.legacySystemPrompt],
            bundle: bundle,
            processInfo: processInfo)
        let userPromptTemplateValue = resolvedValue(
            primaryKey: Key.userPromptTemplate,
            fallbackKeys: [Key.legacyUserPromptTemplate],
            bundle: bundle,
            processInfo: processInfo)
        let enableThinkingValue = resolvedValue(
            primaryKey: Key.enableThinking,
            fallbackKeys: [],
            bundle: bundle,
            processInfo: processInfo)

        guard let endpointValue,
              let endpoint = URL(string: endpointValue),
              let modelValue,
              let systemPromptValue,
              let userPromptTemplateValue else {
            return nil
        }

        return AutoLedgerOpenAIConfiguration(
            endpoint: endpoint,
            apiKey: apiKeyValue,
            model: modelValue,
            systemPrompt: systemPromptValue,
            userPromptTemplate: userPromptTemplateValue,
            enableThinking: parseBool(enableThinkingValue, defaultValue: false))
    }

    func makeRequestBody(for request: AutoLedgerParseRequest, rawOCR: String?) -> AutoLedgerOpenAIRequestBody {
        let userPrompt = renderUserPrompt(for: request, rawOCR: rawOCR)
        let contentParts = buildContentParts(userPrompt: userPrompt, imageData: request.imageData)
        let messages: [AutoLedgerOpenAIChatMessage] = [
            AutoLedgerOpenAIChatMessage(role: "system", content: .text(systemPrompt)),
            AutoLedgerOpenAIChatMessage(role: "user", content: .parts(contentParts))
        ]

        return AutoLedgerOpenAIRequestBody(
            model: model,
            messages: messages,
            responseFormat: AutoLedgerOpenAIResponseFormat(type: "json_object"),
            extraBody: AutoLedgerOpenAIExtraBody(enableThinking: enableThinking))
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

    private func buildContentParts(userPrompt: String, imageData: Data?) -> [AutoLedgerOpenAIContentPart] {
        var parts: [AutoLedgerOpenAIContentPart] = [
            AutoLedgerOpenAIContentPart(type: "text", text: userPrompt, imageURL: nil, inputAudio: nil)
        ]

        if let imageData {
            let base64 = imageData.base64EncodedString()
            let dataURL = "data:image/png;base64,\(base64)"
            parts.append(
                AutoLedgerOpenAIContentPart(
                    type: "image_url",
                    text: nil,
                    imageURL: AutoLedgerOpenAIImageURL(url: dataURL),
                    inputAudio: nil))
        }

        return parts
    }

    private func normalizedRawOCR(_ rawOCR: String?) -> String? {
        rawOCR?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private static func resolvedValue(
        primaryKey: String,
        fallbackKeys: [String],
        bundle: Bundle,
        processInfo: ProcessInfo) -> String? {
        let candidates = [primaryKey] + fallbackKeys

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

    private static func parseBool(_ value: String?, defaultValue: Bool) -> Bool {
        guard let value else { return defaultValue }
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return defaultValue
        }
    }
}

struct VoiceLedgerAIConfiguration {
    enum Key {
        static let endpoint = "VOICE_LEDGER_AI_ENDPOINT"
        static let apiKey = "VOICE_LEDGER_AI_API_KEY"
        static let model = "VOICE_LEDGER_AI_MODEL"
        static let systemPrompt = "VOICE_LEDGER_AI_SYSTEM_PROMPT"
        static let userPromptTemplate = "VOICE_LEDGER_AI_USER_PROMPT_TEMPLATE"
        static let enableThinking = "VOICE_LEDGER_AI_ENABLE_THINKING"
    }

    let endpoint: URL
    let apiKey: String?
    let model: String
    let systemPrompt: String
    let userPromptTemplate: String
    let enableThinking: Bool

    static func load(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
        environment: [String: String]? = nil) -> VoiceLedgerAIConfiguration? {
        let endpointValue = resolvedValue(
            primaryKey: Key.endpoint,
            bundle: bundle,
            processInfo: processInfo,
            environment: environment)
        let apiKeyValue = resolvedValue(
            primaryKey: Key.apiKey,
            bundle: bundle,
            processInfo: processInfo,
            environment: environment)
        let modelValue = resolvedValue(
            primaryKey: Key.model,
            bundle: bundle,
            processInfo: processInfo,
            environment: environment)
        let systemPromptValue = resolvedValue(
            primaryKey: Key.systemPrompt,
            bundle: bundle,
            processInfo: processInfo,
            environment: environment)
        let userPromptTemplateValue = resolvedValue(
            primaryKey: Key.userPromptTemplate,
            bundle: bundle,
            processInfo: processInfo,
            environment: environment)
        let enableThinkingValue = resolvedValue(
            primaryKey: Key.enableThinking,
            bundle: bundle,
            processInfo: processInfo,
            environment: environment)

        guard let endpointValue,
              let endpoint = URL(string: endpointValue),
              let modelValue,
              let systemPromptValue,
              let userPromptTemplateValue else {
            return nil
        }

        return VoiceLedgerAIConfiguration(
            endpoint: endpoint,
            apiKey: apiKeyValue,
            model: modelValue,
            systemPrompt: systemPromptValue,
            userPromptTemplate: userPromptTemplateValue,
            enableThinking: parseBool(enableThinkingValue, defaultValue: false))
    }

    func makeRequestBody(for request: VoiceLedgerParseRequest) -> VoiceLedgerAIRequestBody {
        let userPrompt = renderUserPrompt(for: request)
        let audioFormat = audioFormatIdentifier(from: request.audioMimeType)
        let audioDataURL = "data:;base64,\(request.audioData.base64EncodedString())"
        let contentParts = [
            AutoLedgerOpenAIContentPart(
                type: "input_audio",
                text: nil,
                imageURL: nil,
                inputAudio: AutoLedgerOpenAIInputAudio(data: audioDataURL, format: audioFormat)),
            AutoLedgerOpenAIContentPart(
                type: "text",
                text: userPrompt,
                imageURL: nil,
                inputAudio: nil)
        ]

        return VoiceLedgerAIRequestBody(
            model: model,
            messages: [
                AutoLedgerOpenAIChatMessage(role: "system", content: .text(systemPrompt)),
                AutoLedgerOpenAIChatMessage(role: "user", content: .parts(contentParts))
            ],
            stream: true,
            streamOptions: VoiceLedgerAIStreamOptions(includeUsage: true),
            modalities: ["text"],
            extraBody: AutoLedgerOpenAIExtraBody(enableThinking: enableThinking))
    }

    func renderUserPrompt(for request: VoiceLedgerParseRequest) -> String {
        let replacements: [String: String] = [
            "{{currencyCode}}": request.context.currencyCode,
            "{{localeIdentifier}}": request.context.localeIdentifier,
            "{{categoryCandidates}}": request.context.categoryCandidates.joined(separator: ", "),
            "{{paymentMethodCandidates}}": request.context.paymentMethodCandidates.joined(separator: ", "),
            "{{transcriptHint}}": request.transcriptHint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            "{{hasAudio}}": "true"
        ]

        return replacements.reduce(userPromptTemplate) { partial, pair in
            partial.replacingOccurrences(of: pair.key, with: pair.value)
        }
    }

    private func audioFormatIdentifier(from mimeType: String) -> String {
        let normalized = mimeType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch normalized {
        case "audio/mpeg", "audio/mp3":
            return "mp3"
        case "audio/wav", "audio/x-wav":
            return "wav"
        case "audio/aac":
            return "aac"
        case "audio/amr":
            return "amr"
        default:
            if let slash = normalized.lastIndex(of: "/") {
                return String(normalized[normalized.index(after: slash)...])
            }
            return "wav"
        }
    }

    private static func resolvedValue(
        primaryKey: String,
        bundle: Bundle,
        processInfo: ProcessInfo,
        environment: [String: String]?) -> String? {
        if let environment,
           let value = environment[primaryKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }

        if let envValue = processInfo.environment[primaryKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envValue.isEmpty {
            return envValue
        }

        if let plistValue = bundle.object(forInfoDictionaryKey: primaryKey) as? String {
            let trimmedValue = plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedValue.isEmpty {
                return trimmedValue
            }
        }

        return nil
    }

    private static func parseBool(_ value: String?, defaultValue: Bool) -> Bool {
        guard let value else { return defaultValue }
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return defaultValue
        }
    }
}

struct VoiceLedgerAIRequestBody: Encodable {
    let model: String
    let messages: [AutoLedgerOpenAIChatMessage]
    let stream: Bool
    let streamOptions: VoiceLedgerAIStreamOptions
    let modalities: [String]
    let extraBody: AutoLedgerOpenAIExtraBody?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case streamOptions = "stream_options"
        case modalities
        case extraBody = "extra_body"
    }
}

struct VoiceLedgerAIStreamOptions: Encodable {
    let includeUsage: Bool

    enum CodingKeys: String, CodingKey {
        case includeUsage = "include_usage"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
