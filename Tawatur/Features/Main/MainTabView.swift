// MainTabView.swift — Root tab bar shown after login + verification.

import SwiftUI

struct MainTabView: View {

    @StateObject private var router = TabRouter()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label("الرئيسية", systemImage: "house.fill") }
                .tag(TabRouter.home)

            MyTransactionsView()
                .tabItem { Label("معاملاتي", systemImage: "checkmark.seal.fill") }
                .tag(TabRouter.transactions)

            CertificatesListView()
                .tabItem { Label("شهاداتي", systemImage: "doc.badge.checkmark") }
                .tag(TabRouter.certificates)

            ProfileView()
                .tabItem { Label("حسابي", systemImage: "person.fill") }
                .tag(TabRouter.profile)
        }
        .accentColor(.tPrimary)
        .environmentObject(router)
    }
}
