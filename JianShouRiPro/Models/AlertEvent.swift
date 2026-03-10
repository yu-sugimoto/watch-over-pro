import Foundation

nonisolated struct AlertEvent: Codable, Sendable, Identifiable {
    let id: UUID
    let personId: UUID
    let type: AlertType
    let message: String
    let severity: Double
    var isRead: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        personId: UUID,
        type: AlertType,
        message: String,
        severity: Double,
        isRead: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.personId = personId
        self.type = type
        self.message = message
        self.severity = severity
        self.isRead = isRead
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case personId = "person_id"
        case type
        case message
        case severity
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}
