import SwiftUI

struct WatchOverView: View {
    @Bindable var watchOverViewModel: WatchOverViewModel
    let appModeManager: AppModeManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !watchOverViewModel.familyMembers.isEmpty {
                        overviewHeader
                        alertBanner
                        membersSection
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("見守り Pro")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        watchOverViewModel.showAddPerson = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .navigationDestination(for: String.self) { memberUserId in
                if let member = watchOverViewModel.familyMembers.first(where: { $0.memberUserId == memberUserId }) {
                    PersonDetailView(
                        member: member,
                        watchOverViewModel: watchOverViewModel
                    )
                } else {
                    PersonNotFoundView()
                }
            }
            .sheet(isPresented: $watchOverViewModel.showAddPerson) {
                PersonRegistrationView(
                    watchOverViewModel: watchOverViewModel,
                    appModeManager: appModeManager
                )
            }
            .refreshable {
                await watchOverViewModel.loadData()
            }
            .task {
                await NotificationService.shared.requestAuthorization()
                watchOverViewModel.familyId = appModeManager.familyId
                await watchOverViewModel.loadData()
                await watchOverViewModel.startRealtime()
            }
        }
    }

    private var overviewHeader: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatusSummaryCard(
                count: watchOverViewModel.onlineCount,
                label: "オンライン",
                icon: "checkmark.circle.fill",
                color: .green
            )
            StatusSummaryCard(
                count: watchOverViewModel.staleCount,
                label: "更新なし",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )
            StatusSummaryCard(
                count: watchOverViewModel.offlineCount,
                label: "オフライン",
                icon: "wifi.slash",
                color: .gray
            )
        }
    }

    @ViewBuilder
    private var alertBanner: some View {
        let unreadAlerts = watchOverViewModel.alertEvents.filter { !$0.isRead }
        if let latestAlert = unreadAlerts.first {
            let memberName = watchOverViewModel.familyMembers.first(where: { $0.memberUserId == latestAlert.memberId })?.displayName ?? ""

            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, options: .repeating.speed(0.5), value: true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("最新のアラート")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(latestAlert.message)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                }

                Spacer()

                if !memberName.isEmpty {
                    Text(memberName)
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.12), in: Capsule())
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("見守り対象")
                .font(.headline)
                .padding(.leading, 4)

            ForEach(watchOverViewModel.familyMembers) { member in
                NavigationLink(value: member.memberUserId) {
                    PersonCardView(
                        member: member,
                        status: watchOverViewModel.status(for: member),
                        location: watchOverViewModel.latestLocations[member.memberUserId],
                        alertCount: watchOverViewModel.alertsForMember(member.memberUserId).filter { !$0.isRead }.count
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.teal)
                .symbolEffect(.pulse, options: .repeating.speed(0.3))

            Text("見守り対象を登録")
                .font(.title2.bold())

            Text("見守り対象の情報を登録し、\n招待コードを入力して見守りを開始しましょう。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                watchOverViewModel.showAddPerson = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("見守り対象を登録")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .padding(.horizontal, 20)
        }
    }
}
