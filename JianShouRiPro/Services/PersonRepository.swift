import Foundation
import Supabase

@MainActor
final class PersonRepository {
    static let shared = PersonRepository()

    private var auth: AuthService { AuthService.shared }
    private var client: SupabaseClient { auth.client }

    func save(_ person: WatchPerson) async {
        do {
            try await client.from("watch_persons").upsert(person).execute()
        } catch {
            auth.errorMessage = error.localizedDescription
            saveToPersistence(person)
        }
    }

    func fetchAll(forWatcherDeviceId deviceId: String) async -> [WatchPerson] {
        do {
            let links: [DeviceLink] = try await client.from("device_links")
                .select()
                .eq("watcher_device_id", value: deviceId)
                .execute()
                .value

            guard !links.isEmpty else { return [] }

            let personIds = links.map { $0.personId.uuidString }
            let persons: [WatchPerson] = try await client.from("watch_persons")
                .select()
                .in("id", values: personIds)
                .order("created_at", ascending: false)
                .execute()
                .value
            return persons
        } catch {
            auth.errorMessage = error.localizedDescription
            return loadFromPersistence()
        }
    }

    func fetchById(_ personId: UUID) async -> WatchPerson? {
        do {
            let results: [WatchPerson] = try await client.from("watch_persons")
                .select()
                .eq("id", value: personId.uuidString)
                .limit(1)
                .execute()
                .value
            return results.first
        } catch {
            auth.errorMessage = error.localizedDescription
            return nil
        }
    }

    func exists(_ personId: UUID) async -> Bool {
        do {
            let results: [WatchPerson] = try await client.from("watch_persons")
                .select()
                .eq("id", value: personId.uuidString)
                .limit(1)
                .execute()
                .value
            return !results.isEmpty
        } catch {
            return false
        }
    }

    func delete(id: UUID) async {
        do {
            try await client.from("watch_persons")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
        } catch {
            auth.errorMessage = error.localizedDescription
        }
    }

    func updateInfo(_ personId: UUID, name: String, relationship: Relationship, age: Int, colorHex: String, notes: String) async {
        do {
            let updateData: [String: AnyJSON] = [
                "name": .string(name),
                "relationship": .string(relationship.rawValue),
                "age": .integer(age),
                "color_hex": .string(colorHex),
                "notes": .string(notes)
            ]
            try await client.from("watch_persons")
                .update(updateData)
                .eq("id", value: personId.uuidString)
                .execute()
        } catch {
            auth.errorMessage = error.localizedDescription
        }
    }

    func updateStatus(_ personId: UUID, status: PersonStatus, steps: Int, anomalyCount: Int, riskLevel: String, steadiness: Double?, latitude: Double? = nil, longitude: Double? = nil) async throws {
        var updateData: [String: AnyJSON] = [
            "status": .string(status.rawValue),
            "today_steps": .integer(steps),
            "today_anomaly_count": .integer(anomalyCount),
            "last_risk_level": .string(riskLevel),
            "last_activity": .string(ISO8601.string(from: Date()))
        ]
        if let steadiness {
            updateData["walking_steadiness"] = .double(steadiness)
        }
        if let latitude {
            updateData["latitude"] = .double(latitude)
        }
        if let longitude {
            updateData["longitude"] = .double(longitude)
        }
        try await client.from("watch_persons")
            .update(updateData)
            .eq("id", value: personId.uuidString)
            .execute()
    }

    func setOffline(_ personId: UUID) async {
        do {
            let updateData: [String: AnyJSON] = [
                "status": .string(PersonStatus.offline.rawValue)
            ]
            try await client.from("watch_persons")
                .update(updateData)
                .eq("id", value: personId.uuidString)
                .execute()
        } catch {
            auth.errorMessage = error.localizedDescription
        }
    }

    private func saveToPersistence(_ person: WatchPerson) {
        var persons = loadFromPersistence()
        if let index = persons.firstIndex(where: { $0.id == person.id }) {
            persons[index] = person
        } else {
            persons.append(person)
        }
        if let data = try? JSONEncoder().encode(persons) {
            let url = documentsURL(for: "watch_persons_cache.json")
            try? data.write(to: url, options: .atomic)
        }
    }

    private func loadFromPersistence() -> [WatchPerson] {
        let url = documentsURL(for: "watch_persons_cache.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([WatchPerson].self, from: data)) ?? []
    }

    private nonisolated func documentsURL(for filename: String) -> URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        }
        return docs.appendingPathComponent(filename)
    }
}
