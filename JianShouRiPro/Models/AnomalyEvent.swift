import Foundation

nonisolated struct AnomalyEvent: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let type: AnomalyType
    let severity: Double
    let description: String

    init(id: UUID = UUID(), timestamp: Date = Date(), type: AnomalyType, severity: Double, description: String) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.severity = severity
        self.description = description
    }
}

nonisolated enum AnomalyType: String, Codable, Sendable {
    case cadenceIrregularity
    case paceFluctuation
    case asymmetry
    case instability
    case suddenStop
}
