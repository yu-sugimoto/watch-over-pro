import Foundation

nonisolated struct DeviceLink: Codable, Sendable, Identifiable {
    let id: UUID
    let personId: UUID
    let watchedDeviceId: String
    let watcherDeviceId: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        personId: UUID,
        watchedDeviceId: String,
        watcherDeviceId: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.personId = personId
        self.watchedDeviceId = watchedDeviceId
        self.watcherDeviceId = watcherDeviceId
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case personId = "person_id"
        case watchedDeviceId = "watched_device_id"
        case watcherDeviceId = "watcher_device_id"
        case createdAt = "created_at"
    }
}
