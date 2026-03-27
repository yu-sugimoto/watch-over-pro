import Foundation

protocol AuthRepositoryProtocol: Sendable {
    var isAuthenticated: Bool { get async }
    var currentUserId: String? { get async }
    func signInWithApple() async throws
    func signOut() async throws
    func checkSession() async throws -> Bool
}
