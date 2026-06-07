// AuthState.swift — Global authentication state shared across the entire app.
// Injected as @EnvironmentObject from TawaturApp.

import Foundation
import Combine

enum AuthStatus: Equatable {
    case loading
    case unauthenticated
    case authenticated
}

final class AuthState: ObservableObject {

    @Published var status: AuthStatus = .loading
    @Published var user: UserProfile?
    @Published var pendingTransactionToken: String?

    init() {
        Task { @MainActor in await self.checkStoredToken() }
    }

    @MainActor
    func checkStoredToken() async {
        guard TokenManager.shared.accessToken != nil else {
            status = .unauthenticated
            return
        }
        do {
            let profile = try await APIClient.shared.request(.me, as: UserProfile.self)
            user   = profile
            status = .authenticated
        } catch {
            TokenManager.shared.clear()
            status = .unauthenticated
        }
    }

    // Called from @MainActor context (AuthViewModel methods are @MainActor)
    func handleAuthResponse(_ response: AuthResponse) {
        TokenManager.shared.save(access: response.access, refresh: response.refresh)
        user   = response.user
        status = .authenticated
    }

    @MainActor
    func logout() async {
        if let refresh = TokenManager.shared.refreshToken {
            try? await APIClient.shared.requestEmpty(.logout(refresh: refresh))
        }
        TokenManager.shared.clear()
        user   = nil
        status = .unauthenticated
    }

    @MainActor
    func refreshProfile() async {
        guard status == .authenticated else { return }
        if let profile = try? await APIClient.shared.request(.me, as: UserProfile.self) {
            user = profile
        }
    }
}
