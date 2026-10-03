import Foundation

/// Fixed Santa Fe Plaza pin for screenshot launches. Off unless a debug build
/// is started with `--debug-santa-fe-plaza`. Release builds ignore the argument.
package enum DebugPin {
    package static let argument = "--debug-santa-fe-plaza"
    package static let plaza = LonLat(lon: -105.9378, lat: 35.6870)

    package static func isEnabled(arguments: [String]) -> Bool {
        #if DEBUG
        return arguments.contains(argument)
        #else
        return false
        #endif
    }
}
