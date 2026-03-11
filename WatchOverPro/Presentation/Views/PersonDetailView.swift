import SwiftUI
import MapKit

struct PersonDetailView: View {
    let member: FamilyMember
    let watchOverViewModel: WatchOverViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locationRepository) private var locationRepo
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var routeChunks: [RouteChunk] = []
    @State private var stopEvents: [StopEvent] = []
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var subscriptionTask: Task<Void, Never>?

    private var location: CurrentLocation? {
        watchOverViewModel.latestLocations[member.memberUserId]
    }

    private var memberAlerts: [AlertEvent] {
        watchOverViewModel.alertsForMember(member.memberUserId)
    }

    private var status: PersonStatus {
        watchOverViewModel.status(for: member)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statusBadge
                mapCard
                quickMetrics
                quietHoursCard
                if !memberAlerts.isEmpty {
                    alertsCard
                }
                if !member.notes.isEmpty {
                    notesCard
                }
                dangerZone
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(member.displayName)
        .navigationBarTitleDisplayMode(.inline)
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
                dismiss()
            }
        } message: {
            Text("\(member.displayName)さんのデータがすべて削除されます。")
        }
        .sheet(isPresented: $showEditSheet) {
            PersonEditView(member: member)
        }
        .task {
            await loadRouteData()
            updateMapPosition()
        }
        .onDisappear {
            subscriptionTask?.cancel()
            subscriptionTask = nil
        }
        .navigationDestination(for: String.self) { value in
            if value == "quietHours", let uuid = UUID(uuidString: member.memberUserId) {
                QuietHoursListView(
                    personId: uuid,
                    personName: member.displayName,
                    personColorHex: member.colorHex
                )
            }
        }
        .refreshable {
            await loadRouteData()
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: member.colorHex).opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: member.relationship.icon)
                    .font(.title2)
                    .foregroundStyle(Color(hex: member.colorHex))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.title3.bold())
                    Text(member.relationship.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
                HStack(spacing: 8) {
                    Image(systemName: status.icon)
                        .foregroundStyle(statusColor)
                        .font(.caption)
                    Text(status.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(statusColor)
                    if let updatedAt = location?.updatedAt {
                        Text("・")
                            .foregroundStyle(.tertiary)
                        Text(updatedAt.relativeFormatted)
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

    private var mapCard: some View {
        PersonDetailMapCard(
            member: member,
            location: location,
            mapPosition: $mapPosition
        )
    }

    private var quickMetrics: some View {
        HStack(spacing: 8) {
            quickMetricItem(
                icon: "location.fill",
                value: location != nil ? "取得済み" : "—",
                label: "位置情報",
                color: location != nil ? .teal : .secondary
            )
            quickMetricItem(
                icon: status.icon,
                value: status.label,
                label: "ステータス",
                color: statusColor
            )
            quickMetricItem(
                icon: "stop.circle.fill",
                value: "\(stopEvents.count)",
                label: "停止検知",
                color: stopEvents.isEmpty ? .green : .orange
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
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    @ViewBuilder
    private var quietHoursCard: some View {
        let isInQuiet = watchOverViewModel.isInQuietHours(for: member.memberUserId)
        let quietPeriod = watchOverViewModel.activeQuietPeriod(for: member.memberUserId)

        if let quietPeriod, isInQuiet {
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
        } else if let uuid = UUID(uuidString: member.memberUserId) {
            let quietCount = QuietHoursStore.shared.periods(for: uuid).count
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

    private var alertsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近のアラート")
                    .font(.headline)
                Spacer()
                Text("\(memberAlerts.count)件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(memberAlerts.prefix(5)) { alert in
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
                            watchOverViewModel.markAlertAsRead(alert)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("メモ")
                .font(.headline)
            Text(member.notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
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
        switch status {
        case .online: .green
        case .stale: .orange
        case .offline: .gray
        }
    }

    private func loadRouteData() async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let today = dateFormatter.string(from: Date())

        do {
            routeChunks = try await locationRepo.getRoute24h(
                trackedUserId: member.memberUserId,
                date: today
            )
            stopEvents = try await locationRepo.getStopEvents24h(
                trackedUserId: member.memberUserId,
                date: today
            )
        } catch {}
    }

    private func updateMapPosition() {
        if let loc = location {
            mapPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lng),
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
    }
}
