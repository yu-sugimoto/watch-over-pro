import Foundation
import Network
import Supabase

nonisolated struct PendingSyncItem: Codable, Sendable, Identifiable {
    let id: UUID
    let gaitData: RemoteGaitData
    let personStatus: PersonStatusUpdate
    let createdAt: Date

    init(id: UUID = UUID(), gaitData: RemoteGaitData, personStatus: PersonStatusUpdate, createdAt: Date = Date()) {
        self.id = id
        self.gaitData = gaitData
        self.personStatus = personStatus
        self.createdAt = createdAt
    }
}

nonisolated struct PersonStatusUpdate: Codable, Sendable {
    let personId: UUID
    let status: String
    let steps: Int
    let anomalyCount: Int
    let riskLevel: String
    let steadiness: Double?
    let latitude: Double?
    let longitude: Double?
}

@Observable
@MainActor
final class OfflineSyncQueue {
    static let shared = OfflineSyncQueue()

    var isOnline: Bool = true
    var pendingCount: Int = 0

    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.gait.networkmonitor")
    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("offline_sync_queue.json")
    }()

    private var isFlushing = false
    private var inMemoryQueue: [PendingSyncItem] = []
    private var isLoadedFromDisk = false

    func startMonitoring() {
        stopMonitoring()
        loadFromDiskIfNeeded()
        let newMonitor = NWPathMonitor()
        newMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = path.status == .satisfied
                if wasOffline && self.isOnline {
                    await self.flushQueue()
                }
            }
        }
        newMonitor.start(queue: monitorQueue)
        monitor = newMonitor
    }

    func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
    }

    func enqueue(gaitData: RemoteGaitData, personStatus: PersonStatusUpdate) {
        loadFromDiskIfNeeded()
        let item = PendingSyncItem(gaitData: gaitData, personStatus: personStatus)
        inMemoryQueue.append(item)

        if inMemoryQueue.count > 500 {
            inMemoryQueue = Array(inMemoryQueue.suffix(500))
        }

        pendingCount = inMemoryQueue.count
        persistToDisk(inMemoryQueue)
    }

    func flushQueue() async {
        guard !isFlushing else { return }
        guard isOnline else { return }
        loadFromDiskIfNeeded()
        guard !inMemoryQueue.isEmpty else { return }

        let auth = AuthService.shared
        let authOk = await auth.reauthenticateIfNeeded()
        guard authOk else { return }

        isFlushing = true
        defer { isFlushing = false }

        let staleThreshold = Date().addingTimeInterval(-86400)
        inMemoryQueue.removeAll { $0.createdAt < staleThreshold }

        guard !inMemoryQueue.isEmpty else {
            pendingCount = 0
            persistToDisk(inMemoryQueue)
            return
        }

        let itemsToProcess = inMemoryQueue
        var processedIndices: Set<Int> = []
        var consecutiveFailures = 0
        let maxConsecutiveFailures = 3

        for (index, item) in itemsToProcess.enumerated() {
            guard !Task.isCancelled else { break }
            guard isOnline else { break }
            if consecutiveFailures >= maxConsecutiveFailures { break }
            do {
                try await GaitDataRepository.shared.upload(item.gaitData)
                let status = PersonStatus(rawValue: item.personStatus.status) ?? .safe
                try await PersonRepository.shared.updateStatus(
                    item.personStatus.personId,
                    status: status,
                    steps: item.personStatus.steps,
                    anomalyCount: item.personStatus.anomalyCount,
                    riskLevel: item.personStatus.riskLevel,
                    steadiness: item.personStatus.steadiness,
                    latitude: item.personStatus.latitude,
                    longitude: item.personStatus.longitude
                )
                processedIndices.insert(index)
                consecutiveFailures = 0
            } catch {
                consecutiveFailures += 1
                let isAuthErr = error.localizedDescription.lowercased()
                let authRelated = isAuthErr.contains("jwt") || isAuthErr.contains("401") || isAuthErr.contains("403") || isAuthErr.contains("row-level security")
                if authRelated && consecutiveFailures <= 2 {
                    await auth.ensureAuthenticated()
                    if auth.isAuthenticated {
                        consecutiveFailures = max(consecutiveFailures - 1, 0)
                    }
                }
                if consecutiveFailures < maxConsecutiveFailures {
                    try? await Task.sleep(for: .seconds(Double(consecutiveFailures)))
                }
            }
        }

        inMemoryQueue = itemsToProcess.enumerated().compactMap { index, item in
            processedIndices.contains(index) ? nil : item
        }
        if inMemoryQueue.count > 500 {
            inMemoryQueue = Array(inMemoryQueue.suffix(500))
        }
        pendingCount = inMemoryQueue.count
        persistToDisk(inMemoryQueue)
    }

    private func loadFromDiskIfNeeded() {
        guard !isLoadedFromDisk else { return }
        isLoadedFromDisk = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            inMemoryQueue = try JSONDecoder().decode([PendingSyncItem].self, from: data)
        } catch {
            inMemoryQueue = []
            try? FileManager.default.removeItem(at: fileURL)
        }
        pendingCount = inMemoryQueue.count
    }

    private nonisolated func persistToDisk(_ items: [PendingSyncItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
