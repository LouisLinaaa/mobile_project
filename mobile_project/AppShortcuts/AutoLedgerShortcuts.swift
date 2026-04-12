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
            "快捷指令"
        case .assistiveTouch:
            "辅助触控"
        case .actionButton:
            "操作按钮"
        case .shareSheet:
            "分享扩展"
        case .inAppDemo:
            "App 内演示"
        }
    }
}

enum AutoLedgerShortcutSourceIntentValue: String, AppEnum {
    case shortcutsApp
    case assistiveTouch
    case actionButton
    case shareSheet

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "触发来源"
    }

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [
            .shortcutsApp: "快捷指令",
            .assistiveTouch: "辅助触控",
            .actionButton: "操作按钮",
            .shareSheet: "分享扩展",
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
        let baseURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: LedgerWidgetShared.appGroupID)
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
        source: AutoLedgerShortcutSource
    ) async throws -> AutoLedgerLaunchPayload {
        var storedFilename: String?

        if let file = files.first {
            storedFilename = try await persist(file: file)
        }

        let payload = AutoLedgerLaunchPayload(
            id: UUID(),
            source: source,
            imageFilename: storedFilename,
            ocrTextHint: ocrTextHint?.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )

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

struct StartAutoLedgerIntent: AppIntent {
    static let title: LocalizedStringResource = "自动记账"
    static let description = IntentDescription("把截图交给本地记账，并在 App 内进入自动记账审核流程。")
    static let openAppWhenRun = true

    @Parameter(
        title: "账单截图",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var files: [IntentFile]

    @Parameter(
        title: "OCR 文本",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var ocrTextHint: String?

    @Parameter(title: "触发来源")
    var source: AutoLedgerShortcutSourceIntentValue

    init() {
        self.files = []
        self.ocrTextHint = nil
        self.source = .shortcutsApp
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        _ = try await AutoLedgerHandoffStore.stageLaunch(
            files: files,
            ocrTextHint: ocrTextHint,
            source: source.domainValue
        )
        return .result(dialog: "已打开自动记账审核页。")
    }
}

struct OpenAutoLedgerCenterIntent: AppIntent {
    static let title: LocalizedStringResource = "打开自动记账中心"
    static let description = IntentDescription("直接打开 App 内的自动记账中心。")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "已打开自动记账中心。")
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
                "用 \(.applicationName) 自动记账",
                "在 \(.applicationName) 里自动记账",
                "让 \(.applicationName) 识别账单截图",
            ],
            shortTitle: "自动记账",
            systemImageName: "doc.text.viewfinder"
        )

        AppShortcut(
            intent: OpenAutoLedgerCenterIntent(),
            phrases: [
                "打开 \(.applicationName) 自动记账中心",
                "在 \(.applicationName) 里打开自动记账",
            ],
            shortTitle: "自动记账中心",
            systemImageName: "swirl.circle"
        )
    }
}
