import Foundation

package enum Copy {
    package static let sentences: [String: String] = load("sentences", "json")
    package static let cabqDisclaimer: String = loadText("cabq_disclaimer")
    package static let sloDisclaimer: String = loadText("slo_disclaimer")

    package static func text(_ key: String) -> String {
        guard let value = sentences[key] else {
            preconditionFailure("Missing sentence \(key)")
        }
        return value
    }

    private static func load(_ name: String, _ ext: String) -> [String: String] {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            preconditionFailure("Missing \(name).\(ext)")
        }
        return decoded
    }

    private static func loadText(_ name: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            preconditionFailure("Missing \(name).txt")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
