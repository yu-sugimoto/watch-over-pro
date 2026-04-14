import Foundation

@Observable
@MainActor
final class WatchOverViewModel {
    var familyMembers: [FamilyMember] = []
    var latestLocations: [String: CurrentLocation] = [:]
    var showAddPerson = false
    var familyId: String?

    private let locationRepo: any LocationRepositoryProtocol
    private let familyRepo: any FamilyRepositoryProtocol
    private let resolveStatus = ResolvePersonStatusUseCase()

    private var subscriptionTasks: [String: Task<Void, Never>] = [:]

    init(
        locationRepo: any LocationRepositoryProtocol,
        familyRepo: any FamilyRepositoryProtocol
    ) {
        self.locationRepo = locationRepo
        self.familyRepo = familyRepo
    }

    // MARK: - Computed Properties

    var trackedMembers: [FamilyMember] {
        familyMembers.filter { $0.role == .tracked }
    }

    var onlineCount: Int {
        trackedMembers.filter { status(for: $0) == .online }.count
    }

    var offlineCount: Int {
        trackedMembers.filter { status(for: $0) == .offline }.count
    }

    var pausedCount: Int {
        trackedMembers.filter { status(for: $0) == .paused }.count
    }

    func status(for member: FamilyMember) -> PersonStatus {
        let location = latestLocations[member.memberUserId]
        return resolveStatus.execute(lastUpdated: location?.updatedAt, isActive: location?.isActive ?? true)
    }

    // MARK: - Data Loading

    func loadData() async {
        guard let familyId else { return }

        do {
            familyMembers = try await familyRepo.getFamilyMembers(familyId: familyId)
        } catch {
            print("メンバー取得に失敗しました: \(error.localizedDescription)")
        }

        do {
            let locations = try await locationRepo.getLiveMapState(familyId: familyId)
            for loc in locations {
                latestLocations[loc.trackedUserId] = loc
            }
        } catch {
            print("位置情報取得に失敗しました: \(error.localizedDescription)")
        }
    }

    // MARK: - Realtime

    func startRealtime() async {
        await stopRealtime()

        for member in trackedMembers {
            let userId = member.memberUserId
            let stream = locationRepo.subscribeLocationUpdates(trackedUserId: userId)
            subscriptionTasks[userId] = Task { [weak self] in
                do {
                    for try await location in stream {
                        guard let self, !Task.isCancelled else { return }
                        self.latestLocations[userId] = location
                    }
                } catch is CancellationError {
                    // Task cancelled — expected during stopRealtime()
                } catch {
                    print("[WatchOver] Subscription error for \(userId): \(error.localizedDescription)")
                }
            }
        }
    }

    func stopRealtime() async {
        for (_, task) in subscriptionTasks {
            task.cancel()
        }
        subscriptionTasks.removeAll()
    }

    // MARK: - Member Management

    func updateMember(_ member: FamilyMember) async throws {
        let updated = try await familyRepo.updateFamilyMember(member)
        if let index = familyMembers.firstIndex(where: { $0.memberUserId == updated.memberUserId }) {
            familyMembers[index] = updated
        }
    }

    func deleteMember(_ member: FamilyMember) async throws {
        guard let familyId else { throw AppError.noFamilyId }
        try await familyRepo.deleteFamilyMember(familyId: familyId, memberUserId: member.memberUserId)
        familyMembers.removeAll { $0.memberUserId == member.memberUserId }
        latestLocations.removeValue(forKey: member.memberUserId)
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
