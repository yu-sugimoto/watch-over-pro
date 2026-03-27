import SwiftUI

struct WatchedModeView: View {
    let appModeManager: AppModeManager
    @Environment(\.locationRepository) private var locationRepo
    @Environment(\.familyRepository) private var familyRepo

    @State private var locationService = LocationService()
    @State private var syncService: LocationSyncService?
    @State private var showResetConfirmation = false
    @State private var showPairingCode = false
    @State private var isTracking = false
    @State private var permissionsReady = false
    @State private var resetError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusHeader
                    sharePairingCodeCard
                    syncStatusCard
                    trackingToggle
                    connectionInfoCard
                    resetSection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("見守りモード")
            .sheet(isPresented: $showPairingCode) {
                if let familyId = appModeManager.familyId {
                    PairingCodeGeneratorView(familyId: familyId)
                }
            }
            .task {
                let service = LocationSyncService(
                    locationService: locationService,
                    locationRepo: locationRepo
                )
                syncService = service
                await PermissionManager.requestWatchedModePermissions(
                    hasLinkedPerson: appModeManager.trackedUserId != nil
                )
                permissionsReady = true
                autoStartIfNeeded()
            }
            .onChange(of: appModeManager.currentMode) { _, newMode in
                if newMode != .watched && isTracking {
                    syncService?.stopSync()
                    isTracking = false
                }
            }
        }
    }

    private var sharePairingCodeCard: some View {
        Button {
            showPairingCode = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.teal.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "key.fill")
                        .font(.body)
                        .foregroundStyle(.teal)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("招待コードを共有")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("見守る側を追加するにはコードを共有してください")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var statusHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.teal.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "location.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.teal)
                    .symbolEffect(.pulse, options: .repeating.speed(0.5), value: syncService?.isSyncing ?? false)
            }

            Text("あなたのデバイス")
                .font(.title2.bold())

            HStack(spacing: 8) {
                Circle()
                    .fill((syncService?.isSyncing ?? false) ? .green : .gray)
                    .frame(width: 10, height: 10)
                Text((syncService?.isSyncing ?? false) ? "位置情報送信中" : "待機中")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle((syncService?.isSyncing ?? false) ? .green : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(((syncService?.isSyncing ?? false) ? Color.green : Color.gray).opacity(0.12), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var syncStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("同期状態")
                    .font(.headline)
                Spacer()
                if syncService?.isSyncing ?? false {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("送信中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Label("最終送信", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let lastSync = syncService?.lastSyncTime {
                    Text(lastSync, style: .relative)
                        .font(.subheadline.monospacedDigit())
                } else {
                    Text("未送信")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack {
                Label("送信間隔", systemImage: "timer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("15秒ごと")
                    .font(.subheadline)
            }

            if let error = syncService?.syncError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(3)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var trackingToggle: some View {
        VStack(spacing: 12) {
            Button {
                toggleTracking()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isTracking ? "stop.fill" : "location.fill")
                        .contentTransition(.symbolEffect(.replace))
                    Text(isTracking ? "位置情報送信を停止" : "位置情報送信を開始")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(isTracking ? .red : .teal)
            .sensoryFeedback(.impact, trigger: isTracking)

            Text("位置情報送信を開始すると、現在地をリアルタイムで\n見守る側に送信します")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var connectionInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("接続情報")
                .font(.headline)

            HStack {
                Label("ステータス", systemImage: "link")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(appModeManager.trackedUserId != nil ? "ペアリング済み" : "未接続")
                    .font(.subheadline)
                    .foregroundStyle(appModeManager.trackedUserId != nil ? .green : .secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var resetSection: some View {
        Button(role: .destructive) {
            showResetConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward")
                Text("ペアリングを解除")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .confirmationDialog("ペアリングを解除しますか？", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("解除する", role: .destructive) {
                syncService?.stopSync()
                isTracking = false
                Task {
                    if let familyId = appModeManager.familyId,
                       let trackedUserId = appModeManager.trackedUserId {
                        do {
                            try await familyRepo.deleteFamilyMember(familyId: familyId, memberUserId: trackedUserId)
                        } catch {
                            resetError = error.localizedDescription
                        }
                    }
                    appModeManager.resetAll()
                }
            }
        } message: {
            Text("見守り接続が切断されます。再度コードの入力が必要です。")
        }
        .alert("解除中にエラーが発生しました", isPresented: .init(get: { resetError != nil }, set: { if !$0 { resetError = nil } })) {
            Button("OK") { resetError = nil }
        } message: {
            Text(resetError ?? "")
        }
    }

    private func toggleTracking() {
        if isTracking {
            syncService?.stopSync()
            isTracking = false
        } else {
            guard let trackedUserId = appModeManager.trackedUserId else { return }
            syncService?.startSync(trackedUserId: trackedUserId)
            isTracking = true
        }
    }

    private func autoStartIfNeeded() {
        guard appModeManager.trackedUserId != nil else { return }
        guard !isTracking else { return }
        toggleTracking()
    }
}
