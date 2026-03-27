import Foundation

struct FamilyMember: Codable, Sendable, Identifiable {
    var id: String { "\(familyId)#\(memberUserId)" }
    let familyId: String
    let memberUserId: String
    var displayName: String
    var relationship: Relationship
    var age: Int
    var colorHex: String
    var role: MemberRole
    let joinedAt: Date
    var notes: String

    init(
        familyId: String,
        memberUserId: String,
        displayName: String,
        relationship: Relationship = .other,
        age: Int = 0,
        colorHex: String = "34C759",
        role: MemberRole = .watcher,
        joinedAt: Date = Date(),
        notes: String = ""
    ) {
        self.familyId = familyId
        self.memberUserId = memberUserId
        self.displayName = displayName
        self.relationship = relationship
        self.age = age
        self.colorHex = colorHex
        self.role = role
        self.joinedAt = joinedAt
        self.notes = notes
    }
}
