// NewPurchaseSampleData.swift — Sample data for Xcode previews of the purchase flow.
// Mirrors the content of "توثيق عملية شراء" in UIDesign/gallery.html. Debug builds only.

#if DEBUG
import SwiftUI

extension NewPurchaseViewModel {
    static var sample: NewPurchaseViewModel {
        let vm = NewPurchaseViewModel()
        vm.checksIdentifier = false
        vm.brand = "Apple"
        vm.model = "iPhone 15 Pro"
        vm.identifier = "354672891039487"
        vm.identifierCheck = .free
        vm.sellerIdNumber = "1087654321"
        vm.sellerFirstName = "خالد"
        vm.sellerFatherName = "سعد"
        vm.sellerFamilyName = "العتيبي"
        vm.sellerPhone = "558123341"
        vm.sellerCity = "الرياض"
        vm.price = "3800"
        return vm
    }

    /// The flow after "إرسال للبائع للتأكيد" succeeded.
    static var sampleSent: NewPurchaseViewModel {
        let vm = sample
        vm.agreedToTerms = true
        vm.createdTransaction = Transaction(
            id: "preview", transactionType: "direct_purchase", transactionTypeDisplay: "شراء مباشر",
            status: "pending", statusDisplay: "", price: 3800, deviceCondition: "used",
            createdAt: .now, expiresAt: .now.addingTimeInterval(48 * 3_600), approvedAt: nil,
            productSummary: ProductSummary(id: "preview", brand: "Apple", model: "iPhone 15 Pro",
                                           categoryDisplay: "هاتف ذكي"),
            isInitiator: true, role: "buyer", counterpartyName: "خالد سعد العتيبي",
            notes: nil, sellerTerms: nil, sellerFullName: "خالد سعد العتيبي", sellerIdNumber: nil,
            sellerMobile: nil, sellerCity: "الرياض", certificateId: nil, certificatePdfUrl: nil,
            confirmUrl: "https://tawatur.sa/confirm/7f3c2a91/", auditLogs: nil)
        return vm
    }
}

private extension View {
    func purchasePreviewEnvironment() -> some View {
        environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar_SA"))
    }
}

#Preview("الجهاز") { NewPurchaseView(viewModel: .sample).purchasePreviewEnvironment() }
#Preview("البائع") { NewPurchaseView(viewModel: .sample, startAt: [.seller]).purchasePreviewEnvironment() }
#Preview("المراجعة") { NewPurchaseView(viewModel: .sample, startAt: [.seller, .review]).purchasePreviewEnvironment() }
#Preview("تم الإرسال") { NewPurchaseView(viewModel: .sampleSent).purchasePreviewEnvironment() }
#endif
