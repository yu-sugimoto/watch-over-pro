import Foundation

@MainActor
enum PermissionManager {
    static func requestWatchedModePermissions(hasLinkedPerson: Bool) async {
        await NotificationService.shared.requestAuthorization()

        if hasLinkedPerson {
            let helper = LocationPermissionHelper()
            await helper.requestWhenInUseIfNeeded()
        }
    }
}
