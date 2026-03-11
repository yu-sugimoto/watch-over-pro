import Foundation

struct PairingUseCase: Sendable {
    private let repository: any PairingRepositoryProtocol

    init(repository: any PairingRepositoryProtocol) {
        self.repository = repository
    }

    func createCode(familyId: String) async throws -> PairingCode {
        try await repository.createPairingCode(familyId: familyId)
    }

    func consumeCode(_ code: String) async throws -> FamilyMember {
        try await repository.consumePairingCode(code: code)
    }
}
