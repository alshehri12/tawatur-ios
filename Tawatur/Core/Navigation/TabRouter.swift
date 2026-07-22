// TabRouter.swift — shared tab-selection state so a sheet (e.g. the purchase
// wizard presented from HomeView) can switch MainTabView to another tab
// after it finishes, instead of just dismissing back to where it opened.

import SwiftUI
import Combine

final class TabRouter: ObservableObject {
    @Published var selectedTab = 0

    static let home = 0
    static let transactions = 1
    static let certificates = 2
    static let profile = 3
}
