import Foundation

nonisolated struct HealthMetrics: Codable, Sendable {
    var walkingSpeed: Double?
    var stepLength: Double?
    var walkingAsymmetry: Double?
    var doubleSupport: Double?
    var walkingSteadiness: Double?
    var lastUpdated: Date?

    static let empty = HealthMetrics()
}
