import Foundation
import UIKit

@Observable
@MainActor
final class RemoteSyncService {
    var isSyncing = false
    var lastSyncTime: Date?
    var syncError: String?
    var isUrgentMode = false
    private(set) var consecutiveFailureCount: Int = 0

    private let auth = AuthService.shared
    private let gaitDataRepo = GaitDataRepository.shared
    private let personRepo = PersonRepository.shared
    private let locationService = LocationService()

    var currentLatitude: Double? { locationService.currentLatitude }
    var currentLongitude: Double? { locationService.currentLongitude }

    private var syncPersonId: UUID?
    private var syncDeviceId: String?
    private weak var syncGaitViewModel: GaitViewModel?

    private var lastSyncDate: Date {
        get {
            let ti = UserDefaults.standard.double(forKey: "last_sync_date")
            return ti > 0 ? Date(timeIntervalSince1970: ti) : .distantPast
        }
        set {
            UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: "last_sync_date")
        }
    }

    private let normalSyncInterval: TimeInterval = 30
    private let urgentSyncInterval: TimeInterval = 10
    private var previousRiskLevel: GaitRiskLevel = .normal
    private var previousIsWalking = false
    private var syncTimer: Timer?
    private var flushTimer: Timer?
    private var foregroundObserver: (any NSObjectProtocol)?
    private var terminateObserver: (any NSObjectProtocol)?
    private var backgroundObserver: (any NSObjectProtocol)?
    private var hasRegisteredWatchedUserId = false

    static func registerBackgroundTasks() {
        BackgroundTaskService.registerAll()
    }

    func startAutoSync(personId: UUID, deviceId: String, gaitViewModel: GaitViewModel) {
        guard !isSyncing else { return }
        isSyncing = true
        syncPersonId = personId
        syncDeviceId = deviceId
        syncGaitViewModel = gaitViewModel
        consecutiveFailureCount = 0
        hasRegisteredWatchedUserId = false
        locationService.start()

        Task {
            await performSync()
        }

        registerForAppLifecycleNotifications()
        startSyncTimer()
        startFlushTimer()
    }

    func stopAutoSync() {
        isSyncing = false
        isUrgentMode = false
        previousRiskLevel = .normal
        previousIsWalking = false
        consecutiveFailureCount = 0
        hasRegisteredWatchedUserId = false
        syncTimer?.invalidate()
        syncTimer = nil
        flushTimer?.invalidate()
        flushTimer = nil
        locationService.stop()
        syncPersonId = nil
        syncDeviceId = nil
        syncGaitViewModel = nil
        syncError = nil
        removeLifecycleObservers()
    }

    func triggerImmediateSync() {
        guard isSyncing else { return }
        Task { @MainActor in
            await performSync()
        }
    }

    func onStateChanged(newRiskLevel: GaitRiskLevel, isWalking: Bool) {
        guard isSyncing else { return }

        let riskChanged = newRiskLevel != previousRiskLevel
        let walkingChanged = isWalking != previousIsWalking
        let wasUrgent = isUrgentMode

        if newRiskLevel == .high || newRiskLevel == .elevated {
            isUrgentMode = true
        } else if previousRiskLevel != .normal && newRiskLevel == .normal {
            isUrgentMode = false
        }

        previousRiskLevel = newRiskLevel
        previousIsWalking = isWalking

        if isUrgentMode != wasUrgent {
            startSyncTimer()
        }

        if riskChanged || walkingChanged {
            triggerImmediateSync()
        }
    }

    func retryNow() {
        guard isSyncing else { return }
        consecutiveFailureCount = 0
        syncError = nil
        Task { @MainActor in
            await auth.ensureAuthenticated()
            let queue = OfflineSyncQueue.shared
            if queue.pendingCount > 0 {
                await queue.flushQueue()
            }
            await performSync()
        }
    }

    func performSync() async {
        guard let personId = syncPersonId,
              let deviceId = syncDeviceId,
              let gaitViewModel = syncGaitViewModel else { return }
        await syncData(personId: personId, deviceId: deviceId, gaitViewModel: gaitViewModel)
    }

    private func syncData(personId: UUID, deviceId: String, gaitViewModel: GaitViewModel) async {
        guard isSyncing else { return }

        let authOk = await auth.reauthenticateIfNeeded()
        guard authOk else {
            syncError = "認証エラー — 再試行中"
            consecutiveFailureCount += 1
            if consecutiveFailureCount <= 3 {
                try? await Task.sleep(for: .seconds(2))
                await auth.ensureAuthenticated()
                if auth.isAuthenticated {
                    consecutiveFailureCount = 0
                    syncError = nil
                }
            }
            return
        }

        let isWalking = gaitViewModel.motionService.isWalking
        let steps = gaitViewModel.todaySteps
        let cadence = gaitViewModel.motionService.currentCadence
        let pace = gaitViewModel.motionService.currentPace
        let riskLevel = gaitViewModel.currentRiskLevel.rawValue
        let anomalyCount = gaitViewModel.todayAnomalyCount
        let steadiness = gaitViewModel.healthService.metrics.walkingSteadiness

        let acc = gaitViewModel.motionService.latestAcceleration
        let accMag = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)

        let data = RemoteGaitData(
            personId: personId,
            deviceId: deviceId,
            steps: steps,
            cadence: cadence,
            pace: pace,
            riskLevel: riskLevel,
            anomalyCount: anomalyCount,
            walkingSteadiness: steadiness,
            isWalking: isWalking,
            accelerationMagnitude: accMag,
            latitude: currentLatitude,
            longitude: currentLongitude
        )

        let status = StatusResolver.fromRiskLevel(gaitViewModel.currentRiskLevel)

        let offlineQueue = OfflineSyncQueue.shared

        let statusUpdate = PersonStatusUpdate(
            personId: personId,
            status: status.rawValue,
            steps: steps,
            anomalyCount: anomalyCount,
            riskLevel: riskLevel,
            steadiness: steadiness,
            latitude: currentLatitude,
            longitude: currentLongitude
        )

        lastSyncDate = Date()

        var lastError: Error?
        for attempt in 1...3 {
            guard offlineQueue.isOnline else { break }
            do {
                try await gaitDataRepo.upload(data)
                try await personRepo.updateStatus(
                    personId,
                    status: status,
                    steps: steps,
                    anomalyCount: anomalyCount,
                    riskLevel: riskLevel,
                    steadiness: steadiness,
                    latitude: currentLatitude,
                    longitude: currentLongitude
                )
                lastSyncTime = Date()
                syncError = nil
                consecutiveFailureCount = 0

                if offlineQueue.pendingCount > 0 {
                    await offlineQueue.flushQueue()
                }
                return
            } catch {
                lastError = error
                if isAuthenticationError(error) && attempt <= 2 {
                    await auth.ensureAuthenticated()
                    if auth.isAuthenticated {
                        continue
                    }
                }
                if attempt < 3 {
                    try? await Task.sleep(for: .seconds(Double(attempt)))
                }
            }
        }

        consecutiveFailureCount += 1
        offlineQueue.enqueue(gaitData: data, personStatus: statusUpdate)
        if !offlineQueue.isOnline {
            syncError = "オフライン — データをローカルに保存中"
        } else {
            let errorDetail = lastError?.localizedDescription ?? "不明なエラー"
            syncError = "送信失敗（\(offlineQueue.pendingCount)件キュー）: \(errorDetail)"
        }
    }

    private func isAuthenticationError(_ error: Error) -> Bool {
        let desc = error.localizedDescription.lowercased()
        return desc.contains("jwt") || desc.contains("token") || desc.contains("401") || desc.contains("403") || desc.contains("auth") || desc.contains("permission") || desc.contains("row-level security")
    }

    private var currentSyncInterval: TimeInterval {
        isUrgentMode ? urgentSyncInterval : normalSyncInterval
    }

    private func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: currentSyncInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.syncIfNeeded()
            }
        }
    }

    private func startFlushTimer() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                let queue = OfflineSyncQueue.shared
                guard queue.isOnline, queue.pendingCount > 0 else { return }
                await queue.flushQueue()
            }
        }
    }

    private func syncIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastSyncDate) >= currentSyncInterval else { return }
        guard isSyncing else { return }
        Task { @MainActor in
            await performSync()
        }
    }

    private func registerForAppLifecycleNotifications() {
        removeLifecycleObservers()
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.auth.ensureAuthenticated()
                self.syncIfNeeded()
            }
        }

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.performSync()
                BackgroundTaskService.scheduleRefresh()
                BackgroundTaskService.scheduleProcessing()
            }
        }

        terminateObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.performTerminationSync()
            }
        }
    }

    private func performTerminationSync() async {
        guard let personId = syncPersonId,
              let deviceId = syncDeviceId else { return }

        let data = RemoteGaitData(
            personId: personId,
            deviceId: deviceId,
            steps: 0,
            riskLevel: "normal",
            isWalking: false,
            latitude: currentLatitude,
            longitude: currentLongitude
        )

        let statusUpdate = PersonStatusUpdate(
            personId: personId,
            status: PersonStatus.offline.rawValue,
            steps: 0,
            anomalyCount: 0,
            riskLevel: "normal",
            steadiness: nil,
            latitude: currentLatitude,
            longitude: currentLongitude
        )

        let offlineQueue = OfflineSyncQueue.shared
        guard offlineQueue.isOnline else {
            offlineQueue.enqueue(gaitData: data, personStatus: statusUpdate)
            return
        }

        do {
            try await personRepo.updateStatus(
                personId,
                status: .offline,
                steps: 0,
                anomalyCount: 0,
                riskLevel: "normal",
                steadiness: nil,
                latitude: currentLatitude,
                longitude: currentLongitude
            )
        } catch {
            offlineQueue.enqueue(gaitData: data, personStatus: statusUpdate)
        }
    }

    private func removeLifecycleObservers() {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
        if let observer = terminateObserver {
            NotificationCenter.default.removeObserver(observer)
            terminateObserver = nil
        }
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
    }
}
