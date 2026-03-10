import SwiftUI

@main
struct IOSGaitAnomalyDetectorApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundTaskService.registerAll()
        OfflineSyncQueue.shared.startMonitoring()
        NotificationService.shared.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await NotificationService.shared.checkAuthorizationStatus()
                }
            }
        }
    }
}
