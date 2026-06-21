// MainTabView.swift — Root tab bar shown after login + verification.

import SwiftUI

struct MainTabView: View {

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("الرئيسية", systemImage: "house.fill") }
                .tag(0)

            MyTransactionsView()
                .tabItem { Label("معاملاتي", systemImage: "checkmark.seal.fill") }
                .tag(1)

            CertificatesListView()
                .tabItem { Label("شهاداتي", systemImage: "doc.badge.checkmark") }
                .tag(2)

            ProfileView()
                .tabItem { Label("حسابي", systemImage: "person.fill") }
                .tag(3)
        }
        .accentColor(.tPrimary)
    }
}
