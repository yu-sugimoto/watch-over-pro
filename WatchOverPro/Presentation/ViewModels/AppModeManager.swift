import Foundation

@Observable
@MainActor
final class AppModeManager {
    var currentMode: AppMode = .none
    var trackedUserId: String?
    var familyId: String?

    private let modeKey = "app_mode"
    private let trackedUserIdKey = "tracked_user_id"
    private let familyIdKey = "family_id"

    init() {
        if let modeRaw = UserDefaults.standard.string(forKey: modeKey),
           let mode = AppMode(rawValue: modeRaw) {
            currentMode = mode
        }

        trackedUserId = UserDefaults.standard.string(forKey: trackedUserIdKey)
        familyId = UserDefaults.standard.string(forKey: familyIdKey)
    }

    func setMode(_ mode: AppMode) {
        currentMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
    }

    func linkToTrackedUser(id: String, familyId: String) {
        trackedUserId = id
        self.familyId = familyId
        UserDefaults.standard.set(id, forKey: trackedUserIdKey)
        UserDefaults.standard.set(familyId, forKey: familyIdKey)
    }

    func resetAll() {
        currentMode = .none
        trackedUserId = nil
        familyId = nil
        UserDefaults.standard.removeObject(forKey: modeKey)
        UserDefaults.standard.removeObject(forKey: trackedUserIdKey)
        UserDefaults.standard.removeObject(forKey: familyIdKey)
    }
}
