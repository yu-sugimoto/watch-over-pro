import Foundation

struct StopEvent: Codable, Sendable, Identifiable {
    var id: String { "\(trackedUserIdDate)#\(stopStartEpochMs)" }
    let trackedUserIdDate: String
    let stopStartEpochMs: Double
    let lat: Double
    let lng: Double
    let startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int

    init(
        trackedUserIdDate: String,
        stopStartEpochMs: Double,
        lat: Double,
        lng: Double,
        startedAt: Date,
        endedAt: Date? = nil,
        durationSeconds: Int = 0
    ) {
        self.trackedUserIdDate = trackedUserIdDate
        self.stopStartEpochMs = stopStartEpochMs
        self.lat = lat
        self.lng = lng
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
    }
}
