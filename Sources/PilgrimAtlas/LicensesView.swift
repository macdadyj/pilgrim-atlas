#if canImport(UIKit)
import SwiftUI
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

struct LicensesView: View {
    @Environment(AtlasModel.self) private var model

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("The Swift code in this project is MIT. The databases in the pack are not. Each dataset keeps its own terms.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    section("OpenStreetMap", "Landmarks, trails, and the vector tiles derived from them are © OpenStreetMap contributors, under the Open Database License (ODbL). Extract: \(model.meta["osm_date"] ?? "see the pack manifest").")
                    section("Map tiles", "Offline tiles are a Protomaps PMTiles file built for this pack. OpenFreeMap is optional, off unless you turn it on, and is also OpenStreetMap data. This app does not use openstreetmap.org tile servers or Nominatim.")
                    section("Terrain", "Hillshade and contours every 100 ft, with a heavier labeled line every 500 ft, are derived from Mapzen Terrain Tiles hosted by AWS Open Data (Terrarium elevation). Those tiles are CC BY 4.0 and ODbL. Elevation inputs include USGS and other open sources named by the Mapzen terrain dataset. The derived archives are stored in the app and are not requested at runtime.")
                    section("PAD-US", "Protected-area polygons are USGS PAD-US 4.1, which USGS marks CC0. Cite the U.S. Geological Survey Gap Analysis Project. GAP status is not a hiking permit. Version: PAD-US 4.1.")
                    section("BLM", "Surface-management polygons are the Bureau of Land Management SMA dataset, public domain. They are not a survey and not a land-ownership deed.")
                    section("Forest Service", "Forest ownership is USDA Forest Service Basic Ownership. The administrative forest outline is not treated as fee ownership. A non-Forest Service class inside a forest is not an invitation to enter.")
                    section("National Park Service", "Park outlines are the NPS Land Resources Division boundary. The legislated line is not fee title and not a survey.")
                    section("New Mexico State Trust land", Copy.sloDisclaimer + " " + Copy.text("state_trust"))
                    section("City of Albuquerque", Copy.cabqDisclaimer)
                    section("Santa Fe", "Santa Fe County and City of Santa Fe parcel polygons are not in this pack. Use the official map if you need their records.")
                    ForEach(model.links) { link in
                        if let url = URL(string: link.url) {
                            VStack(alignment: .leading, spacing: 4) {
                                Link(link.title, destination: url)
                                Text(link.note)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .fieldCard()
                        }
                    }
                    Text("MapLibre Native is BSD-2-Clause. SQLite is public domain. Census TIGER data is not used as a land-status layer, and the TIGER trademark is not part of the app name.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(Theme.screenPadding)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Licenses")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("licenses-screen")
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: title)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .fieldCard()
    }
}

#endif
