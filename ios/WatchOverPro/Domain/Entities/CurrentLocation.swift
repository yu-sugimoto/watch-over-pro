import Foundation

struct CurrentLocation: Codable, Sendable, Identifiable {
    var id: String { trackedUserId }
    let trackedUserId: String
    var lat: Double
    var lng: Double
    var altitude: Double?
    var accuracy: Double?
    var speed: Double?
    var heading: Double?
    var batteryLevel: Double?
    var isActive: Bool
    var updatedAt: Date

    init(
        trackedUserId: String,
        lat: Double,
        lng: Double,
        altitude: Double? = nil,
        accuracy: Double? = nil,
        speed: Double? = nil,
        heading: Double? = nil,
        batteryLevel: Double? = nil,
        isActive: Bool = true,
        updatedAt: Date = Date()
    ) {
        self.trackedUserId = trackedUserId
        self.lat = lat
        self.lng = lng
        self.altitude = altitude
        self.accuracy = accuracy
        self.speed = speed
        self.heading = heading
        self.batteryLevel = batteryLevel
        self.isActive = isActive
        self.updatedAt = updatedAt
    }
}
