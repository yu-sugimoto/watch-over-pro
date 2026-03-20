import Foundation

@MainActor
final class DetectStopEventUseCase {
    private let repository: any LocationRepositoryProtocol
    private let distanceThreshold: Double = 20.0 // meters over 1 min
    private let minStopDuration: TimeInterval = 180 // 3 minutes
    private let maxPointAge: TimeInterval = 65 // seconds

    var dateProvider: () -> Date = { Date() }

    private var recentPoints: [(lat: Double, lng: Double, time: Date)] = []
    private var stopStartTime: Date?
    private var stopLat: Double?
    private var stopLng: Double?
    private var currentStopEvent: StopEvent?

    init(repository: any LocationRepositoryProtocol) {
        self.repository = repository
    }

    func evaluate(trackedUserId: String, lat: Double, lng: Double) async throws {
        let now = dateProvider()

        recentPoints.append((lat, lng, now))
        recentPoints.removeAll { now.timeIntervalSince($0.time) > maxPointAge }

        let distance = totalDistance(of: recentPoints)
        let isStopped = recentPoints.count >= 2 && distance <= distanceThreshold

        if isStopped {
            if stopStartTime == nil {
                stopStartTime = now
                stopLat = lat
                stopLng = lng
            }

            if let start = stopStartTime {
                let duration = now.timeIntervalSince(start)
                if duration >= minStopDuration && currentStopEvent == nil {
                    let dateString = DateFormatters.yyyyMMdd.string(from: start)

                    let event = StopEvent(
                        trackedUserIdDate: "\(trackedUserId)#\(dateString)",
                        stopStartEpochMs: start.timeIntervalSince1970 * 1000,
                        lat: stopLat ?? lat,
                        lng: stopLng ?? lng,
                        startedAt: start,
                        durationSeconds: Int(duration)
                    )
                    try await repository.putStopEvent(event)
                    currentStopEvent = event
                }
            }
        } else {
            if let event = currentStopEvent, let start = stopStartTime {
                var finalEvent = event
                finalEvent.endedAt = now
                finalEvent.durationSeconds = Int(now.timeIntervalSince(start))
                try await repository.putStopEvent(finalEvent)
            }
            stopStartTime = nil
            stopLat = nil
            stopLng = nil
            currentStopEvent = nil
        }
    }

    func reset() {
        recentPoints.removeAll()
        stopStartTime = nil
        stopLat = nil
        stopLng = nil
        currentStopEvent = nil
    }

    private func totalDistance(of points: [(lat: Double, lng: Double, time: Date)]) -> Double {
        guard points.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 1..<points.count {
            total += haversine(
                lat1: points[i - 1].lat, lng1: points[i - 1].lng,
                lat2: points[i].lat, lng2: points[i].lng
            )
        }
        return total
    }

    private func haversine(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let R = 6_371_000.0 // Earth radius in meters
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}
