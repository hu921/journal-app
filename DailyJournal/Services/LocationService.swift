import Foundation
import CoreLocation

/// Gets the current location once and turns it into a short place name.
@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    struct Place {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentPlace() async -> Place? {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        let location: CLLocation? = await withCheckedContinuation { cont in
            continuation = cont
            manager.requestLocation()
        }
        guard let location else { return nil }
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        let name = [placemark?.name, placemark?.locality]
            .compactMap { $0 }
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            .joined(separator: ", ")
        return Place(
            name: name.isEmpty ? "Unknown place" : name,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            continuation?.resume(returning: locations.last)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }
}
