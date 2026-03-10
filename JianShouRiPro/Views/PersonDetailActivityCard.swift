import SwiftUI

struct PersonDetailActivityCard: View {
    let remoteData: RemoteGaitData
    let person: WatchPerson

    private var isOffline: Bool { person.status == .offline }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("リアルタイム状態")
                    .font(.headline)
                Spacer()
                statusBadge
            }

            HStack(spacing: 0) {
                metricColumn(
                    value: String(format: "%.0f", remoteData.cadence),
                    label: "歩/分"
                )

                Divider().frame(height: 36)

                metricColumn(
                    value: remoteData.pace > 0 ? String(format: "%.2f", remoteData.pace) : "—",
                    label: "s/m"
                )

                Divider().frame(height: 36)

                metricColumn(
                    value: (remoteData.walkingSteadiness ?? person.walkingSteadiness).map { String(format: "%.0f%%", $0 * 100) } ?? "—",
                    label: "安定性"
                )
            }
            .padding(.vertical, 8)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isOffline {
            HStack(spacing: 4) {
                Circle()
                    .fill(.gray)
                    .frame(width: 8, height: 8)
                Text("オフライン")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.12), in: Capsule())
        } else {
            HStack(spacing: 4) {
                Circle()
                    .fill(remoteData.isWalking ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(remoteData.isWalking ? "歩行中" : "静止中")
                    .font(.caption.bold())
                    .foregroundStyle(remoteData.isWalking ? .green : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((remoteData.isWalking ? Color.green : Color.gray).opacity(0.12), in: Capsule())
        }
    }

    private func metricColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
