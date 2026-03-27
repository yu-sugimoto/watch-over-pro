import Foundation

enum PersonStatus: String, Codable, Sendable {
    case online
    case paused
    case offline

    var label: String {
        switch self {
        case .online: "オンライン"
        case .paused: "共有停止中"
        case .offline: "オフライン"
        }
    }

    var icon: String {
        switch self {
        case .online: "checkmark.circle.fill"
        case .paused: "pause.circle.fill"
        case .offline: "wifi.slash"
        }
    }
}
