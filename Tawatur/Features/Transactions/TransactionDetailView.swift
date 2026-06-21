// TransactionDetailView.swift — Full detail of a direct-purchase transaction.

import SwiftUI
import Combine

final class TransactionViewModel: ObservableObject {
    @Published var transaction: Transaction?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(id: String) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { transaction = try await APIClient.shared.request(.transactionDetail(id: id), as: Transaction.self) }
        catch { errorMessage = error.localizedDescription }
    }
}

struct TransactionDetailView: View {

    let transactionId: String
    @StateObject private var vm = TransactionViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.tSurface.ignoresSafeArea()
            if vm.isLoading {
                ProgressView().tint(.tPrimary)
            } else if let txn = vm.transaction {
                ScrollView {
                    VStack(spacing: 16) {
                        StatusBanner(status: txn.status, display: txn.statusDisplay)

                        // Product
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

                        // Transaction details
                        VStack(spacing: 0) {
                            DetailRow(label: "نوع المعاملة", value: txn.transactionTypeDisplay)
                            Divider().padding(.leading, 16)
                            DetailRow(label: "تاريخ الإنشاء",
                                      value: txn.createdAt.formatted(date: .abbreviated, time: .shortened))
                            if let approved = txn.approvedAt {
                                Divider().padding(.leading, 16)
                                DetailRow(label: "تاريخ الاكتمال",
                                          value: approved.formatted(date: .abbreviated, time: .shortened))
                            }
                            if let cond = txn.deviceCondition, !cond.isEmpty {
                                Divider().padding(.leading, 16)
                                DetailRow(label: "حالة الجهاز", value: cond == "new" ? "جديد" : "مستعمل")
                            }
                        }
                        .background(Color.tBackground).cornerRadius(12)

                        // Seller info
                        if let name = txn.sellerFullName, !name.isEmpty {
                            VStack(spacing: 0) {
                                DetailRow(label: "اسم البائع", value: name)
                                if let city = txn.sellerCity, !city.isEmpty {
                                    Divider().padding(.leading, 16)
                                    DetailRow(label: "المدينة", value: city)
                                }
                                if let mobile = txn.sellerMobile, !mobile.isEmpty {
                                    Divider().padding(.leading, 16)
                                    DetailRow(label: "جوال البائع", value: mobile)
                                }
                                if let idNo = txn.sellerIdNumber, !idNo.isEmpty {
                                    Divider().padding(.leading, 16)
                                    DetailRow(label: "هوية البائع", value: idNo)
                                }
                            }
                            .background(Color.tBackground).cornerRadius(12)
                        }

                        // Optional text fields
                        if let terms = txn.sellerTerms, !terms.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("الشروط").font(.tCaption).foregroundColor(.tSubtext)
                                Text(terms).font(.tBody).foregroundColor(.tText)
                            }
                            .padding(14).background(Color.tBackground).cornerRadius(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let notes = txn.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ملاحظات").font(.tCaption).foregroundColor(.tSubtext)
                                Text(notes).font(.tBody).foregroundColor(.tText)
                            }
                            .padding(14).background(Color.tBackground).cornerRadius(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Certificate
                        if let pdfUrlStr = txn.certificatePdfUrl,
                           let pdfUrl = URL(string: pdfUrlStr) {
                            Button {
                                openURL(pdfUrl)
                            } label: {
                                Label("تحميل شهادة الشراء PDF", systemImage: "doc.fill")
                                    .tPrimaryButton()
                            }
                        }

                        if let error = vm.errorMessage {
                            Text(error).font(.tCaption).foregroundColor(.tDanger)
                                .padding(12).background(Color.tDanger.opacity(0.08)).cornerRadius(8)
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

// ── Shared UI components ──────────────────────────────────────────────────────

struct StatusBanner: View {
    let status: String
    let display: String
    var color: Color {
        switch status {
        case "approved":           return .tSuccess
        case "rejected", "expired": return .tDanger
        case "cancelled":          return .tSubtext
        default:                   return .tWarning
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
                    Image(systemName: "checkmark.seal")
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
