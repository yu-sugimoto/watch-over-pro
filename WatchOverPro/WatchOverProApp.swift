import SwiftUI

@main
struct WatchOverProApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AmplifyConfiguration.configure()
        BackgroundTaskService.registerAll()
        NotificationService.shared.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locationRepository, AppSyncLocationRepository())
                .environment(\.familyRepository, AppSyncFamilyRepository())
                .environment(\.pairingRepository, AppSyncPairingRepository())
                .environment(\.authRepository, CognitoAuthRepository())
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
