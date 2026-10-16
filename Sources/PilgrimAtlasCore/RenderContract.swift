import Foundation

/// Shared with `pipeline/tests/test_map_render.py`. The camera asks MapLibre
/// for `min(cameraZoom, sourceMaxZoom)`.
package struct RenderContract: Decodable, Equatable, Sendable {
    package var cameraZoom: Int
    package var landMaxZoom: Int
    package var trailMaxZoom: Int
    package var placeMaxZoom: Int
    package var hillshadeMaxZoom: Int
    package var terrainMaxZoom: Int
    package var minFillOpacity: Double

    package static func load() -> RenderContract {
        guard let url = ResourceBundle.url(forResource: "render-contract", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let contract = try? JSONDecoder().decode(RenderContract.self, from: data)
        else {
            return RenderContract(
                cameraZoom: 16,
                landMaxZoom: 14,
                trailMaxZoom: 12,
                placeMaxZoom: 14,
                hillshadeMaxZoom: 12,
                terrainMaxZoom: 12,
                minFillOpacity: 0.45
            )
        }
        return contract
    }

    package func requestZoom(sourceMaxZoom: Int) -> Int {
        min(cameraZoom, sourceMaxZoom)
    }
}
