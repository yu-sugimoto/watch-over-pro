import Foundation

@Observable
@MainActor
final class WatchOverViewModel {
    var familyMembers: [FamilyMember] = []
    var latestLocations: [String: CurrentLocation] = [:]
    var alertEvents: [AlertEvent] = []
    var isLoading = false
    var showAddPerson = false
    var showAlert = false
    var alertMessage = ""
    var familyId: String?

    private let locationRepo: any LocationRepositoryProtocol
    private let familyRepo: any FamilyRepositoryProtocol
    private let pairingRepo: any PairingRepositoryProtocol
    private let resolveStatus = ResolvePersonStatusUseCase()
    private let quietHoursStore = QuietHoursStore.shared
    private let notificationService = NotificationService.shared

    private var subscriptionTasks: [String: Task<Void, Never>] = [:]

    init(
        locationRepo: any LocationRepositoryProtocol,
        familyRepo: any FamilyRepositoryProtocol,
        pairingRepo: any PairingRepositoryProtocol
    ) {
        self.locationRepo = locationRepo
        self.familyRepo = familyRepo
        self.pairingRepo = pairingRepo
    }

    // MARK: - Computed Properties

    var unreadAlertCount: Int {
        alertEvents.filter { !$0.isRead }.count
    }

    var onlineCount: Int {
        familyMembers.filter { status(for: $0) == .online }.count
    }

    var staleCount: Int {
        familyMembers.filter { status(for: $0) == .stale }.count
    }

    var offlineCount: Int {
        familyMembers.filter { status(for: $0) == .offline }.count
    }

    func status(for member: FamilyMember) -> PersonStatus {
        let location = latestLocations[member.memberUserId]
        return resolveStatus.execute(lastUpdated: location?.updatedAt)
    }

    func alertsForMember(_ memberUserId: String) -> [AlertEvent] {
        alertEvents.filter { $0.memberId == memberUserId }
    }

    func isInQuietHours(for memberId: String) -> Bool {
        guard let uuid = UUID(uuidString: memberId) else { return false }
        return quietHoursStore.isInQuietHours(for: uuid)
    }

    func activeQuietPeriod(for memberId: String) -> QuietHoursPeriod? {
        guard let uuid = UUID(uuidString: memberId) else { return nil }
        return quietHoursStore.activeQuietPeriod(for: uuid)
    }

    // MARK: - Data Loading

    func loadData() async {
        guard let familyId else { return }
        isLoading = true

        do {
            familyMembers = try await familyRepo.getFamilyMembers(familyId: familyId)
            let locations = try await locationRepo.getLiveMapState(familyId: familyId)
            for loc in locations {
                latestLocations[loc.trackedUserId] = loc
            }
        } catch {
            alertMessage = "データ取得に失敗しました: \(error.localizedDescription)"
            showAlert = true
        }

        isLoading = false
    }

    // MARK: - Realtime

    func startRealtime() async {
        await stopRealtime()

        let trackedMembers = familyMembers.filter { $0.role == .tracked }
        for member in trackedMembers {
            let userId = member.memberUserId
            let stream = locationRepo.subscribeLocationUpdates(trackedUserId: userId)
            subscriptionTasks[userId] = Task { [weak self] in
                do {
                    for try await location in stream {
                        guard let self, !Task.isCancelled else { return }
                        self.latestLocations[userId] = location

                        let status = self.status(for: member)
                        if status == .stale {
                            let alert = AlertEvent(
                                memberId: userId,
                                type: .locationStale,
                                message: "\(member.displayName)さんの位置情報が更新されていません",
                                severity: 0.5
                            )
                            if !self.hasRecentAlert(type: .locationStale, memberId: userId) {
                                self.alertEvents.insert(alert, at: 0)
                                self.sendNotificationForAlert(alert, personName: member.displayName)
                            }
                        }
                    }
                } catch {}
            }
        }
    }

    func stopRealtime() async {
        for (_, task) in subscriptionTasks {
            task.cancel()
        }
        subscriptionTasks.removeAll()
    }

    // MARK: - Pairing

    func createPairingCode() async throws -> PairingCode {
        guard let familyId else {
            throw AppError.noFamilyId
        }
        return try await pairingRepo.createPairingCode(familyId: familyId)
    }

    func consumePairingCode(_ code: String) async throws -> FamilyMember {
        let member = try await pairingRepo.consumePairingCode(code: code)
        if !familyMembers.contains(where: { $0.memberUserId == member.memberUserId }) {
            familyMembers.insert(member, at: 0)
        }
        return member
    }

    // MARK: - Alerts

    func markAlertAsRead(_ alert: AlertEvent) {
        if let index = alertEvents.firstIndex(where: { $0.id == alert.id }) {
            alertEvents[index].isRead = true
        }
    }

    // MARK: - Private

    private func hasRecentAlert(type: AlertType, memberId: String) -> Bool {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return alertEvents.contains { $0.memberId == memberId && $0.type == type && $0.createdAt > oneHourAgo }
    }

    private func sendNotificationForAlert(_ alert: AlertEvent, personName: String) {
        if let uuid = UUID(uuidString: alert.memberId), quietHoursStore.isInQuietHours(for: uuid) {
            return
        }

        switch alert.type {
        case .locationStale:
            notificationService.sendAlertNotification(
                personName: personName,
                message: alert.message,
                alertId: alert.id
            )
        case .offline:
            notificationService.sendOfflineNotification(personName: personName)
        case .stopDetected:
            notificationService.sendAlertNotification(
                personName: personName,
                message: alert.message,
                alertId: alert.id
            )
        case .unknown:
            break
        }
    }
}

enum AppError: Error, LocalizedError {
    case noFamilyId

    var errorDescription: String? {
        switch self {
        case .noFamilyId: "家族IDが設定されていません"
        }
    }
}
