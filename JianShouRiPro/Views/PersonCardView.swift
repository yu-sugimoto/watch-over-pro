import SwiftUI

struct PersonCardView: View {
    let person: WatchPerson
    let alertCount: Int
    var inactivityStatus: InactivityStatus?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: person.colorHex).opacity(0.2))
                        .frame(width: 52, height: 52)
                    Image(systemName: person.relationship.icon)
                        .font(.title3)
                        .foregroundStyle(Color(hex: person.colorHex))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(person.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(person.relationship.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }

                    HStack(spacing: 12) {
                        if person.latitude != nil {
                            Label("位置情報あり", systemImage: "location.fill")
                                .foregroundStyle(.teal)
                        } else {
                            Label("位置情報なし", systemImage: "location.slash")
                        }
                        if let activity = person.lastActivity {
                            Label(activity.relativeFormatted, systemImage: "clock")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: person.status.icon)
                        .font(.title3)
                        .foregroundStyle(statusColor(person.status))

                    if alertCount > 0 {
                        Text("\(alertCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red, in: Capsule())
                    }
                }
            }

            if let status = inactivityStatus, status.level == .warning || status.level == .critical {
                Divider()
                    .padding(.top, 10)
                HStack(spacing: 6) {
                    Image(systemName: status.level.icon)
                        .font(.caption)
                        .foregroundStyle(status.level == .critical ? .red : .orange)
                    Text(status.level.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(status.level == .critical ? .red : .orange)
                    if status.inactiveDuration > 0 {
                        Text("(\(status.durationText))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private func statusColor(_ status: PersonStatus) -> Color {
        switch status {
        case .safe: .green
        case .warning: .orange
        case .alert: .red
        case .offline: .gray
        }
    }
}
