import Foundation

enum AppInfo {
    static let displayName = "Sitizen"
    static let tagline = "你的久坐对手"

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.sitizen.app"
    }

    static var isBundled: Bool {
        Bundle.main.bundleIdentifier != nil
    }
}
