import Foundation
import UserNotifications

@Observable
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    var isAuthorized = false

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    nonisolated func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
        await MainActor.run { isAuthorized = authorized }
    }

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func registerCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_DETAIL",
            title: "詳細を見る",
            options: .foreground
        )

        let generalCategory = UNNotificationCategory(
            identifier: "GENERAL",
            actions: [viewAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([generalCategory])
    }
}
