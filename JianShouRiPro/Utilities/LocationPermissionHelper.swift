import Foundation
import CoreLocation

@MainActor
final class LocationPermissionHelper: NSObject {
    private var continuation: CheckedContinuation<Void, Never>?
    private var locationManager: CLLocationManager?
    private var hasResumed = false

    func requestWhenInUseIfNeeded() async {
        let status = CLLocationManager().authorizationStatus
        guard status == .notDetermined else { return }

        let manager = CLLocationManager()
        locationManager = manager
        hasResumed = false
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.continuation = cont
            manager.delegate = self
            manager.requestWhenInUseAuthorization()
        }
        manager.delegate = nil
        locationManager = nil
        continuation = nil
    }

    private func resumeContinuationOnce() {
        guard !hasResumed else { return }
        hasResumed = true
        continuation?.resume()
        continuation = nil
    }
}

extension LocationPermissionHelper: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let status = manager.authorizationStatus
            guard status != .notDetermined else { return }
            self.resumeContinuationOnce()
        }
    }
}
