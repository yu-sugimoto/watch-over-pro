import Foundation

struct PairingUseCase: Sendable {
    private let repository: any PairingRepositoryProtocol

    init(repository: any PairingRepositoryProtocol) {
        self.repository = repository
    }

    func createCode(familyId: String) async throws -> PairingCode {
        try await repository.createPairingCode(familyId: familyId)
    }

    func consumeCode(
        _ code: String,
        displayName: String? = nil,
        relationship: String? = nil,
        age: Int? = nil,
        colorHex: String? = nil
    ) async throws -> FamilyMember {
        try await repository.consumePairingCode(
            code: code,
            displayName: displayName,
            relationship: relationship,
            age: age,
            colorHex: colorHex
        )
    }
}
