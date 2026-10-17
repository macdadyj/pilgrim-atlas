import Foundation

/// A website that can be opened. Empty strings, placeholders, and bare words are not links.
package enum SiteLink {
    package static func direct(candidates: [String]) -> URL? {
        for candidate in candidates {
            if let url = usable(candidate) { return url }
        }
        return nil
    }

    package static func usable(_ raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        let folded = text.lowercased()
        let blocked = ["n/a", "na", "none", "null", "undefined", "http://", "https://", "example.com", "example.org", "example.net"]
        if blocked.contains(folded) { return nil }
        if folded.contains("example.com") || folded.contains("example.org") || folded.contains("example.net") { return nil }
        if !folded.hasPrefix("http://") && !folded.hasPrefix("https://") {
            guard folded.contains(".") else { return nil }
            text = "https://" + text
        }
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(),
              host.contains("."),
              host != "localhost"
        else { return nil }
        return url
    }

    package static func qid(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = trimmed.range(of: "Q[0-9]+", options: .regularExpression) else { return nil }
        let identifier = String(trimmed[match])
        return identifier == "Q0" ? nil : identifier
    }

    /// Official website (P856) from a `wbgetclaims` JSON document.
    package static func wikidataWebsite(from data: Data) -> URL? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let claims = root["claims"] as? [String: Any],
              let rows = claims["P856"] as? [[String: Any]]
        else { return nil }
        for row in rows {
            guard let snak = row["mainsnak"] as? [String: Any],
                  let value = (snak["datavalue"] as? [String: Any])?["value"] as? String,
                  let url = usable(value)
            else { continue }
            return url
        }
        return nil
    }
}
