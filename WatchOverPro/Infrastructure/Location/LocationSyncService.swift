import Foundation
import CoreLocation

@Observable
@MainActor
final class LocationSyncService {
    var isSyncing = false
    var lastSyncTime: Date?
    var syncError: String?

    private let locationService: LocationService
    private let updateLocationUseCase: UpdateLocationUseCase
    private let manageRouteChunks: ManageRouteChunksUseCase
    private let detectStopEvent: DetectStopEventUseCase

    private var syncTask: Task<Void, Never>?
    private var trackedUserId: String = ""
    private let syncInterval: TimeInterval = 15

    init(
        locationService: LocationService,
        locationRepo: any LocationRepositoryProtocol
    ) {
        self.locationService = locationService
        self.updateLocationUseCase = UpdateLocationUseCase(repository: locationRepo)
        self.manageRouteChunks = ManageRouteChunksUseCase(repository: locationRepo)
        self.detectStopEvent = DetectStopEventUseCase(repository: locationRepo)
    }

    func startSync(trackedUserId: String) {
        self.trackedUserId = trackedUserId
        locationService.start()
        isSyncing = true
        syncError = nil

        syncTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.performSync()
                try? await Task.sleep(for: .seconds(self.syncInterval))
            }
        }
    }

    func stopSync() {
        syncTask?.cancel()
        syncTask = nil
        locationService.stop()
        isSyncing = false
        manageRouteChunks.reset()
        detectStopEvent.reset()
    }

    private func performSync() async {
        guard let lat = locationService.currentLatitude,
              let lng = locationService.currentLongitude else {
            return
        }

        do {
            try await updateLocationUseCase.execute(
                trackedUserId: trackedUserId,
                lat: lat,
                lng: lng
            )

            manageRouteChunks.addPoint(lat: lat, lng: lng, altitude: nil, speed: nil)
            if manageRouteChunks.shouldFlush {
                try await manageRouteChunks.flush(trackedUserId: trackedUserId)
            }

            try await detectStopEvent.evaluate(
                trackedUserId: trackedUserId,
                lat: lat,
                lng: lng
            )

            syncError = nil
            lastSyncTime = Date()
        } catch {
            syncError = error.localizedDescription
        }
    }
}
