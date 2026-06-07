// TransactionDetailView.swift — Full transaction detail + approve/reject/cancel actions.
// Also used as the deep-link landing screen via ApproveTransactionView.

import SwiftUI
import Combine

final class TransactionViewModel: ObservableObject {
    @Published var transaction: Transaction?
    @Published var isLoading = false
    @Published var actionLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func load(id: String) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { transaction = try await APIClient.shared.request(.transactionDetail(id: id), as: Transaction.self) }
        catch { errorMessage = error.localizedDescription }
    }

    func approve(id: String) async {
        actionLoading = true; errorMessage = nil
        defer { actionLoading = false }
        do {
            struct R: Decodable { let detail: String; let transaction: Transaction }
            let result = try await APIClient.shared.request(.approveTransaction(id: id), as: R.self)
            transaction = result.transaction
            successMessage = "تمت عملية نقل الملكية بنجاح 🎉"
        } catch { errorMessage = error.localizedDescription }
    }

    func reject(id: String) async {
        actionLoading = true; errorMessage = nil
        defer { actionLoading = false }
        do {
            struct R: Decodable { let detail: String }
            _ = try await APIClient.shared.request(.rejectTransaction(id: id), as: R.self)
            transaction?.status == "pending" ? (transaction = nil) : ()
            successMessage = "تم رفض طلب نقل الملكية"
            await load(id: id)
        } catch { errorMessage = error.localizedDescription }
    }

    func cancel(id: String) async {
        actionLoading = true; errorMessage = nil
        defer { actionLoading = false }
        do {
            struct R: Decodable { let detail: String }
            _ = try await APIClient.shared.request(.cancelTransaction(id: id), as: R.self)
            successMessage = "تم إلغاء المعاملة"
            await load(id: id)
        } catch { errorMessage = error.localizedDescription }
    }
}

struct TransactionDetailView: View {

    let transactionId: String
    @StateObject private var vm = TransactionViewModel()
    @EnvironmentObject var authState: AuthState

    var body: some View {
        ZStack {
            Color.tSurface.ignoresSafeArea()
            if vm.isLoading {
                ProgressView().tint(.tPrimary)
            } else if let txn = vm.transaction {
                ScrollView {
                    VStack(spacing: 16) {
                        // Status banner
                        StatusBanner(status: txn.status, display: txn.statusDisplay)

                        // Product info
                        HStack(spacing: 14) {
                            Image(systemName: "cube.box")
                                .font(.title2).foregroundColor(.tPrimary)
                                .frame(width: 44, height: 44)
                                .background(Color.tPrimary.opacity(0.1)).cornerRadius(10)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(txn.productSummary.brand) \(txn.productSummary.model)")
                                    .font(.tBodyBold).foregroundColor(.tText)
                                Text(txn.productSummary.categoryDisplay)
                                    .font(.tCaption).foregroundColor(.tSubtext)
                            }
                            Spacer()
                            if let price = txn.price {
                                Text("\(price, specifier: "%.0f") ر.س")
                                    .font(.tBodyBold).foregroundColor(.tPrimary)
                            }
                        }
                        .padding(14).background(Color.tBackground).cornerRadius(12)

                        // Details
                        VStack(spacing: 0) {
                            DetailRow(label: "نوع المعاملة", value: txn.transactionTypeDisplay)
                            Divider().padding(.leading, 16)
                            DetailRow(label: "تاريخ الإنشاء", value: txn.createdAt.formatted(date: .abbreviated, time: .shortened))
                            Divider().padding(.leading, 16)
                            DetailRow(label: "ينتهي في", value: txn.expiresAt.formatted(date: .abbreviated, time: .shortened))
                            if let notes = txn.notes, !notes.isEmpty {
                                Divider().padding(.leading, 16)
                                DetailRow(label: "ملاحظات", value: notes)
                            }
                        }
                        .background(Color.tBackground).cornerRadius(12)

                        // Success / error messages
                        if let success = vm.successMessage {
                            Text(success).font(.tBody).foregroundColor(.tSuccess)
                                .padding(12).background(Color.tSuccess.opacity(0.08)).cornerRadius(8)
                        }
                        if let error = vm.errorMessage {
                            Text(error).font(.tCaption).foregroundColor(.tDanger)
                                .padding(12).background(Color.tDanger.opacity(0.08)).cornerRadius(8)
                        }

                        // Action buttons (only for pending transactions)
                        if txn.isPending {
                            let isRecipient = txn.isInitiator == false
                            let isInitiator = txn.isInitiator == true

                            if isRecipient {
                                VStack(spacing: 10) {
                                    Button {
                                        Task { await vm.approve(id: txn.id) }
                                    } label: {
                                        Label("قبول نقل الملكية", systemImage: "checkmark.circle")
                                            .tPrimaryButton()
                                    }
                                    Button {
                                        Task { await vm.reject(id: txn.id) }
                                    } label: {
                                        Label("رفض المعاملة", systemImage: "xmark.circle")
                                            .tSecondaryButton()
                                    }
                                }
                                .disabled(vm.actionLoading)
                                .opacity(vm.actionLoading ? 0.6 : 1)
                            } else if isInitiator {
                                Button {
                                    Task { await vm.cancel(id: txn.id) }
                                } label: {
                                    Text("إلغاء المعاملة").tSecondaryButton()
                                }
                                .disabled(vm.actionLoading)
                            }
                        }
                    }
                    .padding(16)
                }
            } else if let error = vm.errorMessage {
                Text(error).font(.tBody).foregroundColor(.tDanger).padding()
            }
        }
        .navigationTitle("تفاصيل المعاملة")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(id: transactionId) }
    }
}

struct StatusBanner: View {
    let status: String
    let display: String
    var color: Color {
        switch status {
        case "approved":  return .tSuccess
        case "rejected", "expired": return .tDanger
        case "cancelled": return .tSubtext
        default:          return .tWarning
        }
    }
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(display).font(.tBodyBold).foregroundColor(color)
            Spacer()
        }
        .padding(14)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
}

// ── My transactions list ──────────────────────────────────────────────────────

struct MyTransactionsView: View {

    @State private var transactions: [Transaction] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tSurface.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(.tPrimary)
                } else if transactions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 48)).foregroundColor(.tSubtext.opacity(0.3))
                        Text("لا توجد معاملات بعد").font(.tBodyBold).foregroundColor(.tSubtext)
                    }
                } else {
                    List(transactions) { txn in
                        NavigationLink(destination: TransactionDetailView(transactionId: txn.id)) {
                            TransactionRow(transaction: txn)
                        }
                        .listRowBackground(Color.tBackground)
                        .listRowSeparatorTint(Color.tBorder)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("معاملاتي")
            .task {
                isLoading = true
                transactions = (try? await APIClient.shared.request(.myTransactions, as: [Transaction].self)) ?? []
                isLoading = false
            }
            .refreshable {
                transactions = (try? await APIClient.shared.request(.myTransactions, as: [Transaction].self)) ?? []
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(transaction.statusColor.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.subheadline).foregroundColor(transaction.statusColor)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text("\(transaction.productSummary.brand) \(transaction.productSummary.model)")
                    .font(.tBodyBold).foregroundColor(.tText)
                Text(transaction.statusDisplay)
                    .font(.tCaption).foregroundColor(transaction.statusColor)
            }
            Spacer()
            Text(transaction.createdAt, style: .date)
                .font(.tSmall).foregroundColor(.tSubtext)
        }
        .padding(.vertical, 6)
    }
}

// ── Approve via deep link ─────────────────────────────────────────────────────

struct ApproveTransactionView: View {

    let linkToken: String
    @StateObject private var vm = ApproveTransactionViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tBackground.ignoresSafeArea()
                if vm.isLoading {
                    ProgressView().tint(.tPrimary)
                } else if let info = vm.linkInfo {
                    VStack(spacing: 20) {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 56)).foregroundColor(.tPrimary)
                        Text("طلب نقل ملكية").font(.tTitle2).foregroundColor(.tText)
                        VStack(spacing: 0) {
                            DetailRow(label: "المنتج", value: "\(info.product.brand) \(info.product.model)")
                            Divider().padding(.leading, 16)
                            DetailRow(label: "الفئة", value: info.product.categoryDisplay)
                            Divider().padding(.leading, 16)
                            DetailRow(label: "درجة الثقة", value: "\(info.product.trustScore)/100")
                            if let price = info.price {
                                Divider().padding(.leading, 16)
                                DetailRow(label: "السعر", value: String(format: "%.0f ر.س", price))
                            }
                        }
                        .background(Color.tSurface).cornerRadius(12).padding(.horizontal, 20)

                        if let error = vm.errorMessage {
                            Text(error).font(.tCaption).foregroundColor(.tDanger)
                                .padding(12).background(Color.tDanger.opacity(0.08)).cornerRadius(8)
                                .padding(.horizontal, 20)
                        }
                        if let success = vm.successMessage {
                            Text(success).font(.tBodyBold).foregroundColor(.tSuccess)
                                .padding(12).background(Color.tSuccess.opacity(0.08)).cornerRadius(8)
                                .padding(.horizontal, 20)
                        }

                        Spacer()

                        if vm.transactionId != nil && vm.successMessage == nil {
                            VStack(spacing: 10) {
                                Button { Task { await vm.approve() } } label: {
                                    Label("قبول نقل الملكية", systemImage: "checkmark.circle")
                                        .tPrimaryButton()
                                }
                                Button { Task { await vm.reject() } } label: {
                                    Label("رفض المعاملة", systemImage: "xmark.circle")
                                        .tSecondaryButton()
                                }
                            }
                            .disabled(vm.actionLoading)
                            .padding(.horizontal, 20)
                        }

                        Button { dismiss() } label: {
                            Text("إغلاق").font(.tCaption).foregroundColor(.tSubtext)
                        }
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle("مراجعة المعاملة")
            .navigationBarTitleDisplayMode(.inline)
            .task { await vm.resolveLink(token: linkToken) }
        }
    }
}

final class ApproveTransactionViewModel: ObservableObject {
    @Published var linkInfo: TransactionLinkInfo?
    @Published var transactionId: String?
    @Published var isLoading = false
    @Published var actionLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func resolveLink(token: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            linkInfo = try await APIClient.shared.request(.resolveLink(token: token), as: TransactionLinkInfo.self)
            transactionId = linkInfo?.transactionId
        } catch { errorMessage = error.localizedDescription }
    }

    func approve() async {
        guard let id = transactionId else { return }
        actionLoading = true
        defer { actionLoading = false }
        do {
            struct R: Decodable { let detail: String }
            _ = try await APIClient.shared.request(.approveTransaction(id: id), as: R.self)
            successMessage = "تمت عملية نقل الملكية بنجاح 🎉"
            transactionId = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func reject() async {
        guard let id = transactionId else { return }
        actionLoading = true
        defer { actionLoading = false }
        do {
            struct R: Decodable { let detail: String }
            _ = try await APIClient.shared.request(.rejectTransaction(id: id), as: R.self)
            successMessage = "تم رفض طلب نقل الملكية"
            transactionId = nil
        } catch { errorMessage = error.localizedDescription }
    }
}
