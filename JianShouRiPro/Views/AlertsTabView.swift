import SwiftUI

struct AlertsTabView: View {
    let watchOverViewModel: WatchOverViewModel

    var body: some View {
        NavigationStack {
            Group {
                if watchOverViewModel.alertEvents.isEmpty {
                    ContentUnavailableView(
                        "アラートなし",
                        systemImage: "bell.slash",
                        description: Text("異常が検出されると、ここに通知が表示されます。")
                    )
                } else {
                    List {
                        ForEach(watchOverViewModel.alertEvents) { alert in
                            let personName = watchOverViewModel.persons.first(where: { $0.id == alert.personId })?.name ?? "不明"

                            HStack(spacing: 12) {
                                Circle()
                                    .fill(alert.isRead ? Color(.systemGray4) : severityColor(alert.severity))
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(personName)
                                            .font(.subheadline.bold())
                                        Spacer()
                                        Text(alert.createdAt.relativeFormatted)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }

                                    Text(alert.message)
                                        .font(.subheadline)
                                        .foregroundStyle(alert.isRead ? .secondary : .primary)
                                        .lineLimit(3)
                                }
                            }
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing) {
                                if !alert.isRead {
                                    Button {
                                        Task { await watchOverViewModel.markAlertAsRead(alert) }
                                    } label: {
                                        Label("既読", systemImage: "checkmark")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("アラート")
        }
    }

    private func severityColor(_ severity: Double) -> Color {
        if severity > 0.7 { return .red }
        if severity > 0.4 { return .orange }
        return .yellow
    }
}
