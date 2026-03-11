import Foundation

enum PersonStatus: String, Codable, Sendable {
    case online
    case stale
    case offline

    var label: String {
        switch self {
        case .online: "オンライン"
        case .stale: "更新なし"
        case .offline: "オフライン"
        }
    }

    var icon: String {
        switch self {
        case .online: "checkmark.circle.fill"
        case .stale: "exclamationmark.triangle.fill"
        case .offline: "wifi.slash"
        }
    }
}
