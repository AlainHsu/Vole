import Foundation

enum SiteConfiguration {
    static let defaultBaseURL = "https://www.v2ex.com"
    private static let accidentalDefaultBaseURL = "https://global.v2ex.co"
    private static let presetBaseURLs = [
        defaultBaseURL,
        accidentalDefaultBaseURL,
    ]

    private static let baseURLsKey = "siteBaseURLs"
    private static let selectedBaseURLKey = "selectedSiteBaseURL"

    static let didChangeNotification = NSNotification.Name(
        "SiteConfiguration.didChange"
    )

    static var endpointV1: String {
        selectedBaseURL + "/api/"
    }

    static var endpointV2: String {
        selectedBaseURL + "/api/v2/"
    }

    static var selectedBaseURL: String {
        loadState().selectedBaseURL
    }

    static var baseURLs: [String] {
        loadState().baseURLs
    }

    static var cacheKeySuffix: String {
        let allowed = CharacterSet.alphanumerics
        return selectedBaseURL.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }.joined()
    }

    static func makeSiteURL(from path: String) -> URL? {
        if path.hasPrefix("http") {
            return URL(string: path)
        }

        return URL(string: path, relativeTo: URL(string: selectedBaseURL))
    }

    static func matchesCurrentSite(host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }

        let currentHost = URL(string: selectedBaseURL)?.host?.lowercased()
        let knownHosts = Set(
            ["v2ex.com", "www.v2ex.com", currentHost].compactMap { $0 }
        )

        return knownHosts.contains(host)
    }

    static func normalizeBaseURL(_ rawValue: String) -> String? {
        var normalized = rawValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalized.isEmpty else { return nil }

        if !normalized.contains("://") {
            normalized = "https://" + normalized
        }

        guard var components = URLComponents(string: normalized),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            components.host?.isEmpty == false
        else {
            return nil
        }

        components.scheme = scheme
        components.host = components.host?.lowercased()
        components.query = nil
        components.fragment = nil

        while components.path.count > 1 && components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        if components.path == "/" {
            components.path = ""
        }

        return components.url?.absoluteString
    }

    static func persist(baseURLs: [String], selectedBaseURL: String?) {
        var normalizedURLs: [String] = []
        var seen = Set<String>()

        for url in baseURLs {
            guard let normalized = normalizeBaseURL(url) else { continue }
            let key = normalized.lowercased()
            if seen.insert(key).inserted {
                normalizedURLs.append(normalized)
            }
        }

        if normalizedURLs.isEmpty {
            normalizedURLs = presetBaseURLs
        }

        let normalizedSelected = selectedBaseURL.flatMap(normalizeBaseURL)
        let finalSelected =
            normalizedSelected.flatMap { selected in
                normalizedURLs.first {
                    $0.caseInsensitiveCompare(selected) == .orderedSame
                }
            } ?? normalizedURLs[0]

        UserDefaults.standard.set(normalizedURLs, forKey: baseURLsKey)
        UserDefaults.standard.set(finalSelected, forKey: selectedBaseURLKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func loadState() -> (baseURLs: [String], selectedBaseURL: String) {
        let storedURLs = UserDefaults.standard.stringArray(forKey: baseURLsKey)
            ?? [defaultBaseURL]
        let storedSelected = UserDefaults.standard.string(
            forKey: selectedBaseURLKey
        )

        var normalizedURLs: [String] = []
        var seen = Set<String>()

        for url in storedURLs {
            guard let normalized = normalizeBaseURL(url) else { continue }
            let key = normalized.lowercased()
            if seen.insert(key).inserted {
                normalizedURLs.append(normalized)
            }
        }

        if normalizedURLs.isEmpty {
            normalizedURLs = presetBaseURLs
        }

        let normalizedSelected = storedSelected.flatMap(normalizeBaseURL)

        if normalizedURLs.count == 1,
            normalizedURLs[0].caseInsensitiveCompare(accidentalDefaultBaseURL)
                == .orderedSame,
            normalizedSelected == nil
                || normalizedSelected?.caseInsensitiveCompare(
                    accidentalDefaultBaseURL
                ) == .orderedSame
        {
            normalizedURLs = presetBaseURLs
        }

        let finalSelected =
            normalizedSelected.flatMap { selected in
                normalizedURLs.first {
                    $0.caseInsensitiveCompare(selected) == .orderedSame
                }
            } ?? normalizedURLs[0]

        return (normalizedURLs, finalSelected)
    }
}

enum SiteConfigurationError: LocalizedError {
    case invalidBaseURL

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "请输入有效的站点地址，例如 https://www.v2ex.com"
        }
    }
}

@MainActor
final class SiteConfigurationStore: ObservableObject {
    static let shared = SiteConfigurationStore()

    @Published private(set) var baseURLs: [String] = []
    @Published private(set) var selectedBaseURL: String = SiteConfiguration.defaultBaseURL

    private init() {
        reload()
        SiteConfiguration.persist(
            baseURLs: baseURLs,
            selectedBaseURL: selectedBaseURL
        )
    }

    func reload() {
        let state = SiteConfiguration.loadState()
        baseURLs = state.baseURLs
        selectedBaseURL = state.selectedBaseURL
    }

    func select(_ baseURL: String) {
        SiteConfiguration.persist(baseURLs: baseURLs, selectedBaseURL: baseURL)
        reload()
    }

    @discardableResult
    func add(_ rawValue: String) throws -> String {
        guard let normalized = SiteConfiguration.normalizeBaseURL(rawValue) else {
            throw SiteConfigurationError.invalidBaseURL
        }

        var updated = baseURLs
        if !updated.contains(where: {
            $0.caseInsensitiveCompare(normalized) == .orderedSame
        }) {
            updated.append(normalized)
        }

        SiteConfiguration.persist(baseURLs: updated, selectedBaseURL: normalized)
        reload()
        return normalized
    }

    func remove(_ baseURL: String) {
        let updated = baseURLs.filter {
            $0.caseInsensitiveCompare(baseURL) != .orderedSame
        }
        SiteConfiguration.persist(
            baseURLs: updated,
            selectedBaseURL: selectedBaseURL
        )
        reload()
    }

    func canDelete(_ baseURL: String) -> Bool {
        baseURLs.count > 1
            || baseURL.caseInsensitiveCompare(SiteConfiguration.defaultBaseURL)
                != .orderedSame
    }
}
