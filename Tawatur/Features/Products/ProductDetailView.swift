// ProductDetailView.swift — Full product detail + ownership history timeline.

import SwiftUI
import Combine

final class ProductViewModel: ObservableObject {
    @Published var product: Product?
    @Published var history: OwnershipHistory?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(id: String) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        async let prod = APIClient.shared.request(.productDetail(id: id), as: Product.self)
        async let hist = APIClient.shared.request(.ownershipHistory(id: id), as: OwnershipHistory.self)
        do {
            product = try await prod
            history = try await hist
        } catch { errorMessage = error.localizedDescription }
    }
}

struct ProductDetailView: View {

    let productId: String
    @StateObject private var vm = ProductViewModel()
    @State private var showCreateTransaction = false

    var body: some View {
        ZStack {
            Color.tSurface.ignoresSafeArea()

            if vm.isLoading {
                ProgressView().tint(.tPrimary)
            } else if let product = vm.product {
                ScrollView {
                    VStack(spacing: 16) {

                        // ── Hero card ─────────────────────────────────────────
                        VStack(spacing: 12) {
                            Image(systemName: product.categoryIcon)
                                .font(.system(size: 44)).foregroundColor(.tPrimary)
                                .frame(width: 80, height: 80)
                                .background(Color.tPrimary.opacity(0.1)).cornerRadius(16)

                            Text("\(product.brand) \(product.model)")
                                .font(.tTitle2).foregroundColor(.tText)
                            Text(product.categoryDisplay)
                                .font(.tCaption).foregroundColor(.tSubtext)

                            // Trust score pill
                            HStack(spacing: 6) {
                                Text("\(product.trustScore)/100")
                                    .font(.tBodyBold).foregroundColor(product.trustColor)
                                Text("—").foregroundColor(.tSubtext)
                                Text(product.trustLevelDisplay)
                                    .font(.tBody).foregroundColor(product.trustColor)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(product.trustColor.opacity(0.1)).cornerRadius(20)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20).background(Color.tBackground).cornerRadius(16)
                        .padding(.horizontal, 16)

                        // ── Details grid ──────────────────────────────────────
                        VStack(spacing: 0) {
                            DetailRow(label: "الحالة", value: product.conditionDisplay)
                            Divider().padding(.leading, 16)
                            DetailRow(label: "سلامة السلسلة", value: "\(product.chainIntegrity)%")
                            Divider().padding(.leading, 16)
                            DetailRow(label: "عدد الملاك", value: "\(product.totalOwners)")
                            if let imei = product.imei1, !imei.isEmpty {
                                Divider().padding(.leading, 16)
                                DetailRow(label: "IMEI", value: imei)
                            }
                            if let serial = product.serialNumber, !serial.isEmpty {
                                Divider().padding(.leading, 16)
                                DetailRow(label: "الرقم التسلسلي", value: serial)
                            }
                        }
                        .background(Color.tBackground).cornerRadius(12)
                        .padding(.horizontal, 16)

                        // ── Ownership timeline ────────────────────────────────
                        if let history = vm.history, !history.timeline.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("سلسلة الملكية")
                                    .font(.tHeadline).foregroundColor(.tText)
                                ForEach(history.timeline) { record in
                                    OwnershipTimelineRow(record: record)
                                }
                            }
                            .padding(16).background(Color.tBackground).cornerRadius(12)
                            .padding(.horizontal, 16)
                        }

                        // ── Transfer button (owner only) ──────────────────────
                        Button { showCreateTransaction = true } label: {
                            Label("تحويل الملكية", systemImage: "arrow.left.arrow.right")
                                .tPrimaryButton()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 16)
                }
            } else if let error = vm.errorMessage {
                Text(error).font(.tBody).foregroundColor(.tDanger).padding()
            }
        }
        .navigationTitle("تفاصيل المنتج")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(id: productId) }
        .sheet(isPresented: $showCreateTransaction) {
            CreateTransactionView(preselectedProductId: productId)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.tBody).foregroundColor(.tSubtext)
            Spacer()
            Text(value).font(.tBodyBold).foregroundColor(.tText)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

struct OwnershipTimelineRow: View {
    let record: OwnershipRecord
    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(record.isCurrent ? Color.tSuccess : Color.tBorder)
                    .frame(width: 12, height: 12)
                if !record.isCurrent {
                    Rectangle().fill(Color.tBorder).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.transferTypeDisplay).font(.tBodyBold).foregroundColor(.tText)
                    Spacer()
                    if record.ownerVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.tCaption).foregroundColor(.tSuccess)
                    }
                }
                Text(record.startDate, style: .date)
                    .font(.tCaption).foregroundColor(.tSubtext)
                if record.isCurrent {
                    Text("المالك الحالي").font(.tSmall).foregroundColor(.tSuccess)
                }
            }
        }
    }
}
