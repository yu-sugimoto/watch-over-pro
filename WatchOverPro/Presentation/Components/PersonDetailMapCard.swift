import SwiftUI
import MapKit

struct PersonDetailMapCard: View {
    let member: FamilyMember
    let location: CurrentLocation?
    let routeChunks: [RouteChunk]
    let stopEvents: [StopEvent]
    @Binding var mapPosition: MapCameraPosition

    @State private var selectedStop: StopEvent?

    private var routeCoordinates: [CLLocationCoordinate2D] {
        routeChunks
            .sorted { $0.chunkStartEpochMs < $1.chunkStartEpochMs }
            .flatMap { $0.points }
            .map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    }

    private var hasRouteData: Bool {
        !routeCoordinates.isEmpty
    }

    var body: some View {
        if let loc = location {
            mapContent(loc: loc)
        } else {
            emptyState
        }
    }

    private func mapContent(loc: CurrentLocation) -> some View {
        Map(position: $mapPosition) {
            // Layer 1: Route polyline
            if routeCoordinates.count >= 2 {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(Color(hex: member.colorHex).opacity(0.6), lineWidth: 3)
            }

            // Layer 2: Stop markers
            ForEach(stopEvents) { stop in
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lng)) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedStop = selectedStop?.id == stop.id ? nil : stop
                        }
                    } label: {
                        Circle()
                            .fill(Color.orange.opacity(0.5))
                            .frame(width: 28, height: 28)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.orange, lineWidth: 1.5)
                            }
                    }
                }
            }

            // Layer 3: Current location icon
            Annotation(member.displayName, coordinate: CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lng)) {
                ZStack {
                    Circle()
                        .fill(Color(hex: member.colorHex))
                        .frame(width: 40, height: 40)
                        .shadow(color: Color(hex: member.colorHex).opacity(0.4), radius: 8, y: 2)
                    Image(systemName: member.relationship.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                Image(systemName: hasRouteData ? "figure.walk" : "location.fill")
                    .font(.caption2)
                Text(hasRouteData ? "24h 経路" : "現在地")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
            .padding(14)
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 5) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                Text(loc.updatedAt, style: .relative)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
            .padding(14)
        }
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: member.colorHex))
                    .frame(width: 10, height: 10)
                Text(member.displayName)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
            .padding(14)
        }
        .overlay {
            if let stop = selectedStop {
                stopDetailOverlay(stop: stop)
            }
        }
    }

    private func stopDetailOverlay(stop: StopEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "stop.circle.fill")
                    .foregroundStyle(.orange)
                Text("停止")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedStop = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Text(stopTimeRange(stop))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(stopDurationText(stop))
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
        }
        .padding(12)
        .frame(width: 200)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .environment(\.colorScheme, .dark)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }

    private func stopTimeRange(_ stop: StopEvent) -> String {
        let start = DateFormatters.hourMinute.string(from: stop.startedAt)
        if let end = stop.endedAt {
            let endStr = DateFormatters.hourMinute.string(from: end)
            return "\(start) 〜 \(endStr)"
        }
        return "\(start) 〜 継続中"
    }

    private func stopDurationText(_ stop: StopEvent) -> String {
        let seconds = stop.durationSeconds
        if seconds < 60 {
            return "\(seconds)秒間"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)分間"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "\(hours)時間"
        }
        return "\(hours)時間\(remainingMinutes)分"
    }

    private var emptyState: some View {
        Color(.secondarySystemGroupedBackground)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                VStack(spacing: 14) {
                    Image(systemName: "map")
                        .font(.system(size: 40))
                        .foregroundStyle(.quaternary)
                    Text("位置情報がありません")
                        .font(.subheadline.weight(.medium))
                    Text("見守られる側のアプリがペアリングされると\n位置情報がここに表示されます")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
    }
}
