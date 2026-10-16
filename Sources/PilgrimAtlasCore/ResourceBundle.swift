import Foundation

private class ResourceBundleToken {}

/// Resolves bundled files for SwiftPM, the Xcode app, and hosted unit tests.
package enum ResourceBundle {
    package static func url(
        forResource name: String,
        withExtension ext: String,
        subdirectory: String? = nil
    ) -> URL? {
        var directories: [String?] = [subdirectory, "Resources"]
        if let subdirectory {
            directories.append("Resources/" + subdirectory)
            if subdirectory.hasPrefix("Resources/") {
                directories.append(String(subdirectory.dropFirst("Resources/".count)))
            }
        }
        directories.append(nil)
        var seenDirs = Set<String>()
        var seenBundles = Set<ObjectIdentifier>()
        for bundle in bundles {
            let identity = ObjectIdentifier(bundle)
            if seenBundles.contains(identity) { continue }
            seenBundles.insert(identity)
            for directory in directories {
                let key = directory ?? ""
                if seenDirs.contains("\(identity)-\(key)") { continue }
                seenDirs.insert("\(identity)-\(key)")
                if let directory {
                    if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: directory) {
                        return url
                    }
                } else if let url = bundle.url(forResource: name, withExtension: ext) {
                    return url
                }
            }
        }
        return nil
    }

    private static var bundles: [Bundle] {
        var list: [Bundle] = []
        #if SWIFT_PACKAGE
        list.append(Bundle.module)
        #endif
        list.append(Bundle(for: ResourceBundleToken.self))
        list.append(Bundle.main)
        return list
    }
}
