import SwiftUI
import MapKit

struct PersonDetailView: View {
    let member: FamilyMember
    let watchOverViewModel: WatchOverViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locationRepository) private var locationRepo
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var routeChunks: [RouteChunk] = []
    @State private var stopEvents: [StopEvent] = []
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var routeLoadError: String?

    private var location: CurrentLocation? {
        watchOverViewModel.latestLocations[member.memberUserId]
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
                if let routeLoadError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(routeLoadError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
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
                isDeleting = true
                Task {
                    do {
                        try await watchOverViewModel.deleteMember(member)
                        dismiss()
                    } catch {
                        deleteError = error.localizedDescription
                    }
                    isDeleting = false
                }
            }
        } message: {
            Text("\(member.displayName)さんのデータがすべて削除されます。")
        }
        .alert("削除に失敗しました", isPresented: .init(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .sheet(isPresented: $showEditSheet) {
            PersonEditView(member: member, watchOverViewModel: watchOverViewModel)
        }
        .task {
            await loadRouteData()
            updateMapPosition()
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
            routeChunks: routeChunks,
            stopEvents: stopEvents,
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
        case .paused: .blue
        case .offline: .gray
        }
    }

    private func loadRouteData() async {
        let today = DateFormatters.yyyyMMdd.string(from: Date())
        routeLoadError = nil

        do {
            routeChunks = try await locationRepo.getRoute24h(
                trackedUserId: member.memberUserId,
                date: today
            )
            stopEvents = try await locationRepo.getStopEvents24h(
                trackedUserId: member.memberUserId,
                date: today
            )
        } catch {
            routeLoadError = "ルートデータの取得に失敗しました: \(error.localizedDescription)"
        }
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
