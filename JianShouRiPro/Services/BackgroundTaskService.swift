import Foundation
import BackgroundTasks
import CoreMotion
import CoreLocation

@MainActor
enum BackgroundTaskService {
    static let refreshIdentifier = "app.rork.ios-gait-anomaly-detector.sync"
    static let processingIdentifier = "app.rork.ios-gait-anomaly-detector.processing"

    static func registerAll() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: true)
                return
            }
            handleRefresh(refreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: processingIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: true)
                return
            }
            handleProcessing(processingTask)
        }
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {}
    }

    static func scheduleProcessing() {
        let request = BGProcessingTaskRequest(identifier: processingIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {}
    }

    private static func loadWatchedConfig() -> (personId: UUID, deviceId: String)? {
        let defaults = UserDefaults.standard
        guard let modeRaw = defaults.string(forKey: "app_mode"),
              modeRaw == "watched",
              let personIdStr = defaults.string(forKey: "linked_person_id"),
              let personId = UUID(uuidString: personIdStr),
              let deviceId = defaults.string(forKey: "device_id") else {
            return nil
        }
        return (personId, deviceId)
    }

    private static func fetchPedometerSteps() async -> (steps: Int, cadence: Double) {
        guard CMPedometer.isStepCountingAvailable() else { return (0, 0) }
        let pedometer = CMPedometer()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let pedData = await withCheckedContinuation { (cont: CheckedContinuation<CMPedometerData?, Never>) in
            pedometer.queryPedometerData(from: startOfDay, to: Date()) { data, _ in
                cont.resume(returning: data)
            }
        }
        let steps = pedData?.numberOfSteps.intValue ?? 0
        let cadence = (pedData?.currentCadence?.doubleValue ?? 0) * 60.0
        return (steps, cadence)
    }

    private static func currentLocation() -> (lat: Double?, lon: Double?) {
        let manager = CLLocationManager()
        return (manager.location?.coordinate.latitude, manager.location?.coordinate.longitude)
    }

    private static func handleRefresh(_ task: BGAppRefreshTask) {
        let bgTask = Task { @MainActor in
            guard let config = loadWatchedConfig() else {
                task.setTaskCompleted(success: true)
                scheduleRefresh()
                return
            }

            guard !Task.isCancelled else {
                task.setTaskCompleted(success: false)
                return
            }

            let auth = AuthService.shared
            await auth.ensureAuthenticated()
            guard auth.isAuthenticated else {
                task.setTaskCompleted(success: false)
                scheduleRefresh()
                return
            }

            let ped = await fetchPedometerSteps()
            let loc = currentLocation()

            let data = RemoteGaitData(
                personId: config.personId,
                deviceId: config.deviceId,
                steps: ped.steps,
                cadence: ped.cadence,
                riskLevel: "normal",
                isWalking: ped.cadence > 0,
                latitude: loc.lat,
                longitude: loc.lon
            )

            let gaitRepo = GaitDataRepository.shared
            let personRepo = PersonRepository.shared

            do {
                try await gaitRepo.upload(data)
                try await personRepo.updateStatus(
                    config.personId,
                    status: .safe,
                    steps: ped.steps,
                    anomalyCount: 0,
                    riskLevel: "normal",
                    steadiness: nil,
                    latitude: loc.lat,
                    longitude: loc.lon
                )
            } catch {}

            await OfflineSyncQueue.shared.flushQueue()

            task.setTaskCompleted(success: true)
            scheduleRefresh()
        }

        task.expirationHandler = {
            bgTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private static func handleProcessing(_ task: BGProcessingTask) {
        let bgTask = Task { @MainActor in
            guard let config = loadWatchedConfig() else {
                task.setTaskCompleted(success: true)
                scheduleProcessing()
                return
            }

            guard !Task.isCancelled else {
                task.setTaskCompleted(success: false)
                return
            }

            let auth = AuthService.shared
            await auth.ensureAuthenticated()
            guard auth.isAuthenticated else {
                task.setTaskCompleted(success: false)
                scheduleProcessing()
                return
            }

            await OfflineSyncQueue.shared.flushQueue()

            let ped = await fetchPedometerSteps()
            let loc = currentLocation()

            do {
                try await PersonRepository.shared.updateStatus(
                    config.personId,
                    status: .safe,
                    steps: ped.steps,
                    anomalyCount: 0,
                    riskLevel: "normal",
                    steadiness: nil,
                    latitude: loc.lat,
                    longitude: loc.lon
                )
            } catch {}

            task.setTaskCompleted(success: true)
            scheduleProcessing()
        }

        task.expirationHandler = {
            bgTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
