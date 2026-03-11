import Foundation

final class AppSyncFamilyRepository: FamilyRepositoryProtocol, Sendable {
    private let dataSource = AppSyncDataSource.shared

    func getFamily(familyId: String) async throws -> Family? {
        let result: GQLFamily? = try await dataSource.query(
            """
            query GetFamily($family_id: ID!) {
                getFamily(family_id: $family_id) {
                    family_id name plan_status plan_expires_at created_at
                }
            }
            """,
            variables: ["family_id": familyId]
        )
        return result?.toEntity()
    }

    func getFamilyMembers(familyId: String) async throws -> [FamilyMember] {
        let result: [GQLFamilyMember] = try await dataSource.query(
            """
            query GetFamilyMembers($family_id: ID!) {
                getFamilyMembers(family_id: $family_id) {
                    family_id member_user_id display_name relationship age color_hex role joined_at
                }
            }
            """,
            variables: ["family_id": familyId]
        )
        return result.map { $0.toEntity() }
    }
}
