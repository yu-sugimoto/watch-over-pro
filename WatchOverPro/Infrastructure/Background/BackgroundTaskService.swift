import Foundation
import BackgroundTasks
import CoreLocation

@MainActor
enum BackgroundTaskService {
    static let refreshIdentifier = "com.watchoverpro.app.sync"
    static let processingIdentifier = "com.watchoverpro.app.processing"

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

    private static func loadTrackedConfig() -> (trackedUserId: String, familyId: String)? {
        let defaults = UserDefaults.standard
        guard let modeRaw = defaults.string(forKey: "app_mode"),
              modeRaw == "watched",
              defaults.bool(forKey: "bg_location_active"),
              let trackedUserId = defaults.string(forKey: "tracked_user_id"),
              let familyId = defaults.string(forKey: "family_id") else {
            return nil
        }
        return (trackedUserId, familyId)
    }

    private static func currentLocation() -> (lat: Double?, lon: Double?) {
        let manager = CLLocationManager()
        return (manager.location?.coordinate.latitude, manager.location?.coordinate.longitude)
    }

    private static func handleRefresh(_ task: BGAppRefreshTask) {
        let bgTask = Task { @MainActor in
            guard let config = loadTrackedConfig() else {
                task.setTaskCompleted(success: true)
                scheduleRefresh()
                return
            }

            guard !Task.isCancelled else {
                task.setTaskCompleted(success: false)
                return
            }

            let loc = currentLocation()
            guard let lat = loc.lat, let lon = loc.lon else {
                task.setTaskCompleted(success: true)
                scheduleRefresh()
                return
            }

            let locationRepo = AppSyncLocationRepository()
            let location = CurrentLocation(
                trackedUserId: config.trackedUserId,
                lat: lat,
                lng: lon,
                isActive: true
            )

            do {
                try await locationRepo.updateCurrentLocation(location)
            } catch is CancellationError {
                // Background task expired
            } catch {
                print("[BackgroundTask] Refresh failed: \(error.localizedDescription)")
            }

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
            guard let config = loadTrackedConfig() else {
                task.setTaskCompleted(success: true)
                scheduleProcessing()
                return
            }

            guard !Task.isCancelled else {
                task.setTaskCompleted(success: false)
                return
            }

            let loc = currentLocation()
            guard let lat = loc.lat, let lon = loc.lon else {
                task.setTaskCompleted(success: true)
                scheduleProcessing()
                return
            }

            let locationRepo = AppSyncLocationRepository()
            let location = CurrentLocation(
                trackedUserId: config.trackedUserId,
                lat: lat,
                lng: lon,
                isActive: true
            )

            do {
                try await locationRepo.updateCurrentLocation(location)
            } catch is CancellationError {
                // Background task expired
            } catch {
                print("[BackgroundTask] Processing failed: \(error.localizedDescription)")
            }

            task.setTaskCompleted(success: true)
            scheduleProcessing()
        }

        task.expirationHandler = {
            bgTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
