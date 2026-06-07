// CreateTransactionView.swift — 4-step wizard to initiate an ownership transfer.
// Step 1: Select product  →  Step 2: Recipient phone  →  Step 3: Details  →  Step 4: Confirm & Share

import SwiftUI
import Combine

final class CreateTransactionViewModel: ObservableObject {
    @Published var step = 1
    @Published var products: [Product] = []
    @Published var selectedProduct: Product?
    @Published var recipientPhone = ""
    @Published var transactionType = "individual_to_individual"
    @Published var price = ""
    @Published var notes = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var createdTransaction: Transaction?

    func loadProducts() async {
        do { products = try await APIClient.shared.request(.myProducts, as: [Product].self) }
        catch { errorMessage = error.localizedDescription }
    }

    func submit() async {
        guard let product = selectedProduct else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            createdTransaction = try await APIClient.shared.request(
                .createTransaction(
                    productId: product.id,
                    recipientPhone: recipientPhone,
                    type: transactionType,
                    price: Double(price),
                    notes: notes.isEmpty ? nil : notes
                ),
                as: Transaction.self
            )
            step = 4
        } catch { errorMessage = error.localizedDescription }
    }
}

struct CreateTransactionView: View {

    var preselectedProductId: String? = nil
    @StateObject private var vm = CreateTransactionViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Step indicator
                    StepIndicator(current: vm.step, total: 4)
                        .padding(.vertical, 16)

                    // Step content
                    Group {
                        switch vm.step {
                        case 1: Step1SelectProduct(vm: vm)
                        case 2: Step2RecipientPhone(vm: vm)
                        case 3: Step3Details(vm: vm)
                        default: Step4Share(vm: vm, dismiss: dismiss)
                        }
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing),
                                            removal: .move(edge: .leading)))
                    .animation(.easeInOut(duration: 0.25), value: vm.step)
                }
            }
            .navigationTitle("تحويل الملكية")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                        .foregroundColor(.tSubtext)
                }
            }
            .task {
                await vm.loadProducts()
                if let id = preselectedProductId {
                    vm.selectedProduct = vm.products.first { $0.id == id }
                    if vm.selectedProduct != nil { vm.step = 2 }
                }
            }
        }
    }
}

// ── Step 1: Select product ────────────────────────────────────────────────────

struct Step1SelectProduct: View {
    @ObservedObject var vm: CreateTransactionViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("اختر المنتج").font(.tTitle2).foregroundColor(.tText)
            Text("اختر المنتج الذي تريد تحويل ملكيته").font(.tBody).foregroundColor(.tSubtext)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(vm.products) { product in
                        Button {
                            vm.selectedProduct = product
                            vm.step = 2
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: product.categoryIcon)
                                    .font(.title2).foregroundColor(.tPrimary)
                                    .frame(width: 40, height: 40)
                                    .background(Color.tPrimary.opacity(0.1)).cornerRadius(8)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(product.brand) \(product.model)")
                                        .font(.tBodyBold).foregroundColor(.tText)
                                    Text(product.categoryDisplay)
                                        .font(.tCaption).foregroundColor(.tSubtext)
                                }
                                Spacer()
                                Image(systemName: "chevron.left")
                                    .font(.tCaption).foregroundColor(.tSubtext)
                            }
                            .padding(14).background(Color.tSurface).cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            Spacer()
        }
        .padding(.top, 8)
    }
}

// ── Step 2: Recipient phone ───────────────────────────────────────────────────

struct Step2RecipientPhone: View {
    @ObservedObject var vm: CreateTransactionViewModel
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("رقم المُحوَّل إليه").font(.tTitle2).foregroundColor(.tText)
                Text("أدخل رقم جوال الشخص الذي ستحوّل إليه المنتج")
                    .font(.tBody).foregroundColor(.tSubtext)
            }
            .padding(.top, 8)

            TField(label: "رقم الجوال", placeholder: "05XXXXXXXX", text: $vm.recipientPhone)
                .keyboardType(.phonePad)

            // Transaction type
            VStack(alignment: .leading, spacing: 8) {
                Text("نوع المعاملة").font(.tCaption).foregroundColor(.tSubtext)
                Picker("", selection: $vm.transactionType) {
                    Text("بين أفراد").tag("individual_to_individual")
                    Text("بيع منشأة").tag("business_sale")
                    Text("شراء منشأة").tag("business_purchase")
                }
                .pickerStyle(.segmented)
            }

            if let error = vm.errorMessage {
                Text(error).font(.tCaption).foregroundColor(.tDanger)
                    .padding(12).background(Color.tDanger.opacity(0.08)).cornerRadius(8)
            }

            Spacer()

            HStack(spacing: 12) {
                Button { vm.step = 1 } label: {
                    Text("السابق").tSecondaryButton()
                }
                Button { vm.step = 3 } label: {
                    Text("التالي").tPrimaryButton()
                }
                .disabled(vm.recipientPhone.count < 10)
                .opacity(vm.recipientPhone.count < 10 ? 0.6 : 1)
            }
            .padding(.horizontal, 20).padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
    }
}

// ── Step 3: Price + notes ─────────────────────────────────────────────────────

struct Step3Details: View {
    @ObservedObject var vm: CreateTransactionViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("تفاصيل المعاملة").font(.tTitle2).foregroundColor(.tText)
                Text("أدخل السعر والملاحظات (اختياري)")
                    .font(.tBody).foregroundColor(.tSubtext)
            }.padding(.top, 8)

            TField(label: "السعر بالريال السعودي (اختياري)", placeholder: "0.00", text: $vm.price)
                .keyboardType(.decimalPad)

            VStack(alignment: .leading, spacing: 6) {
                Text("ملاحظات").font(.tCaption).foregroundColor(.tSubtext)
                TextEditor(text: $vm.notes)
                    .font(.tBody)
                    .frame(height: 100)
                    .padding(10)
                    .background(Color.tSurface)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.tBorder, lineWidth: 1))
            }

            Spacer()

            HStack(spacing: 12) {
                Button { vm.step = 2 } label: { Text("السابق").tSecondaryButton() }
                Button { Task { await vm.submit() } } label: {
                    if vm.isLoading {
                        ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.tPrimary).cornerRadius(10)
                    } else { Text("إنشاء المعاملة").tPrimaryButton() }
                }
                .disabled(vm.isLoading)
            }
            .padding(.horizontal, 20).padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
    }
}

// ── Step 4: Share link ────────────────────────────────────────────────────────

struct Step4Share: View {
    @ObservedObject var vm: CreateTransactionViewModel
    let dismiss: DismissAction
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64)).foregroundColor(.tSuccess)
            Text("تم إنشاء المعاملة بنجاح").font(.tTitle2).foregroundColor(.tText)
            Text("أرسل الرابط أدناه للطرف الآخر ليقبل نقل الملكية")
                .font(.tBody).foregroundColor(.tSubtext).multilineTextAlignment(.center)

            if let link = vm.createdTransaction?.shareLink {
                Text(link)
                    .font(.tSmall).foregroundColor(.tSubtext)
                    .padding(12).background(Color.tSurface).cornerRadius(8)
                    .lineLimit(1).truncationMode(.middle)

                ShareLink(item: link) {
                    Label("مشاركة الرابط عبر واتساب أو غيره", systemImage: "square.and.arrow.up")
                        .tPrimaryButton()
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Text("العودة للرئيسية").tSecondaryButton()
            }
            .padding(.horizontal, 24).padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
    }
}

// ── Step indicator ────────────────────────────────────────────────────────────

struct StepIndicator: View {
    let current: Int
    let total: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? Color.tPrimary : Color.tBorder)
                    .frame(width: i == current ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: current)
            }
        }
    }
}
