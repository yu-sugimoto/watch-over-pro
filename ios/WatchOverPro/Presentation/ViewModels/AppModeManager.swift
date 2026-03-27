import Foundation

@Observable
@MainActor
final class AppModeManager {
    var currentMode: AppMode = .none
    var trackedUserId: String?
    var trackedUserName: String = ""
    var familyId: String?
    var deviceId: String

    private let modeKey = "app_mode"
    private let trackedUserIdKey = "tracked_user_id"
    private let trackedUserNameKey = "tracked_user_name"
    private let familyIdKey = "family_id"
    private let deviceIdKey = "device_id"

    init() {
        if let savedDeviceId = UserDefaults.standard.string(forKey: deviceIdKey) {
            deviceId = savedDeviceId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: deviceIdKey)
            deviceId = newId
        }

        if let modeRaw = UserDefaults.standard.string(forKey: modeKey),
           let mode = AppMode(rawValue: modeRaw) {
            currentMode = mode
        }

        trackedUserId = UserDefaults.standard.string(forKey: trackedUserIdKey)
        trackedUserName = UserDefaults.standard.string(forKey: trackedUserNameKey) ?? ""
        familyId = UserDefaults.standard.string(forKey: familyIdKey)
    }

    func setMode(_ mode: AppMode) {
        currentMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
    }

    func linkToTrackedUser(id: String, name: String, familyId: String) {
        trackedUserId = id
        trackedUserName = name
        self.familyId = familyId
        UserDefaults.standard.set(id, forKey: trackedUserIdKey)
        UserDefaults.standard.set(name, forKey: trackedUserNameKey)
        UserDefaults.standard.set(familyId, forKey: familyIdKey)
    }

    func resetAll() {
        currentMode = .none
        trackedUserId = nil
        trackedUserName = ""
        familyId = nil
        UserDefaults.standard.removeObject(forKey: modeKey)
        UserDefaults.standard.removeObject(forKey: trackedUserIdKey)
        UserDefaults.standard.removeObject(forKey: trackedUserNameKey)
        UserDefaults.standard.removeObject(forKey: familyIdKey)
    }
}
