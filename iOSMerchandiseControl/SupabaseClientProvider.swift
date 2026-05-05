import Foundation
import Supabase

nonisolated enum SupabaseOAuthRedirect {
    static let scheme = "com.niwcyber.iosmerchandisecontrol"
    static let url = URL(string: "\(scheme)://login-callback")!
}

final class SupabaseClientProvider: @unchecked Sendable {
    let config: SupabaseConfig
    let redirectURL: URL
    let client: SupabaseClient

    init(config: SupabaseConfig, redirectURL: URL = SupabaseOAuthRedirect.url) {
        self.config = config
        self.redirectURL = redirectURL
        self.client = SupabaseClient(
            supabaseURL: config.projectURL,
            supabaseKey: config.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: redirectURL,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
