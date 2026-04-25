import Foundation
import CoreLocation
import UIKit

@Observable
@MainActor
final class LocationAuthManager: NSObject, CLLocationManagerDelegate {
    var authorizationStatus: CLAuthorizationStatus
    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var isAlwaysAuthorized: Bool {
        authorizationStatus == .authorizedAlways
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.authorizationStatus = status
        }
    }
}
