import Foundation

protocol PairingRepositoryProtocol: Sendable {
    func createPairingCode(familyId: String) async throws -> PairingCode
    func consumePairingCode(code: String) async throws -> FamilyMember
}
