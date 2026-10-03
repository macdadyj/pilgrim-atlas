import Foundation

/// Fixed Santa Fe Plaza pin for screenshot launches. Off unless a debug build
/// is started with the plaza launch argument. Release builds ignore it.
package enum DebugPin {
    package static let plaza = LonLat(lon: -105.9378, lat: 35.6870)

    package static func isEnabled(arguments: [String]) -> Bool {
        DebugLaunch.parse(arguments).pinPlaza
    }
}
