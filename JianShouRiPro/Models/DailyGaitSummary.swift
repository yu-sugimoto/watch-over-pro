import Foundation

nonisolated struct DailyGaitSummary: Codable, Sendable, Identifiable {
    let id: UUID
    let date: Date
    var totalSteps: Int
    var averageCadence: Double
    var averagePace: Double
    var anomalyCount: Int
    var riskLevel: GaitRiskLevel
    var sessionCount: Int

    init(id: UUID = UUID(), date: Date, totalSteps: Int = 0, averageCadence: Double = 0, averagePace: Double = 0, anomalyCount: Int = 0, riskLevel: GaitRiskLevel = .normal, sessionCount: Int = 0) {
        self.id = id
        self.date = date
        self.totalSteps = totalSteps
        self.averageCadence = averageCadence
        self.averagePace = averagePace
        self.anomalyCount = anomalyCount
        self.riskLevel = riskLevel
        self.sessionCount = sessionCount
    }
}
