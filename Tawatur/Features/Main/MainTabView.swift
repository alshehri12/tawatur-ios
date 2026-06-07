// MainTabView.swift — Root tab bar shown after login + verification.
// Also listens for deep-link tokens stored in AuthState.

import SwiftUI

// Wrapper so String can be used as a sheet item without a retroactive conformance
struct IdentifiableString: Identifiable {
    let id: String
    init(_ value: String) { self.id = value }
}

struct MainTabView: View {

    @EnvironmentObject var authState: AuthState
    @State private var selectedTab = 0
    @State private var pendingApprovalToken: IdentifiableString?

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("الرئيسية", systemImage: "house.fill") }
                .tag(0)

            MyTransactionsView()
                .tabItem { Label("معاملاتي", systemImage: "arrow.left.arrow.right") }
                .tag(1)

            CertificatesListView()
                .tabItem { Label("شهاداتي", systemImage: "checkmark.seal.fill") }
                .tag(2)

            ProfileView()
                .tabItem { Label("حسابي", systemImage: "person.fill") }
                .tag(3)
        }
        .accentColor(.tPrimary)
        // Watch for deep-link transaction tokens set by ContentView
        .onChange(of: authState.pendingTransactionToken) { _, token in
            guard let t = token else { return }
            pendingApprovalToken = IdentifiableString(t)
            authState.pendingTransactionToken = nil
            selectedTab = 1
        }
        .sheet(item: $pendingApprovalToken) { item in
            ApproveTransactionView(linkToken: item.id)
        }
    }
}
