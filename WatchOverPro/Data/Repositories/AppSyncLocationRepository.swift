import Foundation

final class AppSyncLocationRepository: LocationRepositoryProtocol, Sendable {
    private let dataSource = AppSyncDataSource.shared

    func updateCurrentLocation(_ location: CurrentLocation) async throws -> CurrentLocation {
        let variables: [String: Any] = [
            "input": [
                "tracked_user_id": location.trackedUserId,
                "lat": location.lat,
                "lng": location.lng,
                "altitude": location.altitude as Any,
                "accuracy": location.accuracy as Any,
                "speed": location.speed as Any,
                "heading": location.heading as Any,
                "battery_level": location.batteryLevel as Any,
                "is_active": location.isActive,
            ]
        ]
        let result: GQLCurrentLocation = try await dataSource.mutate(
            Queries.updateCurrentLocation,
            variables: variables
        )
        return result.toEntity()
    }

    func appendRouteChunk(_ chunk: RouteChunk) async throws {
        let pointsData = chunk.points.map { point -> [String: Any] in
            var dict: [String: Any] = [
                "lat": point.lat,
                "lng": point.lng,
                "timestamp": ISO8601.string(from: point.timestamp),
            ]
            if let alt = point.altitude { dict["altitude"] = alt }
            if let spd = point.speed { dict["speed"] = spd }
            return dict
        }

        let variables: [String: Any] = [
            "input": [
                "tracked_user_id_date": chunk.trackedUserIdDate,
                "chunk_start_epoch_ms": chunk.chunkStartEpochMs,
                "points": pointsData,
            ]
        ]
        let _: GQLRouteChunk = try await dataSource.mutate(
            Queries.appendRouteChunk,
            variables: variables
        )
    }

    func putStopEvent(_ event: StopEvent) async throws {
        var input: [String: Any] = [
            "tracked_user_id_date": event.trackedUserIdDate,
            "stop_start_epoch_ms": event.stopStartEpochMs,
            "lat": event.lat,
            "lng": event.lng,
            "started_at": ISO8601.string(from: event.startedAt),
            "duration_seconds": event.durationSeconds,
        ]
        if let endedAt = event.endedAt {
            input["ended_at"] = ISO8601.string(from: endedAt)
        }
        let _: GQLStopEvent = try await dataSource.mutate(
            Queries.putStopEvent,
            variables: ["input": input]
        )
    }

    func getLiveMapState(familyId: String) async throws -> [CurrentLocation] {
        let result: GQLLiveMapState = try await dataSource.query(
            Queries.getLiveMapState,
            variables: ["family_id": familyId]
        )
        return result.locations.map { $0.toEntity() }
    }

    func getRoute24h(trackedUserId: String, date: String) async throws -> [RouteChunk] {
        let result: [GQLRouteChunk] = try await dataSource.query(
            Queries.getRoute24h,
            variables: ["tracked_user_id": trackedUserId, "date": date]
        )
        return result.map { $0.toEntity() }
    }

    func getStopEvents24h(trackedUserId: String, date: String) async throws -> [StopEvent] {
        let result: [GQLStopEvent] = try await dataSource.query(
            Queries.getStopEvents24h,
            variables: ["tracked_user_id": trackedUserId, "date": date]
        )
        return result.map { $0.toEntity() }
    }

    func subscribeLocationUpdates(trackedUserId: String) -> AsyncThrowingStream<CurrentLocation, Error> {
        let stream: AsyncThrowingStream<GQLCurrentLocation, Error> = dataSource.subscribe(
            Queries.onLocationUpdate,
            variables: ["tracked_user_id": trackedUserId]
        )
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await gql in stream {
                        continuation.yield(gql.toEntity())
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - GraphQL Query Strings
private enum Queries {
    static let updateCurrentLocation = """
    mutation UpdateCurrentLocation($input: UpdateCurrentLocationInput!) {
        updateCurrentLocation(input: $input) {
            tracked_user_id lat lng altitude accuracy speed heading battery_level is_active updated_at
        }
    }
    """

    static let appendRouteChunk = """
    mutation AppendRouteChunk($input: AppendRouteChunkInput!) {
        appendRouteChunk(input: $input) {
            tracked_user_id_date chunk_start_epoch_ms points { lat lng altitude speed timestamp } created_at
        }
    }
    """

    static let putStopEvent = """
    mutation PutStopEvent($input: PutStopEventInput!) {
        putStopEvent(input: $input) {
            tracked_user_id_date stop_start_epoch_ms lat lng started_at ended_at duration_seconds
        }
    }
    """

    static let getLiveMapState = """
    query GetLiveMapState($family_id: ID!) {
        getLiveMapState(family_id: $family_id) {
            locations { tracked_user_id lat lng altitude accuracy speed heading battery_level is_active updated_at }
            members { family_id member_user_id display_name relationship age color_hex role joined_at }
        }
    }
    """

    static let getRoute24h = """
    query GetRoute24h($tracked_user_id: ID!, $date: String!) {
        getRoute24h(tracked_user_id: $tracked_user_id, date: $date) {
            tracked_user_id_date chunk_start_epoch_ms points { lat lng altitude speed timestamp } created_at
        }
    }
    """

    static let getStopEvents24h = """
    query GetStopEvents24h($tracked_user_id: ID!, $date: String!) {
        getStopEvents24h(tracked_user_id: $tracked_user_id, date: $date) {
            tracked_user_id_date stop_start_epoch_ms lat lng started_at ended_at duration_seconds
        }
    }
    """

    static let onLocationUpdate = """
    subscription OnLocationUpdate($tracked_user_id: ID!) {
        onLocationUpdate(tracked_user_id: $tracked_user_id) {
            tracked_user_id lat lng altitude accuracy speed heading battery_level is_active updated_at
        }
    }
    """
}
