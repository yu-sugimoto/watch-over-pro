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

    func sendAlertNotification(personName: String, message: String, alertId: UUID) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "⚠️ \(personName)"
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "ALERT"
        content.userInfo = ["alertId": alertId.uuidString]

        let request = UNNotificationRequest(
            identifier: alertId.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendUrgentAlertNotification(personName: String, message: String, alertId: UUID) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "🚨 緊急: \(personName)"
        content.body = message
        content.sound = .defaultCritical
        content.categoryIdentifier = "URGENT_ALERT"
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["alertId": alertId.uuidString]

        let request = UNNotificationRequest(
            identifier: alertId.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendInactivityNotification(personName: String, duration: String, alertId: UUID) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "📡 \(personName)"
        content.body = "\(personName)さんの活動が\(duration)確認できません"
        content.sound = .default
        content.categoryIdentifier = "INACTIVITY"
        content.userInfo = ["alertId": alertId.uuidString]

        let request = UNNotificationRequest(
            identifier: "inactivity-\(alertId.uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendOfflineNotification(personName: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(personName)"
        content.body = "\(personName)さんのデバイスがオフラインです"
        content.sound = .default
        content.categoryIdentifier = "OFFLINE"

        let request = UNNotificationRequest(
            identifier: "offline-\(personName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
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

        let alertCategory = UNNotificationCategory(
            identifier: "ALERT",
            actions: [viewAction],
            intentIdentifiers: []
        )

        let urgentCategory = UNNotificationCategory(
            identifier: "URGENT_ALERT",
            actions: [viewAction],
            intentIdentifiers: []
        )

        let inactivityCategory = UNNotificationCategory(
            identifier: "INACTIVITY",
            actions: [viewAction],
            intentIdentifiers: []
        )

        let offlineCategory = UNNotificationCategory(
            identifier: "OFFLINE",
            actions: [viewAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            alertCategory, urgentCategory, inactivityCategory, offlineCategory
        ])
    }
}
