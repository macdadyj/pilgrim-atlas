#if canImport(UIKit)
import Foundation

enum PackResources {
    static func url(forResource name: String, withExtension ext: String, subdirectory: String? = nil) -> URL? {
        let bundle: Bundle
        #if SWIFT_PACKAGE
        bundle = Bundle.module
        #else
        bundle = Bundle.main
        #endif
        var directories: [String?] = [subdirectory, "Resources"]
        if let subdirectory {
            directories.append("Resources/" + subdirectory)
            if subdirectory.hasPrefix("Resources/") {
                directories.append(String(subdirectory.dropFirst("Resources/".count)))
            }
        }
        directories.append(nil)
        var seen = Set<String>()
        for directory in directories {
            let key = directory ?? ""
            if seen.contains(key) { continue }
            seen.insert(key)
            if let directory {
                if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: directory) {
                    return url
                }
            } else if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}

#endif
