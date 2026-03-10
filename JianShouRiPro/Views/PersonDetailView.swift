import SwiftUI
import MapKit
import Supabase

struct PersonDetailView: View {
    let personId: UUID
    let watchOverViewModel: WatchOverViewModel
    let appModeManager: AppModeManager

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var remoteData: RemoteGaitData?
    @State private var isLoadingRemote = false
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var detailRealtimeTask: Task<Void, Never>?

    private let auth = AuthService.shared
    private let gaitDataRepo = GaitDataRepository.shared

    private var person: WatchPerson? {
        watchOverViewModel.persons.first(where: { $0.id == personId })
    }

    private var safePerson: WatchPerson {
        person ?? WatchPerson(id: personId, name: "不明", relationship: .other, age: 0)
    }

    private var personAlerts: [AlertEvent] {
        watchOverViewModel.alertsForPerson(personId)
    }

    init(person: WatchPerson, watchOverViewModel: WatchOverViewModel, appModeManager: AppModeManager) {
        self.personId = person.id
        self.watchOverViewModel = watchOverViewModel
        self.appModeManager = appModeManager
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statusBadge
                inactivityCard
                PersonDetailMapCard(
                    person: safePerson,
                    remoteData: remoteData,
                    mapPosition: $mapPosition
                )
                quickMetrics
                if let data = remoteData {
                    PersonDetailActivityCard(remoteData: data, person: safePerson)
                }
                quietHoursCard
                if !personAlerts.isEmpty {
                    alertsCard
                }
                notesCard
                dangerZone
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(safePerson.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: person == nil) { _, isNil in
            if isNil { dismiss() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("この見守り対象を削除しますか？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                Task {
                    await watchOverViewModel.deletePerson(safePerson)
                    dismiss()
                }
            }
        } message: {
            Text("\(safePerson.name)さんのデータがすべて削除されます。")
        }
        .sheet(isPresented: $showEditSheet) {
            PersonEditView(person: safePerson, watchOverViewModel: watchOverViewModel)
        }
        .task {
            await loadRemoteData()
            await startDetailRealtime()
        }
        .onDisappear {
            let task = detailRealtimeTask
            detailRealtimeTask = nil
            task?.cancel()
        }
        .navigationDestination(for: String.self) { value in
            if value == "quietHours" {
                QuietHoursListView(
                    personId: safePerson.id,
                    personName: safePerson.name,
                    personColorHex: safePerson.colorHex
                )
            }
        }
        .refreshable {
            await loadRemoteData()
        }
    }

    private var inactivityStatus: InactivityStatus? {
        watchOverViewModel.inactivityStatuses[personId]
    }

    private var isInQuietHours: Bool {
        watchOverViewModel.isInQuietHours(for: personId)
    }

    private var activeQuietPeriod: QuietHoursPeriod? {
        watchOverViewModel.activeQuietPeriod(for: personId)
    }

    private func startDetailRealtime() async {
        if let existingTask = detailRealtimeTask {
            existingTask.cancel()
            detailRealtimeTask = nil
        }

        let personId = personId
        let ch = auth.client.realtimeV2.channel("person-detail-\(personId.uuidString.prefix(8))")

        let remoteInserts = ch.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "remote_gait_data",
            filter: "person_id=eq.\(personId.uuidString)"
        )

        await ch.subscribe()

        let authRef = auth
        let gaitRepo = gaitDataRepo
        detailRealtimeTask = Task {
            defer {
                Task { @MainActor in
                    await authRef.client.realtimeV2.removeChannel(ch)
                }
            }
            for await _ in remoteInserts {
                guard !Task.isCancelled else { return }
                let latest = await gaitRepo.fetchLatest(for: personId)
                guard !Task.isCancelled else { return }
                remoteData = latest
                updateMapPosition()
            }
        }
    }

    private func loadRemoteData() async {
        isLoadingRemote = true
        remoteData = await gaitDataRepo.fetchLatest(for: personId)
        isLoadingRemote = false
        updateMapPosition()
    }

    private func updateMapPosition() {
        let lat = remoteData?.latitude ?? safePerson.latitude
        let lon = remoteData?.longitude ?? safePerson.longitude
        if let lat, let lon {
            mapPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
    }

    private var statusBadge: some View {
        let p = safePerson
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: p.colorHex).opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: p.relationship.icon)
                    .font(.title2)
                    .foregroundStyle(Color(hex: p.colorHex))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(p.name)
                        .font(.title3.bold())
                    Text(p.relationship.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
                HStack(spacing: 8) {
                    Image(systemName: p.status.icon)
                        .foregroundStyle(statusColor)
                        .font(.caption)
                    Text(p.status.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(statusColor)
                    if let lastActivity = p.lastActivity {
                        Text("・")
                            .foregroundStyle(.tertiary)
                        Text(lastActivity.relativeFormatted)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    @ViewBuilder
    private var quietHoursCard: some View {
        let p = safePerson
        if let quietPeriod = activeQuietPeriod {
            HStack(spacing: 12) {
                Image(systemName: "moon.stars.fill")
                    .font(.title3)
                    .foregroundStyle(.indigo)

                VStack(alignment: .leading, spacing: 3) {
                    Text("非カウント時間中")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                    Text("\(quietPeriod.label)（\(quietPeriod.startTimeString)〜\(quietPeriod.endTimeString)）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("歩行・非活動の判定を一時停止しています")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                NavigationLink(value: "quietHours") {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(14)
            .background(Color.indigo.opacity(0.08), in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
            )
        } else {
            let quietCount = QuietHoursStore.shared.periods(for: p.id).count
            NavigationLink(value: "quietHours") {
                HStack(spacing: 10) {
                    Image(systemName: quietCount > 0 ? "moon.stars.fill" : "moon.stars")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(quietCount > 0 ? "非カウント時間" : "非カウント時間を設定")
                        .font(.subheadline)
                        .foregroundStyle(quietCount > 0 ? .primary : .secondary)
                    Spacer()
                    if quietCount > 0 {
                        Text("\(quietCount)件設定済み")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var inactivityCard: some View {
        if isInQuietHours {
            EmptyView()
        } else if let status = inactivityStatus, status.level != .active {
            HStack(spacing: 12) {
                Image(systemName: status.level.icon)
                    .font(.title3)
                    .foregroundStyle(inactivityColor(status.level))
                    .symbolEffect(.pulse, options: .repeating.speed(0.5), value: status.level == .critical)

                VStack(alignment: .leading, spacing: 3) {
                    Text(status.level.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(inactivityColor(status.level))
                    if status.inactiveDuration > 0 {
                        Text("\(status.durationText)活動が確認できません")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let lastActive = status.lastActiveTime {
                        Text("最終活動: \(lastActive.relativeFormatted)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(inactivityColor(status.level).opacity(0.08), in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(inactivityColor(status.level).opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func inactivityColor(_ level: InactivityLevel) -> Color {
        switch level {
        case .active: .green
        case .idle: .gray
        case .warning: .orange
        case .critical: .red
        }
    }

    private var quickMetrics: some View {
        HStack(spacing: 8) {
            quickMetricItem(
                icon: "shoeprints.fill",
                value: "\(remoteData?.steps ?? safePerson.todaySteps)",
                label: "歩数",
                color: .blue
            )
            quickMetricItem(
                icon: riskIcon,
                value: gaitRiskDisplayLabel,
                label: "歩行異常",
                color: riskColor
            )
            quickMetricItem(
                icon: inactivityRiskIcon,
                value: inactivityRiskDisplayLabel,
                label: "非活動異常",
                color: inactivityRiskColor
            )
        }
    }

    private func quickMetricItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                Text(value)
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(label == "歩数" ? .primary : color)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    private var isPaired: Bool {
        remoteData != nil || safePerson.lastActivity != nil
    }

    private var gaitRiskDisplayLabel: String {
        guard isPaired else { return "—" }
        switch currentRiskLevel {
        case "normal": return "安全"
        case "elevated": return "注意"
        case "high": return "警告"
        default: return "—"
        }
    }

    private var inactivityRiskDisplayLabel: String {
        guard isPaired, let status = inactivityStatus else { return "—" }
        switch status.level {
        case .active, .idle: return "安全"
        case .warning: return "注意"
        case .critical: return "警告"
        }
    }

    private var inactivityRiskColor: Color {
        guard isPaired, let status = inactivityStatus else { return .secondary }
        switch status.level {
        case .active, .idle: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private var inactivityRiskIcon: String {
        guard isPaired, let status = inactivityStatus else { return "questionmark.circle" }
        switch status.level {
        case .active, .idle: return "checkmark.shield.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.shield.fill"
        }
    }

    private var alertsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近のアラート")
                    .font(.headline)
                Spacer()
                Text("\(personAlerts.count)件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(personAlerts.prefix(5)) { alert in
                HStack(spacing: 10) {
                    Circle()
                        .fill(alert.isRead ? Color(.systemGray4) : .orange)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.message)
                            .font(.subheadline)
                            .lineLimit(2)
                        Text(alert.createdAt.relativeFormatted)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    if !alert.isRead {
                        Button {
                            Task { await watchOverViewModel.markAlertAsRead(alert) }
                        } label: {
                            Text("既読")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    @ViewBuilder
    private var notesCard: some View {
        if !safePerson.notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("メモ")
                    .font(.headline)
                Text(safePerson.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        }
    }

    private var dangerZone: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                Text("この見守り対象を削除")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    private var statusColor: Color {
        switch safePerson.status {
        case .safe: .green
        case .warning: .orange
        case .alert: .red
        case .offline: .gray
        }
    }

    private var currentRiskLevel: String {
        remoteData?.riskLevel ?? safePerson.lastRiskLevel
    }

    private var riskIcon: String {
        guard isPaired else { return "questionmark.circle" }
        switch currentRiskLevel {
        case "normal": return "checkmark.shield.fill"
        case "elevated": return "exclamationmark.triangle.fill"
        case "high": return "xmark.shield.fill"
        default: return "questionmark.circle"
        }
    }

    private var riskColor: Color {
        guard isPaired else { return .secondary }
        switch currentRiskLevel {
        case "normal": return .green
        case "elevated": return .orange
        case "high": return .red
        default: return .secondary
        }
    }
}
