import Foundation
import CoreMotion

@MainActor
enum PermissionManager {
    static func requestWatchedModePermissions(gaitViewModel: GaitViewModel, hasLinkedPerson: Bool) async {
        await NotificationService.shared.requestAuthorization()
        await gaitViewModel.requestHealthAuthorization()

        if CMMotionActivityManager.isActivityAvailable(),
           CMMotionActivityManager.authorizationStatus() == .notDetermined {
            let manager = CMMotionActivityManager()
            let now = Date()
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                manager.queryActivityStarting(from: now.addingTimeInterval(-1), to: now, to: .main) { _, _ in
                    continuation.resume()
                }
            }
            _ = manager
        }

        if hasLinkedPerson {
            let helper = LocationPermissionHelper()
            await helper.requestWhenInUseIfNeeded()
        }
    }
}
