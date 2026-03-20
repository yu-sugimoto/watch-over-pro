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

    func consumePairingCode(
        code: String,
        displayName: String?,
        relationship: String?,
        age: Int?,
        colorHex: String?,
        notes: String?
    ) async throws -> FamilyMember {
        var variables: [String: Any] = ["code": code]
        if let displayName { variables["display_name"] = displayName }
        if let relationship { variables["relationship"] = relationship }
        if let age { variables["age"] = age }
        if let colorHex { variables["color_hex"] = colorHex }
        if let notes { variables["notes"] = notes }

        let result: GQLFamilyMember = try await dataSource.mutate(
            """
            mutation ConsumePairingCode($code: String!, $display_name: String, $relationship: String, $age: Int, $color_hex: String, $notes: String) {
                consumePairingCode(code: $code, display_name: $display_name, relationship: $relationship, age: $age, color_hex: $color_hex, notes: $notes) {
                    family_id member_user_id display_name relationship age color_hex role joined_at notes
                }
            }
            """,
            variables: variables
        )
        return result.toEntity()
    }
}
