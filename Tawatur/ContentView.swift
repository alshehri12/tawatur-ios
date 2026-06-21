// ContentView.swift — Root navigator
// Watches AuthState and routes to the correct screen based on auth + verification status.
// Also handles deep links: tawatur://transaction/{token}

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var authState: AuthState

    var body: some View {
        Group {
            switch authState.status {
            case .loading:
                SplashView()

            case .unauthenticated:
                OnboardingView()

            case .authenticated:
                // If verified → go to main app.  If not → verification gate.
                if authState.user?.canTransact == true {
                    MainTabView()
                } else {
                    VerificationGateView()
                }
            }
        }
    }
}

// ── Splash (shown while AuthState checks stored token) ────────────────────────

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.tBackground.ignoresSafeArea()
            VStack(spacing: 8) {
                Text("تواتر")
                    .font(.tTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.tPrimary)
                Text("منصة توثيق الملكية الموثوقة")
                    .font(.tCaption)
                    .foregroundColor(.tSubtext)
                ProgressView()
                    .tint(.tPrimary)
                    .padding(.top, 24)
            }
        }
    }
}
