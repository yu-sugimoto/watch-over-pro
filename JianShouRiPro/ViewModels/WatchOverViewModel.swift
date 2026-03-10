import Foundation

@Observable
@MainActor
final class WatchOverViewModel {
    var persons: [WatchPerson] = []
    var alertEvents: [AlertEvent] = []
    var isLoading = false
    var selectedPerson: WatchPerson?
    var showAddPerson = false
    var showAlert = false
    var alertMessage = ""
    var deviceId: String = ""
    var isRealtimeConnected: Bool { realtimeManager.isConnected }

    let inactivityMonitor = InactivityMonitor()

    private let auth = AuthService.shared
    private let personRepo = PersonRepository.shared
    private let alertRepo = AlertRepository.shared
    private let gaitDataRepo = GaitDataRepository.shared
    private let pairingRepo = PairingRepository.shared
    private let quietHoursStore = QuietHoursStore.shared
    private let notificationService = NotificationService.shared
    private let realtimeManager = RealtimeManager()
    private var linkedPersonIds: Set<UUID> = []

    var inactivityStatuses: [UUID: InactivityStatus] {
        inactivityMonitor.statuses
    }

    var unreadAlertCount: Int {
        alertEvents.filter { !$0.isRead }.count
    }

    var safePersonCount: Int {
        persons.filter { $0.status == .safe }.count
    }

    var warningPersonCount: Int {
        persons.filter { $0.status == .warning }.count
    }

    var alertPersonCount: Int {
        persons.filter { $0.status == .alert }.count
    }

    var inactivityAlertCount: Int {
        inactivityMonitor.warningOrCriticalCount
    }

    func loadData() async {
        isLoading = true
        let authOk = await auth.reauthenticateIfNeeded()
        guard authOk else {
            isLoading = false
            return
        }
        if deviceId.isEmpty {
            persons = []
            alertEvents = []
        } else {
            persons = await personRepo.fetchAll(forWatcherDeviceId: deviceId)
            linkedPersonIds = Set(persons.map { $0.id })
            var allAlerts: [AlertEvent] = []
            for personId in linkedPersonIds {
                let personAlerts = await alertRepo.fetch(for: personId)
                allAlerts.append(contentsOf: personAlerts)
            }
            alertEvents = allAlerts.sorted { $0.createdAt > $1.createdAt }
        }
        await checkInactivity()
        isLoading = false
    }

    func startRealtime() async {
        await stopRealtime()
        guard !deviceId.isEmpty else { return }

        realtimeManager.handlers = RealtimeManager.Handlers(
            onPersonInserted: { [weak self] person in
                guard let self else { return }
                if !self.persons.contains(where: { $0.id == person.id }) {
                    self.persons.insert(person, at: 0)
                }
            },
            onPersonUpdated: { [weak self] updated in
                guard let self else { return }
                if let index = self.persons.firstIndex(where: { $0.id == updated.id }) {
                    self.persons[index] = updated
                }
            },
            onPersonDeleted: { [weak self] id in
                guard let self else { return }
                self.persons.removeAll { $0.id == id }
                self.linkedPersonIds.remove(id)
            },
            onAlertInserted: { [weak self] alert in
                guard let self else { return }
                if !self.alertEvents.contains(where: { $0.id == alert.id }) {
                    self.alertEvents.insert(alert, at: 0)
                    self.sendNotificationForAlert(alert)
                }
            },
            onRemoteDataInserted: { [weak self] in
                await self?.checkInactivity()
            }
        )

        await realtimeManager.start(linkedPersonIds: linkedPersonIds)
        inactivityMonitor.startOfflineCheck { [weak self] in
            guard let self else { return }
            self.persons = self.inactivityMonitor.evaluateOfflineStatus(persons: self.persons)
        }
    }

    func stopRealtime() async {
        await realtimeManager.stop()
        inactivityMonitor.stopOfflineCheck()
    }

    func addPerson(_ person: WatchPerson) async {
        persons.insert(person, at: 0)
        linkedPersonIds.insert(person.id)
        await personRepo.save(person)
        if !deviceId.isEmpty {
            await pairingRepo.createWatcherLink(
                personId: person.id,
                watcherDeviceId: deviceId
            )
        }
    }

    func deletePerson(_ person: WatchPerson) async {
        persons.removeAll { $0.id == person.id }
        linkedPersonIds.remove(person.id)
        inactivityMonitor.statuses.removeValue(forKey: person.id)
        await pairingRepo.deleteDeviceLinkForWatcher(personId: person.id, watcherDeviceId: deviceId)
    }

    func updatePerson(_ person: WatchPerson) async {
        if let index = persons.firstIndex(where: { $0.id == person.id }) {
            persons[index].name = person.name
            persons[index].relationship = person.relationship
            persons[index].age = person.age
            persons[index].notes = person.notes
            persons[index].colorHex = person.colorHex
        }
        await personRepo.updateInfo(
            person.id,
            name: person.name,
            relationship: person.relationship,
            age: person.age,
            colorHex: person.colorHex,
            notes: person.notes
        )
    }

    func syncPersonStatus(personId: UUID, steps: Int, anomalyCount: Int, riskLevel: GaitRiskLevel, steadiness: Double?) async {
        let inactivity = inactivityMonitor.statuses[personId]?.level ?? .active
        let status = StatusResolver.resolve(gaitRisk: riskLevel, inactivity: inactivity)

        if let index = persons.firstIndex(where: { $0.id == personId }) {
            persons[index].status = status
            persons[index].todaySteps = steps
            persons[index].todayAnomalyCount = anomalyCount
            persons[index].lastActivity = Date()
            persons[index].walkingSteadiness = steadiness
            persons[index].lastRiskLevel = riskLevel.rawValue
        }

        try? await personRepo.updateStatus(personId, status: status, steps: steps, anomalyCount: anomalyCount, riskLevel: riskLevel.rawValue, steadiness: steadiness)

        if riskLevel == .high {
            let personName = {
                let n = persons.first(where: { $0.id == personId })?.name ?? ""
                return n.isEmpty ? "不明" : n
            }()
            let alert = AlertEvent(
                personId: personId,
                type: .gaitAnomaly,
                message: "\(personName)さんの歩行に異常が検出されました。リスクレベル: 高",
                severity: 0.8
            )
            alertEvents.insert(alert, at: 0)
            await alertRepo.save(alert)
            sendNotificationForAlert(alert)
        }
    }

    func saveGaitSession(_ session: GaitSession, for personId: UUID) async {
        await gaitDataRepo.saveSession(session, personId: personId)
    }

    func markAlertAsRead(_ alert: AlertEvent) async {
        if let index = alertEvents.firstIndex(where: { $0.id == alert.id }) {
            alertEvents[index].isRead = true
        }
        await alertRepo.markAsRead(alert.id)
    }

    func alertsForPerson(_ personId: UUID) -> [AlertEvent] {
        alertEvents.filter { $0.personId == personId }
    }

    func isInQuietHours(for personId: UUID) -> Bool {
        quietHoursStore.isInQuietHours(for: personId)
    }

    func activeQuietPeriod(for personId: UUID) -> QuietHoursPeriod? {
        quietHoursStore.activeQuietPeriod(for: personId)
    }

    func checkInactivity() async {
        let result = await inactivityMonitor.checkAll(persons: persons)
        persons = result.updatedPersons
        let results = result.alerts

        for result in results {
            guard !hasRecentInactivityAlert(for: result.personId) else { continue }

            if result.inactivity.level == .critical {
                let alert = AlertEvent(
                    personId: result.personId,
                    type: .inactivity,
                    message: "\(result.personName)さんの活動が\(result.inactivity.durationText)確認できません",
                    severity: 0.9
                )
                alertEvents.insert(alert, at: 0)
                await alertRepo.save(alert)
                notificationService.sendUrgentAlertNotification(
                    personName: result.personName,
                    message: alert.message,
                    alertId: alert.id
                )
            } else if result.inactivity.level == .warning {
                let alert = AlertEvent(
                    personId: result.personId,
                    type: .inactivity,
                    message: "\(result.personName)さんが\(result.inactivity.durationText)非活動状態です",
                    severity: 0.5
                )
                alertEvents.insert(alert, at: 0)
                await alertRepo.save(alert)
                notificationService.sendInactivityNotification(
                    personName: result.personName,
                    duration: result.inactivity.durationText,
                    alertId: alert.id
                )
            }
        }
    }

    private func hasRecentInactivityAlert(for personId: UUID) -> Bool {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return alertEvents.contains { $0.personId == personId && $0.type == .inactivity && $0.createdAt > oneHourAgo }
    }

    private func sendNotificationForAlert(_ alert: AlertEvent) {
        if alert.type == .inactivity && quietHoursStore.isInQuietHours(for: alert.personId) {
            return
        }

        let personName = {
            let n = persons.first(where: { $0.id == alert.personId })?.name ?? ""
            return n.isEmpty ? "不明" : n
        }()

        switch alert.type {
        case .gaitAnomaly:
            if alert.severity >= 0.7 {
                notificationService.sendUrgentAlertNotification(
                    personName: personName,
                    message: alert.message,
                    alertId: alert.id
                )
            } else {
                notificationService.sendAlertNotification(
                    personName: personName,
                    message: alert.message,
                    alertId: alert.id
                )
            }
        case .inactivity:
            notificationService.sendInactivityNotification(
                personName: personName,
                duration: "",
                alertId: alert.id
            )
        case .offline, .unknown:
            notificationService.sendAlertNotification(
                personName: personName,
                message: alert.message,
                alertId: alert.id
            )
        }
    }
}
