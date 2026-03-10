import Foundation

@Observable
@MainActor
final class AppModeManager {
    var currentMode: AppMode = .none
    var linkedPersonId: UUID?
    var linkedPersonName: String = ""
    var deviceId: String

    private let modeKey = "app_mode"
    private let personIdKey = "linked_person_id"
    private let personNameKey = "linked_person_name"
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

        if let personIdStr = UserDefaults.standard.string(forKey: personIdKey),
           let personId = UUID(uuidString: personIdStr) {
            linkedPersonId = personId
        }

        linkedPersonName = UserDefaults.standard.string(forKey: personNameKey) ?? ""
    }

    func setMode(_ mode: AppMode) {
        currentMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
    }

    func linkToPerson(id: UUID, name: String) {
        linkedPersonId = id
        linkedPersonName = name
        UserDefaults.standard.set(id.uuidString, forKey: personIdKey)
        UserDefaults.standard.set(name, forKey: personNameKey)
    }

    func resetAll() {
        currentMode = .none
        linkedPersonId = nil
        linkedPersonName = ""
        UserDefaults.standard.removeObject(forKey: modeKey)
        UserDefaults.standard.removeObject(forKey: personIdKey)
        UserDefaults.standard.removeObject(forKey: personNameKey)
    }
}
