import Foundation

struct RoutePoint: Codable, Sendable {
    let lat: Double
    let lng: Double
    let altitude: Double?
    let speed: Double?
    let timestamp: Date
}

struct RouteChunk: Codable, Sendable, Identifiable {
    var id: String { "\(trackedUserIdDate)#\(chunkStartEpochMs)" }
    let trackedUserIdDate: String
    let chunkStartEpochMs: Double
    var points: [RoutePoint]
    let createdAt: Date

    init(
        trackedUserIdDate: String,
        chunkStartEpochMs: Double,
        points: [RoutePoint],
        createdAt: Date = Date()
    ) {
        self.trackedUserIdDate = trackedUserIdDate
        self.chunkStartEpochMs = chunkStartEpochMs
        self.points = points
        self.createdAt = createdAt
    }
}
