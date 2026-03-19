import Foundation
@testable import WatchOverPro

// MARK: - MockLocationRepository

@MainActor
final class MockLocationRepository: LocationRepositoryProtocol {
    var putStopEventCallCount = 0
    var lastPutStopEvent: StopEvent?
    var appendRouteChunkCallCount = 0
    var lastAppendedRouteChunk: RouteChunk?

    nonisolated func updateCurrentLocation(_ location: CurrentLocation) async throws -> CurrentLocation {
        location
    }

    nonisolated func appendRouteChunk(_ chunk: RouteChunk) async throws {
        await MainActor.run {
            appendRouteChunkCallCount += 1
            lastAppendedRouteChunk = chunk
        }
    }

    nonisolated func putStopEvent(_ event: StopEvent) async throws {
        await MainActor.run {
            putStopEventCallCount += 1
            lastPutStopEvent = event
        }
    }

    nonisolated func getLiveMapState(familyId: String) async throws -> [CurrentLocation] {
        []
    }

    nonisolated func getRoute24h(trackedUserId: String, date: String) async throws -> [RouteChunk] {
        []
    }

    nonisolated func getStopEvents24h(trackedUserId: String, date: String) async throws -> [StopEvent] {
        []
    }

    nonisolated func subscribeLocationUpdates(trackedUserId: String) -> AsyncThrowingStream<CurrentLocation, Error> {
        AsyncThrowingStream { _ in }
    }
}

// MARK: - MockFamilyRepository

@MainActor
final class MockFamilyRepository: FamilyRepositoryProtocol {
    var stubbedFamily: Family?
    var stubbedMembers: [FamilyMember] = []
    var deleteFamilyMemberCallCount = 0
    var lastDeletedMemberUserId: String?

    nonisolated func getFamily(familyId: String) async throws -> Family? {
        await stubbedFamily
    }

    nonisolated func getFamilyMembers(familyId: String) async throws -> [FamilyMember] {
        await stubbedMembers
    }

    nonisolated func deleteFamilyMember(familyId: String, memberUserId: String) async throws {
        await MainActor.run {
            deleteFamilyMemberCallCount += 1
            lastDeletedMemberUserId = memberUserId
        }
    }
}

// MARK: - MockPairingRepository

@MainActor
final class MockPairingRepository: PairingRepositoryProtocol {
    var stubbedPairingCode = PairingCode(code: "ABC123", familyId: "fam-1")
    var stubbedFamilyMember = FamilyMember(
        familyId: "fam-1",
        memberUserId: "user-1",
        displayName: "テスト"
    )

    nonisolated func createPairingCode(familyId: String) async throws -> PairingCode {
        await stubbedPairingCode
    }

    nonisolated func consumePairingCode(
        code: String,
        displayName: String?,
        relationship: String?,
        age: Int?,
        colorHex: String?
    ) async throws -> FamilyMember {
        await stubbedFamilyMember
    }
}

// MARK: - MockAuthRepository

@MainActor
final class MockAuthRepository: AuthRepositoryProtocol {
    var stubbedIsAuthenticated = false
    var stubbedUserId: String? = "user-1"

    nonisolated var isAuthenticated: Bool {
        get async { await stubbedIsAuthenticated }
    }

    nonisolated var currentUserId: String? {
        get async { await stubbedUserId }
    }

    nonisolated func signInWithApple() async throws {}
    nonisolated func signOut() async throws {}
    nonisolated func checkSession() async throws -> Bool {
        await stubbedIsAuthenticated
    }
}
