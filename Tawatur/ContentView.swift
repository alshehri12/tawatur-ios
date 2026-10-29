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
// Same logo, size and position as the system launch screen (UILaunchScreen in
// Info.plist), plus a small gold loading bar. Design: "شاشة البداية".

struct SplashView: View {
    @State private var slide = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Image("TawaturLogo")
                .accessibilityLabel("تواتر — توثيق الآن، ثقة تدوم")
                .offset(y: -7)
            Capsule()
                .fill(Color.tBorder)
                .frame(width: 36, height: 4)
                .overlay(alignment: .leading) {
                    Capsule().fill(Color.tGold)
                        .frame(width: 14, height: 4)
                        .offset(x: slide ? 22 : 0)
                }
                .clipShape(Capsule())
                .environment(\.layoutDirection, .leftToRight)
                .offset(y: 111 + 41)   // half the logo height + gap, below the logo
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { slide = true }
        }
    }
}
