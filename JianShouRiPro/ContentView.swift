import SwiftUI

struct ContentView: View {
    @State private var appModeManager = AppModeManager()
    @State private var watchOverViewModel = WatchOverViewModel()
    @State private var selectedTab = 0
    @State private var isAuthReady = false
    @State private var authFailed = false
    @State private var isRetrying = false
    @State private var authErrorDetail: String = ""
    @State private var retryCount = 0

    var body: some View {
        Group {
            if isAuthReady {
                switch appModeManager.currentMode {
                case .none:
                    AppModeSelectionView(appModeManager: appModeManager)

                case .watcher:
                    watcherTabView

                case .watched:
                    WatchedModeView(appModeManager: appModeManager)
                }
            } else if authFailed {
                VStack(spacing: 20) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("接続できません")
                        .font(.title3.bold())
                    Text("ネットワーク接続を確認してください")
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
                        Task { await retryAuth() }
                    } label: {
                        HStack(spacing: 8) {
                            if isRetrying {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("再試行")
                                .fontWeight(.semibold)
                        }
                        .frame(minWidth: 120)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .disabled(isRetrying)
                }
            } else {
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
        .task {
            await performAuth()
        }
    }

    private func performAuth() async {
        let auth = AuthService.shared

        if Config.SUPABASE_URL.isEmpty || Config.SUPABASE_ANON_KEY.isEmpty {
            authErrorDetail = "Supabaseの設定が見つかりません。環境変数を確認してください。"
            authFailed = true
            return
        }

        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(for: .seconds(Double(attempt) * 1.5))
            }
            await auth.ensureAuthenticated()
            if auth.isAuthenticated {
                isAuthReady = true
                authFailed = false
                return
            }
        }

        authErrorDetail = auth.errorMessage ?? "サーバーに接続できませんでした"
        authFailed = true
    }

    private func retryAuth() async {
        isRetrying = true
        authFailed = false
        await performAuth()
        isRetrying = false
    }

    private var watcherTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("見守り", systemImage: "shield.checkered", value: 0) {
                WatchOverView(
                    watchOverViewModel: watchOverViewModel,
                    appModeManager: appModeManager
                )
            }

            Tab("アラート", systemImage: "bell.badge", value: 1) {
                AlertsTabView(watchOverViewModel: watchOverViewModel)
            }

            Tab("設定", systemImage: "gearshape", value: 2) {
                SettingsView(appModeManager: appModeManager)
            }
        }
        .tint(.teal)
        .onAppear {
            watchOverViewModel.deviceId = appModeManager.deviceId
        }
        .onChange(of: appModeManager.currentMode) { _, newMode in
            if newMode != .watcher {
                Task {
                    await watchOverViewModel.stopRealtime()
                }
            }
        }
    }
}
