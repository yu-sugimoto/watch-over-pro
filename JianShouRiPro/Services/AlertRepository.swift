import Foundation
import Supabase

@MainActor
final class AlertRepository {
    static let shared = AlertRepository()

    private var auth: AuthService { AuthService.shared }
    private var client: SupabaseClient { auth.client }

    func save(_ event: AlertEvent) async {
        do {
            try await client.from("alert_events").insert(event).execute()
        } catch {
            auth.errorMessage = error.localizedDescription
        }
    }

    func fetch(for personId: UUID? = nil, limit: Int = 50) async -> [AlertEvent] {
        do {
            if let personId {
                let response: [AlertEvent] = try await client.from("alert_events")
                    .select()
                    .eq("person_id", value: personId.uuidString)
                    .order("created_at", ascending: false)
                    .limit(limit)
                    .execute()
                    .value
                return response
            } else {
                let response: [AlertEvent] = try await client.from("alert_events")
                    .select()
                    .order("created_at", ascending: false)
                    .limit(limit)
                    .execute()
                    .value
                return response
            }
        } catch {
            auth.errorMessage = error.localizedDescription
            return []
        }
    }

    func markAsRead(_ alertId: UUID) async {
        do {
            try await client.from("alert_events")
                .update(["is_read": AnyJSON.bool(true)])
                .eq("id", value: alertId.uuidString)
                .execute()
        } catch {
            auth.errorMessage = error.localizedDescription
        }
    }
}
