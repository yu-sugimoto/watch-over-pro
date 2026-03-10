import Foundation
import Supabase
import Auth

@Observable
@MainActor
final class AuthService {
    static let shared = AuthService()

    var isAuthenticated = false
    var errorMessage: String?

    let client: SupabaseClient

    var currentUserId: String? {
        try? client.auth.currentSession?.user.id.uuidString
    }

    private init() {
        let urlString = Config.SUPABASE_URL.isEmpty ? "https://placeholder.supabase.co" : Config.SUPABASE_URL
        let url = URL(string: urlString) ?? URL(string: "https://placeholder.supabase.co")!
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Config.SUPABASE_ANON_KEY
        )
    }

    func ensureAuthenticated() async {
        do {
            let session = try await client.auth.session
            if session.isExpired {
                try await client.auth.refreshSession()
            }
            isAuthenticated = true
        } catch {
            do {
                try await client.auth.refreshSession()
                isAuthenticated = true
            } catch {
                do {
                    try await client.auth.signInAnonymously()
                    isAuthenticated = true
                } catch {
                    isAuthenticated = false
                    errorMessage = "認証エラー: \(error.localizedDescription)"
                }
            }
        }
    }

    func reauthenticateIfNeeded() async -> Bool {
        if isAuthenticated, currentUserId != nil {
            do {
                let session = try await client.auth.session
                if !session.isExpired {
                    return true
                }
                try await client.auth.refreshSession()
                isAuthenticated = true
                return true
            } catch {}
        }
        await ensureAuthenticated()
        return isAuthenticated
    }

    func removeChannel(_ channel: RealtimeChannelV2) async {
        await client.realtimeV2.removeChannel(channel)
    }
}
