import Testing
import Foundation
@testable import WatchOverPro

struct ManageRouteChunksUseCaseTests {
    @Test @MainActor func addPoint_accumulatesPendingPoints() {
        let mockRepo = MockLocationRepository()
        let sut = ManageRouteChunksUseCase(repository: mockRepo)

        sut.addPoint(lat: 35.0, lng: 139.0, altitude: 10.0, speed: 1.5)
        sut.addPoint(lat: 35.001, lng: 139.001, altitude: 11.0, speed: 1.6)

        // shouldFlush is false because not enough time has passed
        #expect(sut.shouldFlush == false)
    }

    @Test @MainActor func shouldFlush_rightAfterStart_returnsFalse() {
        let mockRepo = MockLocationRepository()
        let sut = ManageRouteChunksUseCase(repository: mockRepo)

        sut.addPoint(lat: 35.0, lng: 139.0, altitude: nil, speed: nil)
        #expect(sut.shouldFlush == false)
    }

    @Test @MainActor func shouldFlush_noPoints_returnsFalse() {
        let mockRepo = MockLocationRepository()
        let sut = ManageRouteChunksUseCase(repository: mockRepo)

        #expect(sut.shouldFlush == false)
    }

    @Test @MainActor func flush_callsRepository_andClearsState() async throws {
        let mockRepo = MockLocationRepository()
        let sut = ManageRouteChunksUseCase(repository: mockRepo)

        sut.addPoint(lat: 35.0, lng: 139.0, altitude: 10.0, speed: 1.5)
        sut.addPoint(lat: 35.001, lng: 139.001, altitude: 11.0, speed: 1.6)

        try await sut.flush(trackedUserId: "user-1")

        #expect(mockRepo.appendRouteChunkCallCount == 1)
        #expect(mockRepo.lastAppendedRouteChunk?.points.count == 2)

        // After flush, shouldFlush is false (state cleared)
        #expect(sut.shouldFlush == false)
    }

    @Test @MainActor func flush_withNoPoints_doesNotCallRepository() async throws {
        let mockRepo = MockLocationRepository()
        let sut = ManageRouteChunksUseCase(repository: mockRepo)

        try await sut.flush(trackedUserId: "user-1")
        #expect(mockRepo.appendRouteChunkCallCount == 0)
    }

    @Test @MainActor func reset_clearsState() {
        let mockRepo = MockLocationRepository()
        let sut = ManageRouteChunksUseCase(repository: mockRepo)

        sut.addPoint(lat: 35.0, lng: 139.0, altitude: nil, speed: nil)
        sut.reset()

        #expect(sut.shouldFlush == false)
    }
}
