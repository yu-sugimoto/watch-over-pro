import Foundation

nonisolated enum GaitRiskLevel: String, Codable, Sendable, CaseIterable {
    case normal
    case elevated
    case high

    var label: String {
        switch self {
        case .normal: "正常"
        case .elevated: "注意"
        case .high: "高リスク"
        }
    }

    var systemImage: String {
        switch self {
        case .normal: "checkmark.shield.fill"
        case .elevated: "exclamationmark.triangle.fill"
        case .high: "xmark.shield.fill"
        }
    }
}
