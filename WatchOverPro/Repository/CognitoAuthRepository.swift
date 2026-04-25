import Foundation

final class CognitoAuthRepository: AuthRepositoryProtocol, Sendable {
    private let dataSource = CognitoDataSource.shared

    var isAuthenticated: Bool {
        get async {
            await dataSource.validateSession()
        }
    }

    var currentUserId: String? {
        get async {
            await dataSource.getCurrentUserId()
        }
    }

    func signInWithApple() async throws {
        try await dataSource.signInWithApple()
    }

    func signOut() async throws {
        try await dataSource.signOut()
    }

    func checkSession() async throws -> Bool {
        let session = try await dataSource.fetchCurrentSession()
        return session.isSignedIn
    }
}
