import Foundation

struct ResolvePersonStatusUseCase: Sendable {
    /// Threshold for offline status (5 minutes)
    private let offlineThreshold: TimeInterval = 300

    func execute(lastUpdated: Date?, isActive: Bool = true) -> PersonStatus {
        guard let lastUpdated else { return .offline }

        if !isActive {
            return .paused
        }

        let elapsed = Date().timeIntervalSince(lastUpdated)

        if elapsed < offlineThreshold {
            return .online
        } else {
            return .offline
        }
    }
}
