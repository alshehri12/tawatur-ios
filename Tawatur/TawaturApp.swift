// TawaturApp.swift — App entry point
// Removes SwiftData (not needed — all data lives on the backend).
// Injects AuthState as the global environment object and enforces RTL/Arabic.

import SwiftUI

@main
struct TawaturApp: App {

    @StateObject private var authState = AuthState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authState)
                .environment(\.layoutDirection, .rightToLeft)   // Enforce RTL
                .environment(\.locale, Locale(identifier: "ar_SA"))
                .preferredColorScheme(.light)
                .task {
                    // Silently discover backend IP on every launch.
                    // Updates ServerConfig if the LAN IP changed since last run.
                    ServerDiscovery.shared.discoverAndUpdate()
                }
        }
    }
}
