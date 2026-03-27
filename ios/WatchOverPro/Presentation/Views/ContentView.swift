import SwiftUI

struct ContentView: View {
    @Environment(\.authRepository) private var authRepo
    @Environment(\.locationRepository) private var locationRepo
    @Environment(\.familyRepository) private var familyRepo
    @Environment(\.pairingRepository) private var pairingRepo

    @State private var appModeManager = AppModeManager()
    @State private var watchOverViewModel: WatchOverViewModel?
    @State private var selectedTab = 0
    @State private var isAuthReady = false
    @State private var authFailed = false
    @State private var isRetrying = false
    @State private var authErrorDetail: String = ""

    var body: some View {
        Group {
            if isAuthReady {
                switch appModeManager.currentMode {
                case .none:
                    AppModeSelectionView(appModeManager: appModeManager)

                case .watcher:
                    if let viewModel = watchOverViewModel {
                        watcherTabView(viewModel: viewModel)
                    }

                case .watched:
                    WatchedModeView(appModeManager: appModeManager)
                }
            } else if authFailed {
                authFailedView
            } else {
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
        .task {
            let vm = WatchOverViewModel(
                locationRepo: locationRepo,
                familyRepo: familyRepo,
                pairingRepo: pairingRepo
            )
            vm.familyId = appModeManager.familyId
            watchOverViewModel = vm
            await performAuth()
        }
    }

    private var authFailedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("サインインが必要です")
                .font(.title3.bold())
            Text("Apple IDでサインインしてください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !authErrorDetail.isEmpty {
                Text(authErrorDetail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button {
                Task { await signIn() }
            } label: {
                HStack(spacing: 8) {
                    if isRetrying {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Image(systemName: "applelogo")
                    Text("Appleでサインイン")
                        .fontWeight(.semibold)
                }
                .frame(minWidth: 200)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .disabled(isRetrying)
        }
    }

    private func performAuth() async {
        let isSignedIn = await authRepo.isAuthenticated
        if isSignedIn {
            isAuthReady = true
            authFailed = false
        } else {
            authFailed = true
        }
    }

    private func signIn() async {
        isRetrying = true
        authErrorDetail = ""
        do {
            try await authRepo.signInWithApple()
            isAuthReady = true
            authFailed = false
        } catch {
            authErrorDetail = error.localizedDescription
            authFailed = true
        }
        isRetrying = false
    }

    private func watcherTabView(viewModel: WatchOverViewModel) -> some View {
        TabView(selection: $selectedTab) {
            Tab("見守り", systemImage: "shield.checkered", value: 0) {
                WatchOverView(
                    watchOverViewModel: viewModel,
                    appModeManager: appModeManager
                )
            }

            Tab("設定", systemImage: "gearshape", value: 1) {
                SettingsView(appModeManager: appModeManager)
            }
        }
        .tint(.teal)
        .onChange(of: appModeManager.currentMode) { _, newMode in
            if newMode != .watcher {
                Task {
                    await viewModel.stopRealtime()
                }
            }
        }
    }
}
