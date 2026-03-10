import Foundation

nonisolated struct GaitSample: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let cadence: Double
    let pace: Double
    let accelerationMagnitude: Double
    let rotationMagnitude: Double

    init(id: UUID = UUID(), timestamp: Date = Date(), cadence: Double, pace: Double, accelerationMagnitude: Double = 0, rotationMagnitude: Double = 0) {
        self.id = id
        self.timestamp = timestamp
        self.cadence = cadence
        self.pace = pace
        self.accelerationMagnitude = accelerationMagnitude
        self.rotationMagnitude = rotationMagnitude
    }
}
