import SwiftUI

struct WatchOverView: View {
    @Bindable var watchOverViewModel: WatchOverViewModel
    let appModeManager: AppModeManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !watchOverViewModel.persons.isEmpty {
                        overviewHeader
                        alertBanner
                        personsSection
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
            .navigationDestination(for: UUID.self) { personId in
                if let person = watchOverViewModel.persons.first(where: { $0.id == personId }) {
                    PersonDetailView(
                        person: person,
                        watchOverViewModel: watchOverViewModel,
                        appModeManager: appModeManager
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
                if watchOverViewModel.deviceId.isEmpty {
                    watchOverViewModel.deviceId = appModeManager.deviceId
                }
                await watchOverViewModel.loadData()
                await watchOverViewModel.startRealtime()
            }
        }
    }

    private var overviewHeader: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatusSummaryCard(
                count: watchOverViewModel.persons.count,
                label: "見守り中",
                icon: "person.2.fill",
                color: .blue
            )
            StatusSummaryCard(
                count: watchOverViewModel.safePersonCount,
                label: "安全",
                icon: "checkmark.shield.fill",
                color: .green
            )
            StatusSummaryCard(
                count: watchOverViewModel.warningPersonCount + watchOverViewModel.inactivityAlertCount,
                label: "注意",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )
            StatusSummaryCard(
                count: watchOverViewModel.alertPersonCount,
                label: "警告",
                icon: "xmark.shield.fill",
                color: .red
            )
        }
    }

    @ViewBuilder
    private var alertBanner: some View {
        let unreadAlerts = watchOverViewModel.alertEvents.filter { !$0.isRead }
        if let latestAlert = unreadAlerts.first {
            let personName = watchOverViewModel.persons.first(where: { $0.id == latestAlert.personId })?.name ?? ""

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

                if !personName.isEmpty {
                    Text(personName)
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

    private var personsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("見守り対象")
                .font(.headline)
                .padding(.leading, 4)

            ForEach(watchOverViewModel.persons) { person in
                NavigationLink(value: person.id) {
                    PersonCardView(
                        person: person,
                        alertCount: watchOverViewModel.alertsForPerson(person.id).filter { !$0.isRead }.count,
                        inactivityStatus: watchOverViewModel.inactivityStatuses[person.id]
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
