// HomeView.swift — Dashboard: pending transactions + my completed operations (معاملاتي).

import SwiftUI
import Combine

final class HomeViewModel: ObservableObject {
    @Published var pendingTransactions: [Transaction] = []
    @Published var completedTransactions: [Transaction] = []
    @Published var sellerRequests: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        async let txnsCall = APIClient.shared.request(.myTransactions, as: [Transaction].self)
        async let requestsCall = APIClient.shared.request(.pendingSellerRequests, as: [Transaction].self)
        do {
            let txns = try await txnsCall
            pendingTransactions   = txns.filter { $0.isPending }
            completedTransactions = txns.filter { $0.isApproved }
        } catch { errorMessage = error.localizedDescription }
        sellerRequests = (try? await requestsCall) ?? []
    }
}

struct HomeView: View {

    @EnvironmentObject var authState: AuthState
    @StateObject private var vm = HomeViewModel()
    @State private var showNewPurchase = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tSurface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // ── Greeting header ───────────────────────────────────
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("مرحباً بك")
                                    .font(.tCaption).foregroundColor(.tSubtext)
                                Text(authState.user?.businessName ?? "مستخدم تواتر")
                                    .font(.tTitle2).foregroundColor(.tText)
                            }
                            Spacer()
                            VerificationBadge(status: authState.user?.verificationStatus ?? "unverified")
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        // ── Buy-requests addressed to me (as the named seller) ─
                        if !vm.sellerRequests.isEmpty {
                            SectionHeader(title: "طلبات شراء بانتظار ردك", count: vm.sellerRequests.count)
                            LazyVStack(spacing: 12) {
                                ForEach(vm.sellerRequests) { txn in
                                    NavigationLink(destination: TransactionDetailView(transactionId: txn.id)) {
                                        SellerRequestCard(transaction: txn)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // ── Pending transactions ──────────────────────────────
                        if !vm.pendingTransactions.isEmpty {
                            SectionHeader(title: "معاملات بانتظار الموافقة", count: vm.pendingTransactions.count)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(vm.pendingTransactions) { txn in
                                        NavigationLink(destination: TransactionDetailView(transactionId: txn.id)) {
                                            PendingTransactionCard(transaction: txn)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // ── معاملاتي — completed selling operations ───────────
                        SectionHeader(title: "معاملاتي", count: vm.completedTransactions.count)

                        if vm.isLoading {
                            ProgressView().tint(.tPrimary).padding(40)
                        } else if vm.completedTransactions.isEmpty {
                            EmptyOperationsView(showCreate: $showNewPurchase)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(vm.completedTransactions) { txn in
                                    NavigationLink(destination: TransactionDetailView(transactionId: txn.id)) {
                                        CompletedTransactionCard(transaction: txn)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        if let error = vm.errorMessage {
                            Text(error).font(.tCaption).foregroundColor(.tDanger).padding(20)
                        }

                        Spacer(minLength: 30)
                    }
                }
                .refreshable { await vm.load() }
            }
            .navigationTitle("تواتر")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showNewPurchase = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2).foregroundColor(.tPrimary)
                    }
                }
            }
            .sheet(isPresented: $showNewPurchase, onDismiss: { Task { await vm.load() } }) {
                NewPurchaseView()
            }
            .task { await vm.load() }
        }
    }
}

// ── Sub-components ────────────────────────────────────────────────────────────

struct SectionHeader: View {
    let title: String
    let count: Int
    var body: some View {
        HStack {
            Text(title).font(.tHeadline).foregroundColor(.tText)
            Spacer()
            if count > 0 {
                Text("\(count)").font(.tSmall).foregroundColor(.tSubtext)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.tSurface).cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct VerificationBadge: View {
    let status: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status == "verified" ? "checkmark.seal.fill" : "clock.fill")
            Text(status == "verified" ? "موثق" : status == "pending" ? "قيد المراجعة" : "غير موثق")
                .font(.tSmall)
        }
        .foregroundColor(status == "verified" ? .tSuccess : .tWarning)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background((status == "verified" ? Color.tSuccess : Color.tWarning).opacity(0.1))
        .cornerRadius(20)
    }
}

struct CompletedTransactionCard: View {
    let transaction: Transaction
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2).foregroundColor(.tSuccess)
                .frame(width: 44, height: 44)
                .background(Color.tSuccess.opacity(0.1)).cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(transaction.productSummary.brand) \(transaction.productSummary.model)")
                    .font(.tBodyBold).foregroundColor(.tText)
                if let seller = transaction.sellerFullName, !seller.isEmpty {
                    Text("من: \(seller)").font(.tCaption).foregroundColor(.tSubtext)
                } else {
                    Text(transaction.productSummary.categoryDisplay)
                        .font(.tCaption).foregroundColor(.tSubtext)
                }
            }
            Spacer()
            if let price = transaction.price {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(price, specifier: "%.0f")").font(.tBodyBold).foregroundColor(.tPrimary)
                    Text("ر.س").font(.tSmall).foregroundColor(.tSubtext)
                }
            }
        }
        .padding(14)
        .background(Color.tBackground)
        .cornerRadius(12)
        .shadow(color: Color.tText.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

struct SellerRequestCard: View {
    let transaction: Transaction
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "bell.badge.fill")
                .font(.title2).foregroundColor(.tWarning)
                .frame(width: 44, height: 44)
                .background(Color.tWarning.opacity(0.12)).cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text("طلب شراء \(transaction.productSummary.brand) \(transaction.productSummary.model)")
                    .font(.tBodyBold).foregroundColor(.tText)
                Text("يحتاج تأكيدك كبائع").font(.tCaption).foregroundColor(.tWarning)
            }
            Spacer()
            if let price = transaction.price {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(price, specifier: "%.0f")").font(.tBodyBold).foregroundColor(.tPrimary)
                    Text("ر.س").font(.tSmall).foregroundColor(.tSubtext)
                }
            }
        }
        .padding(14)
        .background(Color.tBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.tWarning.opacity(0.3), lineWidth: 1.2))
        .shadow(color: Color.tText.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

struct PendingTransactionCard: View {
    let transaction: Transaction
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(transaction.transactionTypeDisplay)
                .font(.tCaption).foregroundColor(.tSubtext)
            Text("\(transaction.productSummary.brand) \(transaction.productSummary.model)")
                .font(.tBodyBold).foregroundColor(.tText)
            if let price = transaction.price {
                Text("\(price, specifier: "%.0f") ر.س")
                    .font(.tBody).foregroundColor(.tPrimary)
            }
            HStack(spacing: 4) {
                Circle().fill(Color.tWarning).frame(width: 6, height: 6)
                Text("بانتظار الموافقة").font(.tSmall).foregroundColor(.tWarning)
            }
        }
        .padding(14)
        .frame(width: 180)
        .background(Color.tBackground)
        .cornerRadius(12)
        .shadow(color: Color.tText.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

struct EmptyOperationsView: View {
    @Binding var showCreate: Bool
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal").font(.system(size: 48)).foregroundColor(.tSubtext.opacity(0.4))
            Text("لا توجد معاملات مكتملة بعد").font(.tBodyBold).foregroundColor(.tSubtext)
            Text("سجّل أول عملية شراء وابدأ ببناء تاريخ ملكية موثوق")
                .font(.tCaption).foregroundColor(.tSubtext).multilineTextAlignment(.center)
            Button { showCreate = true } label: { Text("عملية شراء جديدة").tPrimaryButton() }
                .frame(maxWidth: 220)
        }
        .padding(40)
    }
}
