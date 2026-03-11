import Foundation

enum AlertType: String, Codable, Sendable {
    case locationStale = "location_stale"
    case offline = "offline"
    case stopDetected = "stop_detected"
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = AlertType(rawValue: rawValue) ?? .unknown
    }
}
