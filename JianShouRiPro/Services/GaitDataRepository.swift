import Foundation
import Supabase

@MainActor
final class GaitDataRepository {
    static let shared = GaitDataRepository()

    private var auth: AuthService { AuthService.shared }
    private var client: SupabaseClient { auth.client }

    func upload(_ data: RemoteGaitData) async throws {
        var mutableData = data
        mutableData.userId = auth.currentUserId
        try await client.from("remote_gait_data").upsert(mutableData).execute()
    }

    func fetchLatest(for personId: UUID) async -> RemoteGaitData? {
        do {
            let results: [RemoteGaitData] = try await client.from("remote_gait_data")
                .select()
                .eq("person_id", value: personId.uuidString)
                .order("timestamp", ascending: false)
                .limit(1)
                .execute()
                .value
            return results.first
        } catch {
            auth.errorMessage = error.localizedDescription
            return nil
        }
    }

    func fetchLastActive(for personId: UUID) async -> RemoteGaitData? {
        do {
            let results: [RemoteGaitData] = try await client.from("remote_gait_data")
                .select()
                .eq("person_id", value: personId.uuidString)
                .eq("is_walking", value: true)
                .order("timestamp", ascending: false)
                .limit(1)
                .execute()
                .value
            return results.first
        } catch {
            auth.errorMessage = error.localizedDescription
            return nil
        }
    }

    func fetchHistory(for personId: UUID, limit: Int = 100) async -> [RemoteGaitData] {
        do {
            let results: [RemoteGaitData] = try await client.from("remote_gait_data")
                .select()
                .eq("person_id", value: personId.uuidString)
                .order("timestamp", ascending: false)
                .limit(limit)
                .execute()
                .value
            return results
        } catch {
            auth.errorMessage = error.localizedDescription
            return []
        }
    }

    func saveSession(_ session: GaitSession, personId: UUID) async {
        let sessionData: [String: AnyJSON] = [
            "id": .string(session.id.uuidString),
            "person_id": .string(personId.uuidString),
            "start_date": .string(ISO8601.string(from: session.startDate)),
            "end_date": .string(ISO8601.string(from: session.endDate ?? Date())),
            "average_cadence": .double(session.averageCadence),
            "average_pace": .double(session.averagePace),
            "risk_level": .string(session.riskLevel.rawValue),
            "step_count": .integer(session.stepCount),
            "anomaly_count": .integer(session.anomalies.count)
        ]
        do {
            try await client.from("gait_sessions").upsert(sessionData).execute()
        } catch {
            auth.errorMessage = error.localizedDescription
        }
    }
}
