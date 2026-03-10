import Foundation

nonisolated struct WatchPerson: Codable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var relationship: Relationship
    var age: Int
    var notes: String
    var colorHex: String
    var status: PersonStatus
    var lastActivity: Date?
    var lastLocation: String?
    var latitude: Double?
    var longitude: Double?
    var todaySteps: Int
    var todayAnomalyCount: Int
    var walkingSteadiness: Double?
    var lastRiskLevel: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        relationship: Relationship,
        age: Int,
        notes: String = "",
        colorHex: String = "34C759",
        status: PersonStatus = .offline,
        lastActivity: Date? = nil,
        lastLocation: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        todaySteps: Int = 0,
        todayAnomalyCount: Int = 0,
        walkingSteadiness: Double? = nil,
        lastRiskLevel: String = "normal",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.age = age
        self.notes = notes
        self.colorHex = colorHex
        self.status = status
        self.lastActivity = lastActivity
        self.lastLocation = lastLocation
        self.latitude = latitude
        self.longitude = longitude
        self.todaySteps = todaySteps
        self.todayAnomalyCount = todayAnomalyCount
        self.walkingSteadiness = walkingSteadiness
        self.lastRiskLevel = lastRiskLevel
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case relationship
        case age
        case notes
        case colorHex = "color_hex"
        case status
        case lastActivity = "last_activity"
        case lastLocation = "last_location"
        case latitude
        case longitude
        case todaySteps = "today_steps"
        case todayAnomalyCount = "today_anomaly_count"
        case walkingSteadiness = "walking_steadiness"
        case lastRiskLevel = "last_risk_level"
        case createdAt = "created_at"
    }
}
