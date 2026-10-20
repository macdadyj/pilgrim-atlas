import Foundation

/// Route text drawn on OpenStreetMap highways. `ref` is the number ("25")
/// and `network` says whether that number is an Interstate, a US route, or a state route.
package enum RouteShield {
    package static func caption(network: String, ref: String, routeNetwork: String = "") -> String {
        let number = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !number.isEmpty else { return "" }
        switch network {
        case "us-interstate":
            return "I-\(number)"
        case "us-highway":
            return "US \(number)"
        case "us-state":
            let prefix = statePrefix(routeNetwork)
            return prefix.isEmpty ? number : "\(prefix) \(number)"
        default:
            if routeNetwork == "US:I" { return "I-\(number)" }
            return number
        }
    }

    /// `US:NM` becomes `NM`. Other networks have no state badge.
    package static func statePrefix(_ routeNetwork: String) -> String {
        let parts = routeNetwork.split(separator: ":").map(String.init)
        guard parts.count >= 2, parts[0] == "US" else { return "" }
        let code = parts[1]
        guard code.count == 2, code.allSatisfy({ $0.isLetter }) else { return "" }
        return code
    }

    /// MapLibre text-field. Matches `caption` for the networks this map labels.
    package static var textField: [Any] {
        [
            "case",
            ["==", ["get", "network"], "us-interstate"],
            ["concat", "I-", ["to-string", ["get", "ref"]]],
            ["==", ["get", "network"], "us-highway"],
            ["concat", "US ", ["to-string", ["get", "ref"]]],
            [
                "all",
                ["==", ["get", "network"], "us-state"],
                [">=", ["length", ["to-string", ["coalesce", ["get", "route_1_network"], ""]]], 5],
            ],
            [
                "concat",
                ["slice", ["to-string", ["get", "route_1_network"]], 3],
                " ",
                ["to-string", ["get", "ref"]],
            ],
            ["==", ["get", "route_1_network"], "US:I"],
            ["concat", "I-", ["to-string", ["get", "ref"]]],
            ["to-string", ["get", "ref"]],
        ]
    }
}
