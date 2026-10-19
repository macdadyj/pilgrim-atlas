#if canImport(UIKit)
import CoreLocation
import MapKit
import SafariServices
import SwiftUI
#if SWIFT_PACKAGE
import PilgrimAtlasCore
#endif

struct VisitBlock: View {
    var candidates: [String]
    var wikidata: String
    var phone: String
    var name: String
    var address: String = ""
    var coordinate: LonLat
    var walking: Bool

    @State private var wikidataSite: URL?

    private var website: URL? {
        SiteLink.direct(candidates: candidates) ?? wikidataSite
    }

    var body: some View {
        VisitSection(
            website: website,
            phone: phone,
            name: name,
            address: address,
            coordinate: coordinate,
            walking: walking,
            websiteIdentifier: "place-website",
            directionsIdentifier: "place-directions"
        )
        .task(id: wikidata) {
            guard SiteLink.direct(candidates: candidates) == nil,
                  let qid = SiteLink.qid(from: wikidata)
            else { return }
            wikidataSite = await WikidataWebsite.shared.website(for: qid)
        }
    }
}

struct VisitSection: View {
    var website: URL?
    var phone: String
    var name: String
    var address: String = ""
    var coordinate: LonLat
    var walking: Bool
    var websiteIdentifier: String
    var directionsIdentifier: String

    @State private var chooseMaps = false
    @State private var eta = ""

    var body: some View {
        Section {
            if let website {
                Button("Website") { SafariPresenter.open(website) }
                    .accessibilityIdentifier(websiteIdentifier)
            }
            if let call = VisitRouting.phoneURL(phone) {
                Link("Call", destination: call)
                    .accessibilityIdentifier("place-call")
            }
            Button("Directions") {
                if GoogleMaps.installed {
                    chooseMaps = true
                } else {
                    AppleMaps.open(name: name, coordinate: coordinate, walking: walking)
                }
            }
            .accessibilityIdentifier(directionsIdentifier)
            ShareLink(item: PlaceShare.message(name: name, address: address, phone: phone, website: website?.absoluteString ?? "")) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("place-share")
            if !eta.isEmpty {
                Text(eta)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("place-eta")
            }
        } header: {
            SectionTitle(text: "Visit")
        }
        .confirmationDialog("Directions", isPresented: $chooseMaps, titleVisibility: .visible) {
            Button("Apple Maps") {
                AppleMaps.open(name: name, coordinate: coordinate, walking: walking)
            }
            Button("Google Maps") {
                GoogleMaps.open(coordinate: coordinate, walking: walking)
            }
            Button("Cancel", role: .cancel) {}
        }
        .task(id: "\(coordinate.lat),\(coordinate.lon),\(walking)") {
            eta = await VisitRouting.travelLine(to: coordinate, walking: walking)
        }
    }
}

/// Presents Safari on the topmost view controller.
///
/// A SwiftUI sheet attached to the Visit section sits inside the church card's own sheet.
/// The next list update, including the travel-time line, dismissed that page immediately.
enum SafariPresenter {
    static let identifier = "place-safari"

    @MainActor
    static func open(_ url: URL) {
        guard let presenter = topPresenter() else { return }
        if presenter is SFSafariViewController { return }
        let page = MarkedSafari(url: url)
        page.dismissButtonStyle = .close
        page.modalPresentationStyle = .pageSheet
        presenter.present(page, animated: true)
    }

    @MainActor
    private static func topPresenter() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let root = scene?.windows.first { $0.isKeyWindow }?.rootViewController
            ?? scene?.windows.first?.rootViewController
        var controller = root
        while let presented = controller?.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }
}

private final class MarkedSafari: SFSafariViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.accessibilityIdentifier = SafariPresenter.identifier
    }
}

enum AppleMaps {
    static func open(name: String, coordinate: LonLat, walking: Bool) {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lon))
        let item = MKMapItem(placemark: placemark)
        item.name = name
        let mode = walking ? MKLaunchOptionsDirectionsModeWalking : MKLaunchOptionsDirectionsModeDriving
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: mode])
    }
}

enum GoogleMaps {
    static var installed: Bool {
        guard let url = URL(string: "comgooglemaps://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static func open(coordinate: LonLat, walking: Bool) {
        let mode = walking ? "walking" : "driving"
        guard let url = URL(string: "comgooglemaps://?daddr=\(coordinate.lat),\(coordinate.lon)&directionsmode=\(mode)") else { return }
        UIApplication.shared.open(url)
    }
}

enum VisitRouting {
    static func phoneURL(_ raw: String) -> URL? {
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 10 else { return nil }
        return URL(string: "tel:\(digits)")
    }

    static func travelLine(to coordinate: LonLat, walking: Bool) async -> String {
        let status = CLLocationManager().authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else { return "" }
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lon))
        request.destination = MKMapItem(placemark: placemark)
        request.transportType = walking ? .walking : .automobile
        guard let eta = try? await MKDirections(request: request).calculateETA() else { return "" }
        let minutes = max(1, Int((eta.expectedTravelTime / 60).rounded()))
        let kilometers = eta.distance / 1000
        if kilometers < 1 {
            return "\(minutes) min · \(Int(eta.distance.rounded())) m"
        }
        return String(format: "%d min · %.1f km", minutes, kilometers)
    }
}

actor WikidataWebsite {
    static let shared = WikidataWebsite()
    private var cache: [String: URL?] = [:]

    func website(for qid: String) async -> URL? {
        if let cached = cache[qid] { return cached }
        guard let url = URL(string: "https://www.wikidata.org/w/api.php?action=wbgetclaims&entity=\(qid)&property=P856&format=json") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("PilgrimAtlas/1.0 (https://github.com/macdadyj/pilgrim-atlas)", forHTTPHeaderField: "User-Agent")
        let found: URL?
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse,
           (200..<300).contains(http.statusCode) {
            found = SiteLink.wikidataWebsite(from: data)
        } else {
            found = nil
        }
        cache[qid] = found
        return found
    }
}

#endif
