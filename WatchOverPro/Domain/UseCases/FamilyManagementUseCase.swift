import Foundation

struct FamilyManagementUseCase: Sendable {
    private let repository: any FamilyRepositoryProtocol

    init(repository: any FamilyRepositoryProtocol) {
        self.repository = repository
    }

    func getFamily(familyId: String) async throws -> Family? {
        try await repository.getFamily(familyId: familyId)
    }

    func getMembers(familyId: String) async throws -> [FamilyMember] {
        try await repository.getFamilyMembers(familyId: familyId)
    }
}
