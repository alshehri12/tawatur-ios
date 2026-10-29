// HomeSampleData.swift — Sample data for Xcode previews of the home screen.
// Mirrors the content of "الرئيسية" in UIDesign/gallery.html. Debug builds only.

#if DEBUG
import SwiftUI

extension HomeViewModel {
    static var sample: HomeViewModel {
        let vm = HomeViewModel()
        let now = Date()
        func txn(_ id: String, _ brand: String, _ model: String, _ category: String,
                 status: String, role: String, name: String, price: Double,
                 created: TimeInterval, approved: TimeInterval? = nil, expiresIn: TimeInterval = 0) -> Transaction {
            Transaction(id: id, transactionType: "direct_purchase", transactionTypeDisplay: "شراء مباشر",
                        status: status, statusDisplay: "", price: price, deviceCondition: "used",
                        createdAt: now.addingTimeInterval(created),
                        expiresAt: now.addingTimeInterval(expiresIn),
                        approvedAt: approved.map { now.addingTimeInterval($0) },
                        productSummary: ProductSummary(id: id, brand: brand, model: model, categoryDisplay: category),
                        isInitiator: role == "buyer", role: role, counterpartyName: name,
                        notes: nil, sellerTerms: nil, sellerFullName: nil, sellerIdNumber: nil,
                        sellerMobile: nil, sellerCity: nil, certificateId: nil, certificatePdfUrl: nil,
                        confirmUrl: nil, auditLogs: nil)
        }
        let day: TimeInterval = 86_400, hour: TimeInterval = 3_600
        vm.sellerRequests = [
            txn("r1", "Galaxy", "S23 Ultra", "هاتف ذكي", status: "pending", role: "seller",
                name: "فيصل الدوسري", price: 2450, created: -12 * 60, expiresIn: 23 * hour),
        ]
        vm.pendingTransactions = [
            txn("p1", "iPhone", "15 Pro", "هاتف ذكي", status: "pending", role: "buyer",
                name: "خالد العتيبي", price: 3800, created: -3 * hour, expiresIn: 21 * hour + 30 * 60),
            txn("p2", "iPad", "Air M2", "جهاز لوحي", status: "pending", role: "buyer",
                name: "نورة الشهري", price: 1950, created: -20 * hour, expiresIn: 4 * hour + 20 * 60),
        ]
        vm.completedTransactions = [
            txn("c1", "iPhone", "14 Pro", "هاتف ذكي", status: "approved", role: "buyer",
                name: "سارة القحطاني", price: 3200, created: -2 * day, approved: -2 * day),
            txn("c2", "Apple Watch", "S9", "ساعة ذكية", status: "approved", role: "seller",
                name: "ماجد الحربي", price: 950, created: -3 * day, approved: -3 * day),
            txn("c3", "MacBook Air", "M2", "حاسوب محمول", status: "approved", role: "buyer",
                name: "محمد الغامدي", price: 3400, created: -38 * day, approved: -38 * day),
        ]
        vm.devicesCount = 4
        vm.certificatesCount = 7
        vm.hasLoaded = true
        return vm
    }
}

extension UserProfile {
    static let sample = UserProfile(
        id: "preview", userType: "individual", fullName: "عبدالرحمن الشهري",
        identitySubmitted: true, absherVerified: false, businessName: nil, crSubmitted: false,
        wathiqVerified: false, verificationStatus: "verified", canTransact: true, dateJoined: .now)
}

#Preview("الرئيسية") {
    let auth = AuthState()
    auth.user = .sample
    return HomeView(viewModel: .sample, loadsOnAppear: false)
        .environmentObject(auth)
        .environmentObject(TabRouter())
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar_SA"))
}
#endif
