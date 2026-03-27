import Foundation

struct Family: Codable, Sendable, Identifiable {
    var id: String { familyId }
    let familyId: String
    var name: String
    var planStatus: String
    var planExpiresAt: Date?
    let createdAt: Date

    init(
        familyId: String,
        name: String = "",
        planStatus: String = "free",
        planExpiresAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.familyId = familyId
        self.name = name
        self.planStatus = planStatus
        self.planExpiresAt = planExpiresAt
        self.createdAt = createdAt
    }
}
