import Foundation

/// Timing lines for the city-search tap. They show up in the UI test log.
enum TapTrace {
    private static let start = Date()

    static func mark(_ event: String) {
        #if DEBUG
        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        print("[atlas-tap] \(elapsed)ms \(event)")
        #endif
    }
}
