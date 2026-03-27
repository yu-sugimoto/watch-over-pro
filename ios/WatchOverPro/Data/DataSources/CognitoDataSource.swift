import Foundation
import AuthenticationServices
import Amplify
import AWSCognitoAuthPlugin

final class CognitoDataSource: NSObject, @unchecked Sendable {
    static let shared = CognitoDataSource()

    private override init() {
        super.init()
    }

    // MARK: - Apple Sign In + Cognito Custom Auth

    func signInWithApple() async throws {
        let credential = try await performAppleSignIn()

        guard let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            throw CognitoError.signInFailed("Apple identity token not found")
        }

        let userId = credential.user
        let email = credential.email // Only available on first sign-in

        // 1. Sign up first (succeeds on first time, UsernameExists on subsequent)
        do {
            var userAttributes: [AuthUserAttribute] = []
            if let email = email {
                userAttributes.append(AuthUserAttribute(.email, value: email))
            }
            _ = try await Amplify.Auth.signUp(
                username: userId,
                password: UUID().uuidString + "Aa1!",
                options: .init(userAttributes: userAttributes)
            )
        } catch let error as AuthError {
            // UsernameExists is expected for returning users — ignore it.
            // For any other error, still attempt signIn (user may already exist).
            let desc = error.underlyingError?.localizedDescription ?? error.localizedDescription
            if !desc.contains("UsernameExistsException") && !desc.contains("already exists") {
                print("[CognitoDataSource] signUp warning (will attempt signIn): \(desc)")
            }
        }

        // 2. Initiate Custom Auth flow with Apple user ID as username
        let options = AWSAuthSignInOptions(authFlowType: .customWithoutSRP)
        let result = try await Amplify.Auth.signIn(
            username: userId,
            options: .init(pluginOptions: options)
        )

        // 3. Respond to the custom challenge with the Apple identity token
        if case .confirmSignInWithCustomChallenge = result.nextStep {
            let confirmResult = try await Amplify.Auth.confirmSignIn(
                challengeResponse: token
            )
            guard confirmResult.isSignedIn else {
                throw CognitoError.signInFailed("Challenge verification failed")
            }
        } else if !result.isSignedIn {
            throw CognitoError.signInFailed("Unexpected sign-in state: \(result.nextStep)")
        }
    }

    func signOut() async throws {
        _ = await Amplify.Auth.signOut()
    }

    func fetchCurrentSession() async throws -> (isSignedIn: Bool, userId: String?) {
        let session = try await Amplify.Auth.fetchAuthSession()
        let userId = try? await Amplify.Auth.getCurrentUser().userId
        return (session.isSignedIn, userId)
    }

    func getCurrentUserId() async -> String? {
        try? await Amplify.Auth.getCurrentUser().userId
    }

    // MARK: - ASAuthorization (Native Apple Sign In UI)

    @MainActor
    private func performAppleSignIn() async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email, .fullName]

            let delegate = AppleSignInDelegate(continuation: continuation)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate

            // Keep delegate alive until completion
            objc_setAssociatedObject(
                controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN
            )

            controller.performRequests()
        }
    }
}

// MARK: - ASAuthorizationController Delegate

private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation.resume(returning: credential)
        } else {
            continuation.resume(throwing: CognitoError.signInFailed("Invalid credential type"))
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation.resume(throwing: error)
    }
}

// MARK: - Errors

enum CognitoError: Error, LocalizedError {
    case signInFailed(String)

    var errorDescription: String? {
        switch self {
        case .signInFailed(let msg): "Sign in failed: \(msg)"
        }
    }
}
