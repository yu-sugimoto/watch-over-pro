import Foundation

final class AppSyncPairingRepository: PairingRepositoryProtocol, Sendable {
    private let dataSource = AppSyncDataSource.shared

    func createPairingCode(familyId: String) async throws -> PairingCode {
        let result: GQLPairingCode = try await dataSource.mutate(
            """
            mutation CreatePairingCode($family_id: ID!) {
                createPairingCode(family_id: $family_id) {
                    code family_id expires_at is_used
                }
            }
            """,
            variables: ["family_id": familyId]
        )
        return result.toEntity()
    }

    func consumePairingCode(code: String) async throws -> FamilyMember {
        let result: GQLFamilyMember = try await dataSource.mutate(
            """
            mutation ConsumePairingCode($code: String!) {
                consumePairingCode(code: $code) {
                    family_id member_user_id display_name relationship age color_hex role joined_at
                }
            }
            """,
            variables: ["code": code]
        )
        return result.toEntity()
    }
}
