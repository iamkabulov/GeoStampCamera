import CoreLocation

/// Отслеживает текущую позицию и человекочитаемый адрес.
@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var location: CLLocation?
    @Published private(set) var address: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastGeocoded: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    /// Строки для наложения: координаты и адрес (если есть).
    var overlayLines: [String] {
        guard let loc = location else { return ["Локация недоступна"] }
        var lines = [String(format: "%.6f, %.6f  ±%.0f м",
                            loc.coordinate.latitude,
                            loc.coordinate.longitude,
                            loc.horizontalAccuracy)]
        if let address { lines.append(address) }
        return lines
    }

    private func reverseGeocodeIfNeeded(_ loc: CLLocation) {
        if let last = lastGeocoded, last.distance(from: loc) < 50 { return }
        lastGeocoded = loc
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            guard let p = placemarks?.first else { return }
            let parts = [p.thoroughfare, p.subThoroughfare, p.locality, p.country]
                .compactMap { $0 }
            Task { @MainActor in self?.address = parts.joined(separator: ", ") }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.location = loc
            self.reverseGeocodeIfNeeded(loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}
