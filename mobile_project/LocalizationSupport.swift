import Foundation

enum L10n {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.autoupdatingCurrent, arguments: arguments)
    }
}

extension String {
    var localized: String {
        L10n.text(self)
    }
}
