import Foundation

@MainActor
final class DetectStopEventUseCase {
    private let repository: any LocationRepositoryProtocol
    private let speedThreshold: Double = 0.5 // m/s
    private let minStopDuration: TimeInterval = 180 // 3 minutes

    private var stopStartTime: Date?
    private var stopLat: Double?
    private var stopLng: Double?
    private var currentStopEvent: StopEvent?

    init(repository: any LocationRepositoryProtocol) {
        self.repository = repository
    }

    func evaluate(trackedUserId: String, lat: Double, lng: Double, speed: Double?) async throws {
        let currentSpeed = speed ?? 0

        if currentSpeed < speedThreshold {
            if stopStartTime == nil {
                stopStartTime = Date()
                stopLat = lat
                stopLng = lng
            }

            if let start = stopStartTime {
                let duration = Date().timeIntervalSince(start)
                if duration >= minStopDuration && currentStopEvent == nil {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyyMMdd"
                    let dateString = dateFormatter.string(from: start)

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
                finalEvent.endedAt = Date()
                finalEvent.durationSeconds = Int(Date().timeIntervalSince(start))
                try await repository.putStopEvent(finalEvent)
            }
            stopStartTime = nil
            stopLat = nil
            stopLng = nil
            currentStopEvent = nil
        }
    }

    func reset() {
        stopStartTime = nil
        stopLat = nil
        stopLng = nil
        currentStopEvent = nil
    }
}
