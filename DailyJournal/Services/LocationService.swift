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
        return await Self.place(for: location.coordinate)
    }

    /// Turns a coordinate into a short place name like "Taipei 101, Taipei".
    static func place(for coordinate: CLLocationCoordinate2D) async -> Place {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        let name = [placemark?.name, placemark?.locality]
            .compactMap { $0 }
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            .joined(separator: ", ")
        return Place(
            name: name.isEmpty ? String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude) : name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
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
