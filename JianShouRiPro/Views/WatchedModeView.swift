import SwiftUI

struct WatchedModeView: View {
    let appModeManager: AppModeManager
    @State private var gaitViewModel = GaitViewModel()
    @State private var syncService = RemoteSyncService()
    @State private var showResetConfirmation = false
    @State private var showPairingCode = false
    @State private var isAutoMonitoring = false
    @State private var permissionsReady = false

    private let personRepo = PersonRepository.shared
    private let pairingRepo = PairingRepository.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusHeader
                    sharePairingCodeCard
                    syncStatusCard
                    autoMonitorToggle
                    currentMetricsCard
                    connectionInfoCard
                    resetSection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("見守りモード")
            .sheet(isPresented: $showPairingCode) {
                if let personId = appModeManager.linkedPersonId {
                    PairingCodeGeneratorView(
                        personId: personId,
                        deviceId: appModeManager.deviceId
                    )
                }
            }
            .task {
                await PermissionManager.requestWatchedModePermissions(
                    gaitViewModel: gaitViewModel,
                    hasLinkedPerson: appModeManager.linkedPersonId != nil
                )
                permissionsReady = true
                setupHealthKitCallbacks()
                autoStartIfNeeded()
            }
            .onChange(of: gaitViewModel.currentRiskLevel) { _, newValue in
                guard isAutoMonitoring else { return }
                syncService.onStateChanged(
                    newRiskLevel: newValue,
                    isWalking: gaitViewModel.motionService.isWalking
                )
            }
            .onChange(of: gaitViewModel.motionService.isWalking) { _, newValue in
                guard isAutoMonitoring else { return }
                syncService.onStateChanged(
                    newRiskLevel: gaitViewModel.currentRiskLevel,
                    isWalking: newValue
                )
            }
            .onChange(of: appModeManager.currentMode) { _, newMode in
                if newMode != .watched && isAutoMonitoring {
                    gaitViewModel.stopMonitoring()
                    gaitViewModel.healthService.stopBackgroundObservers()
                    syncService.stopAutoSync()
                    isAutoMonitoring = false
                    Task {
                        if let personId = appModeManager.linkedPersonId {
                            await personRepo.setOffline(personId)
                        }
                    }
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
                Image(systemName: "figure.walk.motion")
                    .font(.largeTitle)
                    .foregroundStyle(.teal)
                    .symbolEffect(.pulse, options: .repeating.speed(0.5), value: syncService.isSyncing)
            }

            Text("あなたのデバイス")
                .font(.title2.bold())

            HStack(spacing: 8) {
                Circle()
                    .fill(syncService.isSyncing ? .green : .gray)
                    .frame(width: 10, height: 10)
                Text(syncService.isSyncing ? "データ送信中" : "待機中")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(syncService.isSyncing ? .green : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background((syncService.isSyncing ? Color.green : Color.gray).opacity(0.12), in: Capsule())
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
                if syncService.isSyncing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("同期中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Label("最終同期", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let lastSync = syncService.lastSyncTime {
                    Text(lastSync, style: .relative)
                        .font(.subheadline.monospacedDigit())
                } else {
                    Text("未同期")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack {
                Label("送信間隔", systemImage: "timer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(syncService.isUrgentMode ? "10秒ごと（緊急）" : "30秒ごと")
                    .font(.subheadline)
                    .foregroundStyle(syncService.isUrgentMode ? .orange : .primary)
            }

            if let error = syncService.syncError {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .lineLimit(3)
                    }

                    Button {
                        syncService.retryNow()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("再送信")
                        }
                        .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .controlSize(.small)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var autoMonitorToggle: some View {
        VStack(spacing: 12) {
            Button {
                toggleAutoMonitoring()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isAutoMonitoring ? "stop.fill" : "figure.walk.motion")
                        .contentTransition(.symbolEffect(.replace))
                    Text(isAutoMonitoring ? "自動計測を停止" : "自動計測を開始")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(isAutoMonitoring ? .red : .teal)
            .sensoryFeedback(.impact, trigger: isAutoMonitoring)

            Text("自動計測を開始すると、歩行データをリアルタイムで\n見守る側に送信します")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var currentMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("現在のデータ")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCardView(
                    title: "今日の歩数",
                    value: "\(gaitViewModel.todaySteps)",
                    icon: "shoeprints.fill",
                    color: .blue
                )
                MetricCardView(
                    title: "リスクレベル",
                    value: gaitViewModel.currentRiskLevel.label,
                    icon: gaitViewModel.currentRiskLevel.systemImage,
                    color: riskColor
                )
                MetricCardView(
                    title: "ケイデンス",
                    value: String(format: "%.0f", gaitViewModel.motionService.currentCadence),
                    icon: "metronome",
                    color: .purple
                )
                MetricCardView(
                    title: "異常検出",
                    value: "\(gaitViewModel.todayAnomalyCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: gaitViewModel.todayAnomalyCount > 0 ? .orange : .green
                )
            }
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
                Text(appModeManager.linkedPersonId != nil ? "ペアリング済み" : "未接続")
                    .font(.subheadline)
                    .foregroundStyle(appModeManager.linkedPersonId != nil ? .green : .secondary)
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
                syncService.stopAutoSync()
                gaitViewModel.stopMonitoring()
                Task {
                    if let personId = appModeManager.linkedPersonId {
                        await personRepo.setOffline(personId)
                        await pairingRepo.deleteDeviceLink(personId: personId, watchedDeviceId: appModeManager.deviceId)
                    }
                    appModeManager.resetAll()
                }
            }
        } message: {
            Text("見守り接続が切断されます。再度コードの入力が必要です。")
        }
    }

    private var riskColor: Color {
        switch gaitViewModel.currentRiskLevel {
        case .normal: .green
        case .elevated: .orange
        case .high: .red
        }
    }

    private func toggleAutoMonitoring() {
        if isAutoMonitoring {
            gaitViewModel.stopMonitoring()
            gaitViewModel.healthService.stopBackgroundObservers()
            syncService.stopAutoSync()
            isAutoMonitoring = false
        } else {
            guard let personId = appModeManager.linkedPersonId else { return }
            gaitViewModel.startMonitoring()
            gaitViewModel.healthService.startBackgroundObservers()
            syncService.startAutoSync(
                personId: personId,
                deviceId: appModeManager.deviceId,
                gaitViewModel: gaitViewModel
            )
            isAutoMonitoring = true
        }
    }

    private func autoStartIfNeeded() {
        guard let personId = appModeManager.linkedPersonId else { return }
        guard !isAutoMonitoring else { return }
        guard !appModeManager.deviceId.isEmpty else { return }
        gaitViewModel.startMonitoring()
        gaitViewModel.healthService.startBackgroundObservers()
        syncService.startAutoSync(
            personId: personId,
            deviceId: appModeManager.deviceId,
            gaitViewModel: gaitViewModel
        )
        isAutoMonitoring = true
    }

    private func setupHealthKitCallbacks() {
        gaitViewModel.healthService.onStepCountUpdated = { [weak gaitViewModel, weak syncService] steps in
            Task { @MainActor in
                gaitViewModel?.todaySteps = steps
                syncService?.triggerImmediateSync()
            }
        }
        gaitViewModel.healthService.onSteadinessUpdated = { [weak syncService] _ in
            Task { @MainActor in
                syncService?.triggerImmediateSync()
            }
        }
    }
}
