import Foundation

protocol LocationRepositoryProtocol: Sendable {
    func updateCurrentLocation(_ location: CurrentLocation) async throws -> CurrentLocation
    func appendRouteChunk(_ chunk: RouteChunk) async throws
    func putStopEvent(_ event: StopEvent) async throws
    func getLiveMapState(familyId: String) async throws -> [CurrentLocation]
    func getRoute24h(trackedUserId: String, date: String) async throws -> [RouteChunk]
    func getStopEvents24h(trackedUserId: String, date: String) async throws -> [StopEvent]
    func subscribeLocationUpdates(trackedUserId: String) -> AsyncThrowingStream<CurrentLocation, Error>
}
