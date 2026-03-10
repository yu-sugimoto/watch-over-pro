import Foundation

nonisolated struct PairingCode: Codable, Sendable, Identifiable {
    let id: UUID
    let code: String
    let personId: UUID
    let watcherDeviceId: String
    var isUsed: Bool
    let createdAt: Date
    let expiresAt: Date

    init(
        id: UUID = UUID(),
        code: String,
        personId: UUID,
        watcherDeviceId: String = "",
        isUsed: Bool = false,
        createdAt: Date = Date(),
        expiresAt: Date = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date().addingTimeInterval(86400)
    ) {
        self.id = id
        self.code = code
        self.personId = personId
        self.watcherDeviceId = watcherDeviceId
        self.isUsed = isUsed
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    enum CodingKeys: String, CodingKey {
        case id, code
        case personId = "person_id"
        case watcherDeviceId = "watcher_device_id"
        case isUsed = "is_used"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}
