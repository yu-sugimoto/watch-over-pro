import Foundation

struct PairingCode: Codable, Sendable {
    let code: String
    let familyId: String
    let expiresAt: Date
    var isUsed: Bool

    init(
        code: String,
        familyId: String,
        expiresAt: Date = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date().addingTimeInterval(86400),
        isUsed: Bool = false
    ) {
        self.code = code
        self.familyId = familyId
        self.expiresAt = expiresAt
        self.isUsed = isUsed
    }
}
