import Foundation

nonisolated enum AlertType: String, Codable, Sendable {
    case gaitAnomaly = "gait_anomaly"
    case inactivity = "inactivity"
    case offline = "offline"
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = AlertType(rawValue: rawValue) ?? .unknown
    }
}
