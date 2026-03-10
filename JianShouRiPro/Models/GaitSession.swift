import Foundation

nonisolated struct GaitSession: Codable, Sendable, Identifiable {
    let id: UUID
    let startDate: Date
    var endDate: Date?
    var samples: [GaitSample]
    var anomalies: [AnomalyEvent]
    var averageCadence: Double
    var averagePace: Double
    var riskLevel: GaitRiskLevel
    var stepCount: Int

    init(id: UUID = UUID(), startDate: Date = Date()) {
        self.id = id
        self.startDate = startDate
        self.endDate = nil
        self.samples = []
        self.anomalies = []
        self.averageCadence = 0
        self.averagePace = 0
        self.riskLevel = .normal
        self.stepCount = 0
    }

    var duration: TimeInterval {
        (endDate ?? Date()).timeIntervalSince(startDate)
    }

    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}
