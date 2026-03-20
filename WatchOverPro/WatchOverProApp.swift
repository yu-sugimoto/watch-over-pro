import SwiftUI

@main
struct WatchOverProApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        guard !Self.isTesting else { return }
        AmplifyConfiguration.configure()
        BackgroundTaskService.registerAll()
        NotificationService.shared.registerCategories()
    }

    private static var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var body: some Scene {
        WindowGroup {
            if Self.isTesting {
                Color.clear
            } else {
                ContentView()
                    .environment(\.locationRepository, AppSyncLocationRepository())
                    .environment(\.familyRepository, AppSyncFamilyRepository())
                    .environment(\.pairingRepository, AppSyncPairingRepository())
                    .environment(\.authRepository, CognitoAuthRepository())
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && !Self.isTesting {
                Task {
                    await NotificationService.shared.checkAuthorizationStatus()
                }
            }
        }
    }
}
