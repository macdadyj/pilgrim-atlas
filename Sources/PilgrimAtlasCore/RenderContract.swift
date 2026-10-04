import Foundation

/// Shared with `pipeline/tests/test_map_render.py`. Camera zoom 15 asks MapLibre
/// for `min(cameraZoom, sourceMaxZoom)`. Land and trail tiles stop below the
/// archive max zoom, so those sources must overzoom or the cream background is
/// all that draws.
package struct RenderContract: Decodable, Equatable, Sendable {
    package var cameraZoom: Int
    package var landMaxZoom: Int
    package var trailMaxZoom: Int
    package var placeMaxZoom: Int
    package var minFillOpacity: Double

    package static func load() -> RenderContract {
        guard let url = Bundle.module.url(forResource: "render-contract", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let contract = try? JSONDecoder().decode(RenderContract.self, from: data)
        else {
            return RenderContract(
                cameraZoom: 15,
                landMaxZoom: 11,
                trailMaxZoom: 12,
                placeMaxZoom: 14,
                minFillOpacity: 0.45
            )
        }
        return contract
    }

    package func requestZoom(sourceMaxZoom: Int) -> Int {
        min(cameraZoom, sourceMaxZoom)
    }
}
