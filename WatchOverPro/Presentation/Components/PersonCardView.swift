import SwiftUI

struct PersonCardView: View {
    let member: FamilyMember
    let status: PersonStatus
    let location: CurrentLocation?
    let alertCount: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: member.colorHex).opacity(0.2))
                        .frame(width: 52, height: 52)
                    Image(systemName: member.relationship.icon)
                        .font(.title3)
                        .foregroundStyle(Color(hex: member.colorHex))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(member.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(member.relationship.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }

                    HStack(spacing: 12) {
                        if location != nil {
                            Label("位置情報あり", systemImage: "location.fill")
                                .foregroundStyle(.teal)
                        } else {
                            Label("位置情報なし", systemImage: "location.slash")
                        }
                        if let updatedAt = location?.updatedAt {
                            Label(updatedAt.relativeFormatted, systemImage: "clock")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: status.icon)
                        .font(.title3)
                        .foregroundStyle(statusColor(status))

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
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private func statusColor(_ status: PersonStatus) -> Color {
        switch status {
        case .online: .green
        case .stale: .orange
        case .offline: .gray
        }
    }
}
