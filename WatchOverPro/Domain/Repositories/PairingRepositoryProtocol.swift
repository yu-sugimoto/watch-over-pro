import Foundation

protocol PairingRepositoryProtocol: Sendable {
    func createPairingCode(familyId: String) async throws -> PairingCode
    func consumePairingCode(
        code: String,
        displayName: String?,
        relationship: String?,
        age: Int?,
        colorHex: String?
    ) async throws -> FamilyMember
}
