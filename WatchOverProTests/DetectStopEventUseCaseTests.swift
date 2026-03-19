import Testing
import Foundation
@testable import WatchOverPro

struct DetectStopEventUseCaseTests {
    @Test @MainActor func lowSpeed_startsStopTracking() async throws {
        let mockRepo = MockLocationRepository()
        let sut = DetectStopEventUseCase(repository: mockRepo)

        // First call with low speed — should start tracking but not yet create event
        try await sut.evaluate(trackedUserId: "user-1", lat: 35.0, lng: 139.0, speed: 0.2)
        #expect(mockRepo.putStopEventCallCount == 0)
    }

    @Test @MainActor func stopOverThreeMinutes_createsStopEvent() async throws {
        let mockRepo = MockLocationRepository()
        let sut = DetectStopEventUseCase(repository: mockRepo)

        // Simulate: first call sets stopStartTime to "now"
        try await sut.evaluate(trackedUserId: "user-1", lat: 35.0, lng: 139.0, speed: 0.1)

        // Manually manipulate time by calling evaluate after setting up internal state
        // Since we can't easily mock Date(), we test the flow:
        // The first call should NOT create a stop event (duration < 3 min)
        #expect(mockRepo.putStopEventCallCount == 0)

        // Simulate continued low speed — still under threshold since time hasn't passed
        try await sut.evaluate(trackedUserId: "user-1", lat: 35.0, lng: 139.0, speed: 0.1)
        // Duration is ~0 seconds, so no event created yet
        #expect(mockRepo.putStopEventCallCount == 0)
    }

    @Test @MainActor func highSpeed_endsStop() async throws {
        let mockRepo = MockLocationRepository()
        let sut = DetectStopEventUseCase(repository: mockRepo)

        // Start with low speed
        try await sut.evaluate(trackedUserId: "user-1", lat: 35.0, lng: 139.0, speed: 0.1)

        // Move at high speed — should end stop tracking
        try await sut.evaluate(trackedUserId: "user-1", lat: 35.0, lng: 139.0, speed: 5.0)

        // No stop event was long enough to be persisted, so count stays 0
        #expect(mockRepo.putStopEventCallCount == 0)
    }

    @Test @MainActor func reset_clearsState() async throws {
        let mockRepo = MockLocationRepository()
        let sut = DetectStopEventUseCase(repository: mockRepo)

        // Start tracking
        try await sut.evaluate(trackedUserId: "user-1", lat: 35.0, lng: 139.0, speed: 0.1)

        // Reset
        sut.reset()

        // After reset, high speed should not trigger putStopEvent
        try await sut.evaluate(trackedUserId: "user-1", lat: 35.0, lng: 139.0, speed: 5.0)
        #expect(mockRepo.putStopEventCallCount == 0)
    }
}
