// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PilgrimAtlas",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PilgrimAtlas", targets: ["PilgrimAtlas"]),
    ],
    dependencies: [
        .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution", from: "6.10.0"),
    ],
    targets: [
        .target(
            name: "PilgrimAtlasCore",
            resources: [
                .copy("sentences.json"),
                .copy("render-contract.json"),
                .copy("cabq_disclaimer.txt"),
                .copy("slo_disclaimer.txt"),
            ]
        ),
        .target(
            name: "PilgrimAtlas",
            dependencies: [
                "PilgrimAtlasCore",
                .product(
                    name: "MapLibre",
                    package: "maplibre-gl-native-distribution",
                    condition: .when(platforms: [.iOS, .macOS])
                ),
            ],
            resources: [
                .copy("Resources"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3", .when(platforms: [.iOS, .macOS])),
            ]
        ),
        .testTarget(
            name: "PilgrimAtlasCoreTests",
            dependencies: ["PilgrimAtlasCore"]
        ),
    ]
)
