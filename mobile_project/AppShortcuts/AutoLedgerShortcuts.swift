import AppIntents
import Foundation

enum AutoLedgerShortcutSource: String, Codable, Equatable, Sendable {
    case shortcutsApp
    case assistiveTouch
    case actionButton
    case shareSheet
    case inAppDemo

    var displayName: String {
        switch self {
        case .shortcutsApp:
            "快捷指令".localized
        case .assistiveTouch:
            "辅助触控（小白点）".localized
        case .actionButton:
            "操作按钮".localized
        case .shareSheet:
            "分享扩展".localized
        case .inAppDemo:
            "App 内演示".localized
        }
    }
}

enum AutoLedgerShortcutSourceIntentValue: String, AppEnum {
    case shortcutsApp
    case assistiveTouch
    case actionButton
    case shareSheet

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("触发来源"))
    }

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [
            .shortcutsApp: DisplayRepresentation(title: LocalizedStringResource("快捷指令")),
            .assistiveTouch: DisplayRepresentation(title: LocalizedStringResource("辅助触控（小白点）")),
            .actionButton: DisplayRepresentation(title: LocalizedStringResource("操作按钮")),
            .shareSheet: DisplayRepresentation(title: LocalizedStringResource("分享扩展"))
        ]
    }

    var domainValue: AutoLedgerShortcutSource {
        switch self {
        case .shortcutsApp:
            .shortcutsApp
        case .assistiveTouch:
            .assistiveTouch
        case .actionButton:
            .actionButton
        case .shareSheet:
            .shareSheet
        }
    }
}

struct AutoLedgerLaunchPayload: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let source: AutoLedgerShortcutSource
    let imageFilename: String?
    let ocrTextHint: String?
    let educationState: AutoLedgerShortcutEducationState?
    let createdAt: Date
}

struct AutoLedgerShortcutRunStatus: Codable, Equatable, Sendable {
    var lastTriggeredAt: Date?
    var lastSource: AutoLedgerShortcutSource?
    var lastCompletedAt: Date?
    var lastErrorMessage: String?
}

enum AutoLedgerHandoffStore {
    private static let pendingLaunchKey = "ledger.auto-ledger.pending-launch.v1"
    private static let shortcutStatusKey = "ledger.auto-ledger.shortcut-status.v1"
    private static let debugSnapshotKey = "ledger.auto-ledger.debug-snapshot.v1"
    private static let incomingFolderName = "AutoLedgerIncoming"

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: LedgerWidgetShared.appGroupID) ?? .standard
    }

    private static var incomingDirectoryURL: URL {
        let baseURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: LedgerWidgetShared.appGroupID)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directoryURL = baseURL.appendingPathComponent(incomingFolderName, isDirectory: true)

        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        return directoryURL
    }

    static func stageLaunch(
        files: [IntentFile],
        ocrTextHint: String?,
        source: AutoLedgerShortcutSource,
        educationState: AutoLedgerShortcutEducationState? = nil) async throws -> AutoLedgerLaunchPayload {
        var storedFilename: String?

        if let file = files.first {
            storedFilename = try await persist(file: file)
        }

        let payload = AutoLedgerLaunchPayload(
            id: UUID(),
            source: source,
            imageFilename: storedFilename,
            ocrTextHint: ocrTextHint?.trimmingCharacters(in: .whitespacesAndNewlines),
            educationState: educationState,
            createdAt: Date())

        savePayload(payload)

        var status = loadStatus()
        status.lastTriggeredAt = payload.createdAt
        status.lastSource = source
        status.lastErrorMessage = nil
        saveStatus(status)

        return payload
    }

    static func peekPendingLaunch() -> AutoLedgerLaunchPayload? {
        guard let data = defaults.data(forKey: pendingLaunchKey) else { return nil }
        return try? decoder.decode(AutoLedgerLaunchPayload.self, from: data)
    }

    static func consumePendingLaunch() -> AutoLedgerLaunchPayload? {
        guard let payload = peekPendingLaunch() else { return nil }
        defaults.removeObject(forKey: pendingLaunchKey)
        return payload
    }

    static func consumeImageData(for payload: AutoLedgerLaunchPayload) throws -> Data? {
        guard let fileURL = fileURL(for: payload) else { return nil }
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }
        return try Data(contentsOf: fileURL)
    }

    static func markTriggered(source: AutoLedgerShortcutSource) {
        var status = loadStatus()
        status.lastTriggeredAt = Date()
        status.lastSource = source
        status.lastErrorMessage = nil
        saveStatus(status)
    }

    static func markLastRunFailed(_ message: String) {
        var status = loadStatus()
        status.lastErrorMessage = message
        saveStatus(status)
    }

    static func markLastRunSucceeded() {
        var status = loadStatus()
        status.lastCompletedAt = Date()
        status.lastErrorMessage = nil
        saveStatus(status)
    }

    static func loadStatus() -> AutoLedgerShortcutRunStatus {
        guard let data = defaults.data(forKey: shortcutStatusKey),
              let status = try? decoder.decode(AutoLedgerShortcutRunStatus.self, from: data) else {
            return AutoLedgerShortcutRunStatus()
        }
        return status
    }

    static func saveDebugSnapshot(_ snapshot: AutoLedgerDebugSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: debugSnapshotKey)
    }

    static func loadDebugSnapshot() -> AutoLedgerDebugSnapshot? {
        guard let data = defaults.data(forKey: debugSnapshotKey) else { return nil }
        return try? decoder.decode(AutoLedgerDebugSnapshot.self, from: data)
    }

    private static func savePayload(_ payload: AutoLedgerLaunchPayload) {
        guard let data = try? encoder.encode(payload) else { return }
        defaults.set(data, forKey: pendingLaunchKey)
    }

    private static func saveStatus(_ status: AutoLedgerShortcutRunStatus) {
        guard let data = try? encoder.encode(status) else { return }
        defaults.set(data, forKey: shortcutStatusKey)
    }

    private static func fileURL(for payload: AutoLedgerLaunchPayload) -> URL? {
        guard let imageFilename = payload.imageFilename, !imageFilename.isEmpty else { return nil }
        return incomingDirectoryURL.appendingPathComponent(imageFilename)
    }

    private static func persist(file: IntentFile) async throws -> String {
        let fileExtension = (file.filename as NSString).pathExtension
        let filename = fileExtension.isEmpty
            ? "capture-\(UUID().uuidString)"
            : "capture-\(UUID().uuidString).\(fileExtension)"
        let destinationURL = incomingDirectoryURL.appendingPathComponent(filename)

        if let fileURL = file.fileURL {
            let didAccess = fileURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
        } else {
            try file.data.write(to: destinationURL, options: .atomic)
        }

        return filename
    }
}

private enum AutoLedgerIntentInputLoader {
    static func loadFirstImageData(from files: [IntentFile]) throws -> Data? {
        guard let file = files.first else { return nil }

        if let fileURL = file.fileURL {
            let didAccess = fileURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            return try Data(contentsOf: fileURL)
        }

        return file.data
    }
}

private enum AutoLedgerDirectRunner {
    static func run(
        files: [IntentFile],
        ocrTextHint: String?,
        source: AutoLedgerShortcutSource) async throws -> String {
        let normalizedOCRTextHint = ocrTextHint?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !files.isEmpty || !(normalizedOCRTextHint?.isEmpty ?? true) else {
            return "请先在快捷指令里配置“截图 -> 从截图获取图像 -> 识别账单”。"
        }

        AutoLedgerHandoffStore.markTriggered(source: source)

        let imageData = try AutoLedgerIntentInputLoader.loadFirstImageData(from: files)
        let snapshot = LedgerPersistenceStore.loadOrSeedPersistedState()
        let request = AutoLedgerParseRequest(
            imageData: imageData,
            context: makeContext(from: snapshot),
            ocrTextHint: normalizedOCRTextHint)

        let service = AutoLedgerServiceFactory.make()
        let debugRequestSummary = buildRequestSummary(request, source: source)
        let ocrPreview = debugPreview(normalizedOCRTextHint)
        let shouldPersistDirectDebugSnapshot = service.recognitionEngine == .local
        do {
            let result = try await service.parseReceipt(request)
            if shouldPersistDirectDebugSnapshot {
                AutoLedgerHandoffStore.saveDebugSnapshot(
                    AutoLedgerDebugSnapshot(
                        timestamp: Date(),
                        engine: "local",
                        endpoint: nil,
                        model: nil,
                        requestSummary: debugRequestSummary,
                        rawOCRPreview: ocrPreview,
                        rawResponse: nil,
                        parsedResult: result,
                        errorMessage: nil))
            }
            let dialog = try AutoLedgerDirectSaver.save(
                envelope: result,
                imageData: request.imageData,
                into: snapshot)
            AutoLedgerHandoffStore.markLastRunSucceeded()
            return dialog
        } catch {
            if shouldPersistDirectDebugSnapshot {
                AutoLedgerHandoffStore.saveDebugSnapshot(
                    AutoLedgerDebugSnapshot(
                        timestamp: Date(),
                        engine: "local",
                        endpoint: nil,
                        model: nil,
                        requestSummary: debugRequestSummary,
                        rawOCRPreview: ocrPreview,
                        rawResponse: nil,
                        parsedResult: nil,
                        errorMessage: error.localizedDescription))
            }
            throw error
        }
    }

    private static func makeContext(from snapshot: LedgerPersistenceSnapshot) -> AutoLedgerParseContext {
        let selectedScheme = snapshot.categorySchemes.first(where: { $0.id == snapshot.selectedCategorySchemeID })
            ?? snapshot.categorySchemes.first
            ?? LedgerCategoryScheme.defaultSchemes.first
            ?? LedgerCategoryScheme(
                name: "默认分类",
                note: "",
                expenseCategories: LedgerCategory.expenseCategories,
                incomeCategories: LedgerCategory.incomeCategories)

        let categories = LedgerKind.allCases.flatMap { kind -> [String] in
            let source = kind == .expense ? selectedScheme.expenseCategories : selectedScheme.incomeCategories
            return source.flatMap { category in
                [
                    "\(kind.localizedTitle):\(category.name)",
                    "\(kind.localizedTitle):\(category.name.localized)",
                    "\(kind.storageKey):\(category.id)"
                ]
            }
        }

        let paymentMethods = uniqueStrings(
            snapshot.accounts
                .filter { $0.group != .credit && $0.group != .loan }
                .map(\.name) + ["支付宝", "微信", "银行卡", "现金"])

        return AutoLedgerParseContext(
            currencyCode: "CNY",
            localeIdentifier: LedgerFormatters.locale.identifier,
            categoryCandidates: categories,
            paymentMethodCandidates: paymentMethods)
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var result: [String] = []

        for value in values where !result.contains(value) {
            result.append(value)
        }

        return result
    }

    private static func buildRequestSummary(_ request: AutoLedgerParseRequest,
                                            source: AutoLedgerShortcutSource) -> String {
        let imageState = request.imageData == nil ? "无图片" : "有图片"
        let ocrState = request.ocrTextHint?.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false ? "有 OCR hint" : "无 OCR hint"
        return "source=\(source.rawValue) | \(imageState) | \(ocrState) | currency=\(request.context.currencyCode) | locale=\(request.context.localeIdentifier)"
    }

    private static func debugPreview(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(800))
    }
}

private enum AutoLedgerDirectSaver {
    static func save(envelope: AutoLedgerParseEnvelope,
                     imageData: Data?,
                     into currentSnapshot: LedgerPersistenceSnapshot) throws -> String {
        let validEntries = envelope.entries.filter { ($0.amount ?? 0) > 0 }
        guard !validEntries.isEmpty else {
            throw AutoLedgerServiceError.parseFailed
        }

        var snapshot = currentSnapshot
        let bookID = resolvedBookID(in: snapshot)
        var savedCount = 0
        var primaryTitle: String?
        var primaryAmount: Double?
        var primaryCategory: LedgerCategory?
        let primaryCandidate = envelope.primaryEntry

        if let primaryCandidate, let amount = primaryCandidate.amount, amount > 0 {
            let kind = primaryCandidate.normalizedKind ?? .expense
            let categories = categories(for: kind, in: snapshot)
            let category = mapCategory(from: primaryCandidate.category, categories: categories, kind: kind)
            let merchant = (primaryCandidate.merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let note = (primaryCandidate.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            primaryTitle = merchant.isEmpty ? (note.isEmpty ? category.name.localized : note) : merchant
            primaryAmount = amount
            primaryCategory = category
        }

        for entry in validEntries {
            let kind = entry.normalizedKind ?? .expense
            let categories = categories(for: kind, in: snapshot)
            let category = mapCategory(from: entry.category, categories: categories, kind: kind)
            let paymentMethod = mapPaymentMethod(from: entry.paymentMethod, in: snapshot)
            let merchant = (entry.merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let note = (entry.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let title = merchant.isEmpty ? (note.isEmpty ? category.name.localized : note) : merchant
            let amount = entry.amount ?? 0

            snapshot.entries.insert(
                LedgerEntry(
                    bookID: bookID,
                    title: title,
                    amount: amount,
                    kind: kind,
                    category: category,
                    paymentMethod: paymentMethod,
                    note: note,
                    date: entry.occurredAt,
                    screenshotData: snapshot.appSettings.showRecordImages ? imageData : nil),
                at: 0)

            savedCount += 1
        }

        if primaryTitle == nil, let firstEntry = validEntries.first {
            let kind = firstEntry.normalizedKind ?? .expense
            let categories = categories(for: kind, in: snapshot)
            let category = mapCategory(from: firstEntry.category, categories: categories, kind: kind)
            let merchant = (firstEntry.merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let note = (firstEntry.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            primaryTitle = merchant.isEmpty ? (note.isEmpty ? category.name.localized : note) : merchant
            primaryAmount = firstEntry.amount ?? 0
            primaryCategory = category
        }

        snapshot.appSettings.hasAcknowledgedShortcutInstall = true
        snapshot.appSettings.lastShortcutEducationState = .usage
        LedgerPersistenceStore.savePersistedState(snapshot)
        LedgerPersistenceStore.saveAppSettings(snapshot.appSettings)

        let summaryTitle = primaryTitle ?? (primaryCategory?.name ?? "账单")
        let summaryAmount = primaryAmount ?? 0
        var summary = "已自动入账 \(savedCount) 笔：\(LedgerFormatters.currency(summaryAmount)) · \(summaryTitle)"

        if validEntries.contains(where: { $0.confidence < 0.65 }) {
            summary += "。部分记录置信度偏低，请回 Monee 核对。"
        } else {
            summary += "。"
        }

        return summary
    }

    private static func categories(for kind: LedgerKind, in snapshot: LedgerPersistenceSnapshot) -> [LedgerCategory] {
        let selectedScheme = snapshot.categorySchemes.first(where: { $0.id == snapshot.selectedCategorySchemeID })
            ?? snapshot.categorySchemes.first
            ?? LedgerCategoryScheme.defaultSchemes.first
            ?? LedgerCategoryScheme(
                name: "默认分类",
                note: "",
                expenseCategories: LedgerCategory.expenseCategories,
                incomeCategories: LedgerCategory.incomeCategories)

        return kind == .expense ? selectedScheme.expenseCategories : selectedScheme.incomeCategories
    }

    private static func resolvedBookID(in snapshot: LedgerPersistenceSnapshot) -> UUID {
        if snapshot.books.contains(where: { $0.id == snapshot.selectedBookID }) {
            return snapshot.selectedBookID
        }

        if let firstBook = snapshot.books.first {
            return firstBook.id
        }

        return LedgerStore.makeSeedPersistedState().selectedBookID
    }

    private static func mapCategory(from hint: String?, categories: [LedgerCategory],
                                    kind: LedgerKind) -> LedgerCategory {
        guard let hint, !hint.isEmpty else {
            return fallbackCategory(from: categories, kind: kind)
        }

        let normalizedHint = normalizedLookupText(hint)

        if let byID = categories.first(where: { $0.id.caseInsensitiveCompare(hint) == .orderedSame }) {
            return byID
        }

        if let byName = categories.first(where: {
            $0.name.caseInsensitiveCompare(hint) == .orderedSame ||
                $0.name.localized.caseInsensitiveCompare(hint) == .orderedSame
        }) {
            return byName
        }

        if let fuzzy = categories.first(where: {
            let candidates = [$0.name, $0.name.localized]
            return candidates.contains { candidate in
                let normalizedCategoryName = normalizedLookupText(candidate)
                return normalizedCategoryName.contains(normalizedHint) || normalizedHint
                    .contains(normalizedCategoryName)
            }
        }) {
            return fuzzy
        }

        return fallbackCategory(from: categories, kind: kind)
    }

    private static func fallbackCategory(from categories: [LedgerCategory], kind: LedgerKind) -> LedgerCategory {
        if kind == .expense,
           let expenseOther = categories.first(where: { $0.id == "expense.other" }) {
            return expenseOther
        }

        return categories.first ?? LedgerCategory.defaultCategory(for: kind)
    }

    private static func mapPaymentMethod(from hint: String?, in snapshot: LedgerPersistenceSnapshot) -> String {
        let paymentMethods = uniqueStrings(
            snapshot.accounts
                .filter { $0.group != .credit && $0.group != .loan }
                .map(\.name) + ["支付宝", "微信", "银行卡", "现金", "待确认"])

        guard let hint, !hint.isEmpty else { return "待确认" }

        if hint.localizedCaseInsensitiveContains("微信") {
            return paymentMethods.first(where: { $0.localizedCaseInsensitiveContains("微信") }) ?? "微信"
        }

        if hint.localizedCaseInsensitiveContains("支付宝") {
            return paymentMethods.first(where: { $0.localizedCaseInsensitiveContains("支付宝") }) ?? "支付宝"
        }

        if ["银行卡", "信用卡", "储蓄卡", "visa", "mastercard"].contains(where: hint.localizedCaseInsensitiveContains) {
            return paymentMethods.first(where: {
                ["银行卡", "信用卡", "储蓄卡"].contains(where: $0.localizedCaseInsensitiveContains)
            }) ?? "银行卡"
        }

        if ["现金", "cash"].contains(where: hint.localizedCaseInsensitiveContains) {
            return paymentMethods.first(where: { $0.localizedCaseInsensitiveContains("现金") }) ?? "现金"
        }

        if let exact = paymentMethods.first(where: { $0.caseInsensitiveCompare(hint) == .orderedSame }) {
            return exact
        }

        return "待确认"
    }

    private static func normalizedLookupText(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "类", with: "")
            .replacingOccurrences(of: "消费", with: "")
            .replacingOccurrences(of: "支出", with: "")
            .replacingOccurrences(of: "收入", with: "")
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var result: [String] = []

        for value in values where !result.contains(value) {
            result.append(value)
        }

        return result
    }
}

struct StartAutoLedgerIntent: AppIntent {
    static let title: LocalizedStringResource = "识别账单"
    static let description = IntentDescription("接收快捷指令里的截图图像，打开 App 并交给自动记账中心完成识别和入账。")
    static let openAppWhenRun = true

    @Parameter(
        title: "图片",
        inputConnectionBehavior: .connectToPreviousIntentResult)
    var files: [IntentFile]

    @Parameter(
        title: "OCR 文本",
        inputConnectionBehavior: .connectToPreviousIntentResult)
    var ocrTextHint: String?

    @Parameter(title: "触发来源")
    var source: AutoLedgerShortcutSourceIntentValue

    init() {
        self.files = []
        self.ocrTextHint = nil
        self.source = .shortcutsApp
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            _ = try await AutoLedgerHandoffStore.stageLaunch(
                files: files,
                ocrTextHint: ocrTextHint,
                source: source.domainValue,
                educationState: .usage)
            return .result(dialog: IntentDialog(stringLiteral: "已接收截图，正在打开 App 完成识别与自动入账。"))
        } catch {
            AutoLedgerHandoffStore.markLastRunFailed(error.localizedDescription)
            return .result(dialog: IntentDialog(stringLiteral: error.localizedDescription))
        }
    }
}

struct OpenAutoLedgerCenterIntent: AppIntent {
    static let title: LocalizedStringResource = "打开自动记账中心"
    static let description = IntentDescription("直接打开 App 内的自动记账中心。")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        _ = try await AutoLedgerHandoffStore.stageLaunch(
            files: [],
            ocrTextHint: nil,
            source: .shortcutsApp,
            educationState: .install)
        return .result(dialog: "已打开自动记账中心。")
    }
}

struct AutoLedgerShortcutsProvider: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor {
        .blue
    }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartAutoLedgerIntent(),
            phrases: [
                "用 \(.applicationName) 识别账单",
                "在 \(.applicationName) 里识别账单",
                "让 \(.applicationName) 处理账单截图"
            ],
            shortTitle: "识别账单",
            systemImageName: "doc.text.viewfinder")
        AppShortcut(
            intent: OpenAutoLedgerCenterIntent(),
            phrases: [
                "打开 \(.applicationName) 自动记账中心",
                "在 \(.applicationName) 里打开自动记账"
            ],
            shortTitle: "自动记账中心",
            systemImageName: "swirl.circle")
    }
}
