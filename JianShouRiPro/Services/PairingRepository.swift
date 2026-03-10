import Foundation
import UIKit
import Supabase

@MainActor
final class PairingRepository {
    static let shared = PairingRepository()

    private var auth: AuthService { AuthService.shared }
    private var client: SupabaseClient { auth.client }

    func generateCode(for personId: UUID, deviceId: String? = nil) async throws -> String {
        await invalidateAllCodes(for: personId)
        let code = String(format: "%06d", Int.random(in: 0...999999))
        let now = Date()
        let expires = Calendar.current.date(byAdding: .hour, value: 24, to: now) ?? now.addingTimeInterval(86400)
        let resolvedDeviceId = deviceId ?? UIDevice.current.identifierForVendor?.uuidString ?? ""
        let data: [String: AnyJSON] = [
            "id": .string(UUID().uuidString),
            "code": .string(code),
            "person_id": .string(personId.uuidString),
            "watcher_device_id": .string(resolvedDeviceId),
            "is_used": .bool(false),
            "created_at": .string(ISO8601.string(from: now)),
            "expires_at": .string(ISO8601.string(from: expires))
        ]
        try await client.from("pairing_codes").insert(data).execute()
        return code
    }

    func validate(_ code: String) async -> PairingCode? {
        do {
            let now = ISO8601.string(from: Date())
            let results: [PairingCode] = try await client.from("pairing_codes")
                .select()
                .eq("code", value: code)
                .eq("is_used", value: false)
                .gte("expires_at", value: now)
                .limit(1)
                .execute()
                .value
            return results.first
        } catch {
            auth.errorMessage = error.localizedDescription
            return nil
        }
    }

    func markUsed(_ codeId: UUID) async {
        do {
            try await client.from("pairing_codes")
                .update(["is_used": AnyJSON.bool(true)])
                .eq("id", value: codeId.uuidString)
                .execute()
        } catch {
            auth.errorMessage = error.localizedDescription
        }
    }

    func invalidateAllCodes(for personId: UUID) async {
        do {
            try await client.from("pairing_codes")
                .update(["is_used": AnyJSON.bool(true)])
                .eq("person_id", value: personId.uuidString)
                .eq("is_used", value: false)
                .execute()
        } catch {
            auth.errorMessage = error.localizedDescription
        }
    }

    func fetchActiveCode(for personId: UUID) async -> PairingCode? {
        do {
            let now = ISO8601.string(from: Date())
            let results: [PairingCode] = try await client.from("pairing_codes")
                .select()
                .eq("person_id", value: personId.uuidString)
                .eq("is_used", value: false)
                .gte("expires_at", value: now)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            return results.first
        } catch {
            auth.errorMessage = error.localizedDescription
            return nil
        }
    }

    func createDeviceLink(_ link: DeviceLink) async {
        do {
            let existing: [DeviceLink] = try await client.from("device_links")
                .select()
                .eq("person_id", value: link.personId.uuidString)
                .eq("watcher_device_id", value: link.watcherDeviceId)
                .limit(1)
                .execute()
                .value
            if !existing.isEmpty { return }
            try await client.from("device_links").insert(link).execute()
        } catch {
            auth.errorMessage = error.localizedDescription
        }
    }

    func createWatcherLink(personId: UUID, watcherDeviceId: String, watchedDeviceId: String = "") async {
        let link = DeviceLink(
            personId: personId,
            watchedDeviceId: watchedDeviceId,
            watcherDeviceId: watcherDeviceId
        )
        await createDeviceLink(link)
    }

    func fetchConnectedWatcherCount(for personId: UUID) async -> Int {
        do {
            let links: [DeviceLink] = try await client.from("device_links")
                .select()
                .eq("person_id", value: personId.uuidString)
                .execute()
                .value
            return links.count
        } catch {
            auth.errorMessage = error.localizedDescription
            return 0
        }
    }

    func deleteDeviceLink(personId: UUID, watchedDeviceId: String) async {
        do {
            try await client.from("device_links")
                .delete()
                .eq("person_id", value: personId.uuidString)
                .eq("watched_device_id", value: watchedDeviceId)
                .execute()
        } catch {
            auth.errorMessage = error.localizedDescription
        }
    }

    func deleteDeviceLinkForWatcher(personId: UUID, watcherDeviceId: String) async {
        do {
            try await client.from("device_links")
                .delete()
                .eq("person_id", value: personId.uuidString)
                .eq("watcher_device_id", value: watcherDeviceId)
                .execute()
        } catch {
            auth.errorMessage = error.localizedDescription
        }
    }
}
