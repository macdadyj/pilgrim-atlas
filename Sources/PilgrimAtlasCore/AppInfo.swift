import Foundation

/// Marketing version and build number shown in Settings.
package enum AppInfo {
    package static var marketing: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    package static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    package static var line: String {
        versionLine(marketing: marketing, build: build)
    }

    package static func versionLine(marketing: String, build: String) -> String {
        "\(marketing) (\(build))"
    }
}
