import Foundation

enum L10n {
    static let supportedLocaleIdentifiers = ["zh-Hans", "en"]

    static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
    }

    static func text(_ key: String, localeIdentifier: String) -> String {
        guard
            let path = Bundle.main.path(forResource: localeIdentifier, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return key
        }

        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.autoupdatingCurrent, arguments: arguments)
    }

    static func variants(for key: String, localeIdentifiers: [String] = supportedLocaleIdentifiers) -> [String] {
        uniqueStrings([key] + localeIdentifiers.map { text(key, localeIdentifier: $0) })
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var result: [String] = []

        for value in values where !result.contains(value) {
            result.append(value)
        }

        return result
    }
}

extension String {
    var localized: String {
        L10n.text(self)
    }

    func localized(in localeIdentifier: String) -> String {
        L10n.text(self, localeIdentifier: localeIdentifier)
    }

    var localizedVariants: [String] {
        L10n.variants(for: self)
    }
}
