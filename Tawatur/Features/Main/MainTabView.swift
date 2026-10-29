// MainTabView.swift — Root tabs shown after login + verification.
// The system tab bar is hidden; each tab's root screen shows the floating
// TTabBar (Components.swift) via .tTabRoot(_:).

import SwiftUI

struct MainTabView: View {

    @StateObject private var router = TabRouter()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .toolbar(.hidden, for: .tabBar)
                .tag(TabRouter.home)

            MyTransactionsView()
                .toolbar(.hidden, for: .tabBar)
                .tag(TabRouter.transactions)

            CertificatesListView()
                .toolbar(.hidden, for: .tabBar)
                .tag(TabRouter.certificates)

            ProfileView()
                .toolbar(.hidden, for: .tabBar)
                .tag(TabRouter.profile)
        }
        .tint(.tForest)
        .environmentObject(router)
    }
}
