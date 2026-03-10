import Foundation
import Supabase

@Observable
@MainActor
final class RealtimeManager {
    var isConnected = false

    private let auth = AuthService.shared
    private var realtimeTask: Task<Void, Never>?
    private var channel: RealtimeChannelV2?

    struct Handlers {
        var onPersonInserted: (WatchPerson) -> Void = { _ in }
        var onPersonUpdated: (WatchPerson) -> Void = { _ in }
        var onPersonDeleted: (UUID) -> Void = { _ in }
        var onAlertInserted: (AlertEvent) -> Void = { _ in }
        var onRemoteDataInserted: () async -> Void = {}
    }

    var handlers = Handlers()

    func start(linkedPersonIds: Set<UUID>) async {
        await stop()

        let authOk = await auth.reauthenticateIfNeeded()
        guard authOk else { return }

        let ch = auth.client.realtimeV2.channel("watch-over-changes")
        self.channel = ch

        let personInserts = ch.postgresChange(InsertAction.self, schema: "public", table: "watch_persons")
        let personUpdates = ch.postgresChange(UpdateAction.self, schema: "public", table: "watch_persons")
        let personDeletes = ch.postgresChange(DeleteAction.self, schema: "public", table: "watch_persons")
        let alertInserts = ch.postgresChange(InsertAction.self, schema: "public", table: "alert_events")
        let remoteDataInserts = ch.postgresChange(InsertAction.self, schema: "public", table: "remote_gait_data")

        await ch.subscribe()
        isConnected = true

        let ids = linkedPersonIds

        realtimeTask = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor [weak self] in
                    for await insert in personInserts {
                        guard let self, !Task.isCancelled else { return }
                        if let person = try? insert.decodeRecord(as: WatchPerson.self, decoder: ISO8601.realtimeDecoder) {
                            guard ids.contains(person.id) else { continue }
                            self.handlers.onPersonInserted(person)
                        }
                    }
                }
                group.addTask { @MainActor [weak self] in
                    for await update in personUpdates {
                        guard let self, !Task.isCancelled else { return }
                        if let updated = try? update.decodeRecord(as: WatchPerson.self, decoder: ISO8601.realtimeDecoder) {
                            guard ids.contains(updated.id) else { continue }
                            self.handlers.onPersonUpdated(updated)
                        }
                    }
                }
                group.addTask { @MainActor [weak self] in
                    for await delete in personDeletes {
                        guard let self, !Task.isCancelled else { return }
                        let oldRecord = delete.oldRecord
                        if let idJSON = oldRecord["id"],
                           case .string(let idString) = idJSON,
                           let id = UUID(uuidString: idString) {
                            guard ids.contains(id) else { continue }
                            self.handlers.onPersonDeleted(id)
                        }
                    }
                }
                group.addTask { @MainActor [weak self] in
                    for await insert in alertInserts {
                        guard let self, !Task.isCancelled else { return }
                        if let alert = try? insert.decodeRecord(as: AlertEvent.self, decoder: ISO8601.realtimeDecoder) {
                            guard ids.contains(alert.personId) else { continue }
                            self.handlers.onAlertInserted(alert)
                        }
                    }
                }
                group.addTask { @MainActor [weak self] in
                    for await _ in remoteDataInserts {
                        guard let self, !Task.isCancelled else { return }
                        await self.handlers.onRemoteDataInserted()
                    }
                }
            }
        }
    }

    func stop() async {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let ch = channel {
            await auth.removeChannel(ch)
            channel = nil
        }
        isConnected = false
    }
}
