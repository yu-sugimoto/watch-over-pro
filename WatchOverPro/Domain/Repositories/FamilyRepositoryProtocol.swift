import Foundation

protocol FamilyRepositoryProtocol: Sendable {
    func getFamilyMembers(familyId: String) async throws -> [FamilyMember]
    func updateFamilyMember(_ member: FamilyMember) async throws -> FamilyMember
    func deleteFamilyMember(familyId: String, memberUserId: String) async throws
}
