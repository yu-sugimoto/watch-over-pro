import Foundation

nonisolated enum PersonStatus: String, Codable, Sendable {
    case safe
    case warning
    case alert
    case offline

    var label: String {
        switch self {
        case .safe: "安全"
        case .warning: "注意"
        case .alert: "警告"
        case .offline: "オフライン"
        }
    }

    var icon: String {
        switch self {
        case .safe: "checkmark.shield.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .alert: "xmark.shield.fill"
        case .offline: "wifi.slash"
        }
    }
}
