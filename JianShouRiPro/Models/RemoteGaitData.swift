import Foundation

nonisolated struct RemoteGaitData: Codable, Sendable, Identifiable {
    let id: UUID
    let personId: UUID
    let deviceId: String
    let timestamp: Date
    var steps: Int
    var cadence: Double
    var pace: Double
    var riskLevel: String
    var anomalyCount: Int
    var walkingSteadiness: Double?
    var isWalking: Bool
    var accelerationMagnitude: Double
    var latitude: Double?
    var longitude: Double?
    var userId: String?

    init(
        id: UUID = UUID(),
        personId: UUID,
        deviceId: String,
        timestamp: Date = Date(),
        steps: Int = 0,
        cadence: Double = 0,
        pace: Double = 0,
        riskLevel: String = "normal",
        anomalyCount: Int = 0,
        walkingSteadiness: Double? = nil,
        isWalking: Bool = false,
        accelerationMagnitude: Double = 0,
        latitude: Double? = nil,
        longitude: Double? = nil,
        userId: String? = nil
    ) {
        self.id = id
        self.personId = personId
        self.deviceId = deviceId
        self.timestamp = timestamp
        self.steps = steps
        self.cadence = cadence
        self.pace = pace
        self.riskLevel = riskLevel
        self.anomalyCount = anomalyCount
        self.walkingSteadiness = walkingSteadiness
        self.isWalking = isWalking
        self.accelerationMagnitude = accelerationMagnitude
        self.latitude = latitude
        self.longitude = longitude
        self.userId = userId
    }

    enum CodingKeys: String, CodingKey {
        case id
        case personId = "person_id"
        case deviceId = "device_id"
        case timestamp
        case steps, cadence, pace
        case riskLevel = "risk_level"
        case anomalyCount = "anomaly_count"
        case walkingSteadiness = "walking_steadiness"
        case isWalking = "is_walking"
        case accelerationMagnitude = "acceleration_magnitude"
        case latitude
        case longitude
        case userId = "user_id"
    }
}
