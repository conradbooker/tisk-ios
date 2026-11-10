import AuthenticationServices
import Foundation
import Observation
import Supabase

@Observable
final class AuthStore {
    enum State {
        case loading
        case signedOut
        case signedIn(email: String?)
    }

    private(set) var state: State = .loading
    var errorMessage: String?
    var infoMessage: String?
    private(set) var isWorking = false

    private var client: SupabaseClient { SupabaseService.client }
    private var listener: Task<Void, Never>?

    init() {
        listener = Task { [weak self] in
            guard let client = self?.client else { return }
            for await (_, session) in client.auth.authStateChanges {
                guard let self else { return }
                if let session {
                    self.state = .signedIn(email: session.user.email)
                } else {
                    self.state = .signedOut
                }
            }
        }
    }

    deinit {
        listener?.cancel()
    }

    func signIn(email: String, password: String) async {
        await perform {
            try await self.client.auth.signIn(email: email, password: password)
        }
    }

    func signUp(email: String, password: String) async {
        await perform {
            let response = try await self.client.auth.signUp(email: email, password: password)
            if response.session == nil {
                self.infoMessage = "Check your email to confirm your account, then sign in."
            }
        }
    }

    /// Opens Google sign-in in a system web authentication session. The redirect
    /// URL must be listed under Authentication > URL Configuration in Supabase.
    func signInWithGoogle() async {
        errorMessage = nil
        infoMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: Self.redirectURL
            )
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // User dismissed the sheet; not an error.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static let redirectURL = URL(string: "tisk-ios://auth-callback")!

    func signOut() async {
        await perform {
            try await self.client.auth.signOut()
        }
    }

    private func perform(_ work: () async throws -> some Any) async {
        errorMessage = nil
        infoMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await work()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
