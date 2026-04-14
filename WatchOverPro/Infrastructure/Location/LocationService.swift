import Foundation
import CoreLocation

@Observable
@MainActor
final class LocationService {
    var currentLatitude: Double?
    var currentLongitude: Double?

    private var backgroundSession: CLBackgroundActivitySession?
    private var locationTask: Task<Void, Never>?

    func start() {
        guard locationTask == nil else { return }
        startBackgroundSessionIfAuthorized()
        locationTask = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    guard let self, !Task.isCancelled else { break }
                    if let location = update.location {
                        self.currentLatitude = location.coordinate.latitude
                        self.currentLongitude = location.coordinate.longitude
                    }
                    if self.backgroundSession == nil {
                        self.startBackgroundSessionIfAuthorized()
                    }
                }
            } catch {}
        }
    }

    func stop() {
        locationTask?.cancel()
        locationTask = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
        UserDefaults.standard.set(false, forKey: "bg_location_active")
        currentLatitude = nil
        currentLongitude = nil
    }

    private func startBackgroundSessionIfAuthorized() {
        guard backgroundSession == nil else { return }
        let status = CLLocationManager().authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else { return }
        backgroundSession = CLBackgroundActivitySession()
        UserDefaults.standard.set(true, forKey: "bg_location_active")
    }
}
