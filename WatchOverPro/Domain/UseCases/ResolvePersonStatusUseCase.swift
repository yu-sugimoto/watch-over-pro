import Foundation

struct ResolvePersonStatusUseCase: Sendable {
    /// Thresholds for status resolution
    private let staleThreshold: TimeInterval = 300    // 5 minutes
    private let offlineThreshold: TimeInterval = 900  // 15 minutes

    func execute(lastUpdated: Date?, isActive: Bool = true) -> PersonStatus {
        guard let lastUpdated else { return .offline }

        if !isActive {
            return .paused
        }

        let elapsed = Date().timeIntervalSince(lastUpdated)

        if elapsed < staleThreshold {
            return .online
        } else if elapsed < offlineThreshold {
            return .stale
        } else {
            return .offline
        }
    }
}
