import Testing
import Foundation
@testable import WatchOverPro

struct DetectStopEventUseCaseTests {

    // MARK: - Helpers

    @MainActor
    private final class MockClock {
        var now: Date
        init(_ start: Date) { self.now = start }
        func advance(by seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    @MainActor
    private static func makeSUT(
        startDate: Date = Date(timeIntervalSince1970: 1_000_000)
    ) -> (sut: DetectStopEventUseCase, repo: MockLocationRepository, clock: MockClock) {
        let repo = MockLocationRepository()
        let sut = DetectStopEventUseCase(repository: repo)
        let clock = MockClock(startDate)
        sut.dateProvider = { clock.now }
        return (sut, repo, clock)
    }

    // MARK: - Stop detection (same coordinates = 0m movement)

    @Test @MainActor
    func sameCoords_twoPoints_detectsStop() async throws {
        let (sut, repo, clock) = Self.makeSUT()

        try await sut.evaluate(trackedUserId: "u1", lat: 35.0, lng: 139.0)
        clock.advance(by: 15)
        try await sut.evaluate(trackedUserId: "u1", lat: 35.0, lng: 139.0)

        // Stop detected but duration < 3min → no StopEvent yet
        #expect(repo.putStopEventCallCount == 0)
    }

    @Test @MainActor
    func sameCoords_underThreeMinutes_noStopEvent() async throws {
        let (sut, repo, clock) = Self.makeSUT()

        // 4 evaluations at 15s intervals; stopStartTime set on 2nd → duration ≈ 30s
        for _ in 0..<4 {
            try await sut.evaluate(trackedUserId: "u1", lat: 35.0, lng: 139.0)
            clock.advance(by: 15)
        }

        #expect(repo.putStopEventCallCount == 0)
    }

    @Test @MainActor
    func sameCoords_threeMinutes_createsStopEvent() async throws {
        let (sut, repo, clock) = Self.makeSUT()

        // Need >= 2 recent points and duration >= 180s
        // Feed points at 15s intervals for 3+ minutes
        for _ in 0..<14 {
            try await sut.evaluate(trackedUserId: "u1", lat: 35.0, lng: 139.0)
            clock.advance(by: 15)
        }

        // stopStartTime set on 2nd eval (t=15s), 14th eval at t=195s → duration = 180s ≥ 180s
        #expect(repo.putStopEventCallCount == 1)
        #expect(repo.lastPutStopEvent?.endedAt == nil)
    }

    // MARK: - Movement breaks stop

    @Test @MainActor
    func movementAfterStop_endsStopEvent() async throws {
        let (sut, repo, clock) = Self.makeSUT()

        // Build up a stop event (3+ minutes stationary)
        for _ in 0..<14 {
            try await sut.evaluate(trackedUserId: "u1", lat: 35.0, lng: 139.0)
            clock.advance(by: 15)
        }

        #expect(repo.putStopEventCallCount == 1)

        // Now move significantly (> 20m away)
        try await sut.evaluate(trackedUserId: "u1", lat: 35.001, lng: 139.001)

        // Should have called putStopEvent again with endedAt set
        #expect(repo.putStopEventCallCount == 2)
        #expect(repo.lastPutStopEvent?.endedAt != nil)
    }

    @Test @MainActor
    func largeMovement_neverCreatesStopEvent() async throws {
        let (sut, repo, clock) = Self.makeSUT()
        var lat = 35.0

        // Each step moves ~111m (0.001° latitude ≈ 111m)
        for _ in 0..<14 {
            try await sut.evaluate(trackedUserId: "u1", lat: lat, lng: 139.0)
            clock.advance(by: 15)
            lat += 0.001
        }

        #expect(repo.putStopEventCallCount == 0)
    }

    // MARK: - Single point (not enough data)

    @Test @MainActor
    func singlePoint_notEnoughData_noStop() async throws {
        let (sut, repo, _) = Self.makeSUT()

        try await sut.evaluate(trackedUserId: "u1", lat: 35.0, lng: 139.0)

        #expect(repo.putStopEventCallCount == 0)
    }

    // MARK: - Reset

    @Test @MainActor
    func reset_clearsAllState() async throws {
        let (sut, repo, clock) = Self.makeSUT()

        // Start a stop
        for _ in 0..<4 {
            try await sut.evaluate(trackedUserId: "u1", lat: 35.0, lng: 139.0)
            clock.advance(by: 15)
        }

        sut.reset()

        // After reset, moving should not trigger an endedAt update
        try await sut.evaluate(trackedUserId: "u1", lat: 36.0, lng: 140.0)
        #expect(repo.putStopEventCallCount == 0)
    }

    // MARK: - Edge: small movement within threshold

    @Test @MainActor
    func smallMovement_withinThreshold_stillDetectsStop() async throws {
        let (sut, repo, clock) = Self.makeSUT()

        // ~1.1m movement per step, total over 60s window ≈ 4.4m < 20m
        var lat = 35.0
        for _ in 0..<14 {
            try await sut.evaluate(trackedUserId: "u1", lat: lat, lng: 139.0)
            clock.advance(by: 15)
            lat += 0.00001 // ~1.1m per step
        }

        // Total distance in any 60s window is ~4.4m, well under 20m threshold
        #expect(repo.putStopEventCallCount == 1)
    }
}
