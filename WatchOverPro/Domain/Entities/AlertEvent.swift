import Foundation

struct AlertEvent: Codable, Sendable, Identifiable {
    let id: UUID
    let memberId: String
    let type: AlertType
    let message: String
    let severity: Double
    var isRead: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        memberId: String,
        type: AlertType,
        message: String,
        severity: Double,
        isRead: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.memberId = memberId
        self.type = type
        self.message = message
        self.severity = severity
        self.isRead = isRead
        self.createdAt = createdAt
    }
}
