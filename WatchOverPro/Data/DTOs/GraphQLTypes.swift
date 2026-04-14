import Foundation

// MARK: - GraphQL Response DTOs

struct GQLCurrentLocation: Decodable {
    let tracked_user_id: String
    let lat: Double
    let lng: Double
    let altitude: Double?
    let accuracy: Double?
    let speed: Double?
    let heading: Double?
    let battery_level: Double?
    let is_active: Bool
    let updated_at: String

    func toEntity() -> CurrentLocation {
        CurrentLocation(
            trackedUserId: tracked_user_id,
            lat: lat,
            lng: lng,
            altitude: altitude,
            accuracy: accuracy,
            speed: speed,
            heading: heading,
            batteryLevel: battery_level,
            isActive: is_active,
            updatedAt: ISO8601.date(from: updated_at) ?? Date()
        )
    }
}

struct GQLRouteChunk: Decodable {
    let tracked_user_id_date: String
    let chunk_start_epoch_ms: Double
    let points: [GQLRoutePoint]
    let created_at: String

    func toEntity() -> RouteChunk {
        RouteChunk(
            trackedUserIdDate: tracked_user_id_date,
            chunkStartEpochMs: chunk_start_epoch_ms,
            points: points.map { $0.toEntity() },
            createdAt: ISO8601.date(from: created_at) ?? Date()
        )
    }
}

struct GQLRoutePoint: Decodable {
    let lat: Double
    let lng: Double
    let altitude: Double?
    let speed: Double?
    let timestamp: String

    func toEntity() -> RoutePoint {
        RoutePoint(
            lat: lat,
            lng: lng,
            altitude: altitude,
            speed: speed,
            timestamp: ISO8601.date(from: timestamp) ?? Date()
        )
    }
}

struct GQLStopEvent: Decodable {
    let tracked_user_id_date: String
    let stop_start_epoch_ms: Double
    let lat: Double
    let lng: Double
    let started_at: String
    let ended_at: String?
    let duration_seconds: Int

    func toEntity() -> StopEvent {
        StopEvent(
            trackedUserIdDate: tracked_user_id_date,
            stopStartEpochMs: stop_start_epoch_ms,
            lat: lat,
            lng: lng,
            startedAt: ISO8601.date(from: started_at) ?? Date(),
            endedAt: ended_at.flatMap { ISO8601.date(from: $0) },
            durationSeconds: duration_seconds
        )
    }
}

struct GQLFamilyMember: Decodable {
    let family_id: String
    let member_user_id: String
    let display_name: String
    let relationship: String
    let age: Int
    let color_hex: String
    let role: String
    let joined_at: String
    let notes: String?

    func toEntity() -> FamilyMember {
        FamilyMember(
            familyId: family_id,
            memberUserId: member_user_id,
            displayName: display_name,
            relationship: Relationship(rawValue: relationship) ?? .other,
            age: age,
            colorHex: color_hex,
            role: MemberRole(rawValue: role) ?? .watcher,
            joinedAt: ISO8601.date(from: joined_at) ?? Date(),
            notes: notes ?? ""
        )
    }
}

struct GQLPairingCode: Decodable {
    let code: String
    let family_id: String
    let created_by: String
    let expires_at: String
    let is_used: Bool

    func toEntity() -> PairingCode {
        PairingCode(
            code: code,
            familyId: family_id,
            expiresAt: ISO8601.date(from: expires_at) ?? Date(),
            isUsed: is_used
        )
    }
}

struct GQLLiveMapState: Decodable {
    let locations: [GQLCurrentLocation]
}
