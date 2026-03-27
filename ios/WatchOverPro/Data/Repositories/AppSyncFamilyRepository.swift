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
                    family_id member_user_id display_name relationship age color_hex role joined_at notes
                }
            }
            """,
            variables: ["family_id": familyId]
        )
        return result.map { $0.toEntity() }
    }

    func updateFamilyMember(_ member: FamilyMember) async throws -> FamilyMember {
        let variables: [String: Any] = [
            "input": [
                "family_id": member.familyId,
                "member_user_id": member.memberUserId,
                "display_name": member.displayName,
                "relationship": member.relationship.rawValue,
                "age": member.age,
                "color_hex": member.colorHex,
                "notes": member.notes,
            ] as [String: Any]
        ]

        let result: GQLFamilyMember = try await dataSource.mutate(
            """
            mutation UpdateFamilyMember($input: UpdateFamilyMemberInput!) {
                updateFamilyMember(input: $input) {
                    family_id member_user_id display_name relationship age color_hex role joined_at notes
                }
            }
            """,
            variables: variables
        )
        return result.toEntity()
    }

    func deleteFamilyMember(familyId: String, memberUserId: String) async throws {
        let _: Bool = try await dataSource.mutate(
            """
            mutation DeleteFamilyMember($family_id: ID!, $member_user_id: ID!) {
                deleteFamilyMember(family_id: $family_id, member_user_id: $member_user_id)
            }
            """,
            variables: ["family_id": familyId, "member_user_id": memberUserId]
        )
    }
}
