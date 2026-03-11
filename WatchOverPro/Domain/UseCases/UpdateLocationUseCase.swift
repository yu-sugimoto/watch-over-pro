import Foundation

struct UpdateLocationUseCase: Sendable {
    private let repository: any LocationRepositoryProtocol

    init(repository: any LocationRepositoryProtocol) {
        self.repository = repository
    }

    @discardableResult
    func execute(
        trackedUserId: String,
        lat: Double,
        lng: Double,
        altitude: Double? = nil,
        accuracy: Double? = nil,
        speed: Double? = nil,
        heading: Double? = nil,
        batteryLevel: Double? = nil
    ) async throws -> CurrentLocation {
        let location = CurrentLocation(
            trackedUserId: trackedUserId,
            lat: lat,
            lng: lng,
            altitude: altitude,
            accuracy: accuracy,
            speed: speed,
            heading: heading,
            batteryLevel: batteryLevel
        )
        return try await repository.updateCurrentLocation(location)
    }
}
