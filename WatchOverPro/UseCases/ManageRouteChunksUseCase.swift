import Foundation

@MainActor
final class ManageRouteChunksUseCase {
    private let repository: any LocationRepositoryProtocol
    private var pendingPoints: [RoutePoint] = []
    private var chunkStartTime: Date?
    private let flushInterval: TimeInterval = 300 // 5 minutes

    init(repository: any LocationRepositoryProtocol) {
        self.repository = repository
    }

    func addPoint(lat: Double, lng: Double, altitude: Double?, speed: Double?) {
        let point = RoutePoint(
            lat: lat,
            lng: lng,
            altitude: altitude,
            speed: speed,
            timestamp: Date()
        )
        if chunkStartTime == nil {
            chunkStartTime = Date()
        }
        pendingPoints.append(point)
    }

    var shouldFlush: Bool {
        guard let start = chunkStartTime else { return false }
        return Date().timeIntervalSince(start) >= flushInterval
    }

    func flush(trackedUserId: String) async throws {
        guard !pendingPoints.isEmpty, let start = chunkStartTime else { return }

        let dateString = DateFormatters.yyyyMMdd.string(from: start)

        let chunk = RouteChunk(
            trackedUserIdDate: "\(trackedUserId)#\(dateString)",
            chunkStartEpochMs: start.timeIntervalSince1970 * 1000,
            points: pendingPoints
        )

        try await repository.appendRouteChunk(chunk)
        pendingPoints.removeAll()
        chunkStartTime = nil
    }

    func reset() {
        pendingPoints.removeAll()
        chunkStartTime = nil
    }
}
