import Foundation

nonisolated enum InactivityLevel: String, Sendable {
    case active
    case idle
    case warning
    case critical

    var label: String {
        switch self {
        case .active: "活動中"
        case .idle: "静止中"
        case .warning: "長時間非活動"
        case .critical: "要確認"
        }
    }

    var icon: String {
        switch self {
        case .active: "figure.walk.motion"
        case .idle: "moon.zzz.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "bell.badge.fill"
        }
    }
}

nonisolated struct InactivityStatus: Sendable {
    let level: InactivityLevel
    let lastActiveTime: Date?
    let lastDataTime: Date?
    let inactiveDuration: TimeInterval

    var durationText: String {
        let totalSeconds = Int(inactiveDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分間"
        }
        if minutes > 0 {
            return "\(minutes)分間"
        }
        return "1分未満"
    }

    static func evaluate(
        lastActiveTime: Date?,
        lastDataTime: Date?,
        isCurrentlyWalking: Bool
    ) -> InactivityStatus {
        if isCurrentlyWalking {
            return InactivityStatus(
                level: .active,
                lastActiveTime: lastActiveTime,
                lastDataTime: lastDataTime,
                inactiveDuration: 0
            )
        }

        let referenceTime = lastActiveTime ?? lastDataTime
        guard let referenceTime else {
            return InactivityStatus(
                level: .idle,
                lastActiveTime: nil,
                lastDataTime: lastDataTime,
                inactiveDuration: 0
            )
        }

        let elapsed = Date().timeIntervalSince(referenceTime)

        let level: InactivityLevel
        if elapsed < 60 * 60 {
            level = .idle
        } else if elapsed < 4 * 3600 {
            level = .warning
        } else {
            level = .critical
        }

        return InactivityStatus(
            level: level,
            lastActiveTime: lastActiveTime,
            lastDataTime: lastDataTime,
            inactiveDuration: elapsed
        )
    }
}
