import Foundation

enum StatusResolver {
    static func resolve(gaitRisk: GaitRiskLevel, inactivity: InactivityLevel) -> PersonStatus {
        let gaitStatus: PersonStatus = switch gaitRisk {
        case .normal: .safe
        case .elevated: .warning
        case .high: .alert
        }
        let inactivityStatus: PersonStatus = switch inactivity {
        case .active, .idle: .safe
        case .warning: .warning
        case .critical: .alert
        }
        let priority: [PersonStatus] = [.alert, .warning, .safe]
        for p in priority {
            if gaitStatus == p || inactivityStatus == p { return p }
        }
        return .safe
    }

    static func fromRiskLevel(_ riskLevel: GaitRiskLevel) -> PersonStatus {
        switch riskLevel {
        case .normal: .safe
        case .elevated: .warning
        case .high: .alert
        }
    }
}
