import Foundation

@Observable
@MainActor
final class InactivityMonitor {
    var statuses: [UUID: InactivityStatus] = [:]

    private let gaitDataRepo = GaitDataRepository.shared
    private let quietHoursStore = QuietHoursStore.shared
    private var offlineCheckTimer: Timer?
    private let offlineThreshold: TimeInterval = 10 * 60

    var warningOrCriticalCount: Int {
        statuses.values.filter { $0.level == .warning || $0.level == .critical }.count
    }

    func evaluateOfflineStatus(persons: [WatchPerson]) -> [WatchPerson] {
        let now = Date()
        var updated = persons
        for i in updated.indices {
            let person = updated[i]
            guard let lastActivity = person.lastActivity else {
                if person.status != .offline {
                    updated[i].status = .offline
                }
                continue
            }
            if now.timeIntervalSince(lastActivity) > offlineThreshold {
                if person.status != .offline {
                    updated[i].status = .offline
                }
            } else if person.status == .offline {
                let gaitRisk = GaitRiskLevel(rawValue: updated[i].lastRiskLevel) ?? .normal
                let inactivity = statuses[person.id]?.level ?? .active
                updated[i].status = StatusResolver.resolve(gaitRisk: gaitRisk, inactivity: inactivity)
            }
        }
        return updated
    }

    func startOfflineCheck(evaluate: @escaping @MainActor () -> Void) {
        offlineCheckTimer?.invalidate()
        offlineCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                evaluate()
            }
        }
        evaluate()
    }

    func stopOfflineCheck() {
        offlineCheckTimer?.invalidate()
        offlineCheckTimer = nil
    }

    struct InactivityResult {
        let personId: UUID
        let personName: String
        let inactivity: InactivityStatus
    }

    struct CheckAllResult {
        let updatedPersons: [WatchPerson]
        let alerts: [InactivityResult]
    }

    func checkAll(persons: [WatchPerson]) async -> CheckAllResult {
        var updated = persons
        var alerts: [InactivityResult] = []

        for person in persons {
            guard !Task.isCancelled else { break }

            if quietHoursStore.isInQuietHours(for: person.id) {
                statuses[person.id] = InactivityStatus(
                    level: .active,
                    lastActiveTime: nil,
                    lastDataTime: nil,
                    inactiveDuration: 0
                )
                if let index = updated.firstIndex(where: { $0.id == person.id }) {
                    let gaitRisk = GaitRiskLevel(rawValue: updated[index].lastRiskLevel) ?? .normal
                    updated[index].status = StatusResolver.resolve(gaitRisk: gaitRisk, inactivity: .active)
                }
                continue
            }

            let lastActive = await gaitDataRepo.fetchLastActive(for: person.id)
            let lastData = await gaitDataRepo.fetchLatest(for: person.id)

            guard !Task.isCancelled else { break }

            let inactivity = InactivityStatus.evaluate(
                lastActiveTime: lastActive?.timestamp,
                lastDataTime: lastData?.timestamp,
                isCurrentlyWalking: lastData?.isWalking ?? false
            )
            statuses[person.id] = inactivity

            if let index = updated.firstIndex(where: { $0.id == person.id }) {
                let gaitRisk = GaitRiskLevel(rawValue: updated[index].lastRiskLevel) ?? .normal
                updated[index].status = StatusResolver.resolve(gaitRisk: gaitRisk, inactivity: inactivity.level)
            }

            if inactivity.level == .critical || inactivity.level == .warning {
                let displayName = person.name.isEmpty ? "不明" : person.name
                alerts.append(InactivityResult(
                    personId: person.id,
                    personName: displayName,
                    inactivity: inactivity
                ))
            }
        }
        return CheckAllResult(updatedPersons: updated, alerts: alerts)
    }
}
