// CreateTransactionView.swift — توثيق عملية شراء منتج مسجّل.
// Step 1: اختر المنتج  →  Step 2: بيانات البائع والصفقة  →  Step 3: اكتملت العملية

import SwiftUI
import Combine

// ── ViewModel ────────────────────────────────────────────────────────────────

final class CreateTransactionViewModel: ObservableObject {
    @Published var step = 1
    @Published var products: [Product] = []
    @Published var selectedProduct: Product?

    // Seller info
    @Published var sellerIdNumber   = ""
    @Published var sellerFirstName  = ""
    @Published var sellerMiddleName = ""
    @Published var sellerLastName   = ""
    @Published var sellerMobile     = ""
    @Published var sellerCity       = ""

    // Deal details
    @Published var price           = ""
    @Published var deviceCondition = "used"
    @Published var noTerms         = false
    @Published var sellerTerms     = ""
    @Published var notes           = ""

    @Published var isLoading          = false
    @Published var errorMessage: String?
    @Published var createdTransaction: Transaction?

    var sellerFullName: String {
        [sellerFirstName, sellerMiddleName, sellerLastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var canSubmit: Bool {
        !sellerIdNumber.isEmpty && !sellerFirstName.isEmpty &&
        !sellerLastName.isEmpty && !sellerMobile.isEmpty && !sellerCity.isEmpty
    }

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
                .createDirectPurchase(
                    productId:      product.id,
                    sellerFullName: sellerFullName,
                    sellerIdNumber: sellerIdNumber,
                    sellerMobile:   sellerMobile,
                    sellerCity:     sellerCity,
                    price:          Double(price),
                    deviceCondition: deviceCondition.isEmpty ? nil : deviceCondition,
                    sellerTerms:    noTerms ? nil : (sellerTerms.isEmpty ? nil : sellerTerms),
                    notes:          notes.isEmpty ? nil : notes
                ),
                as: Transaction.self
            )
            withAnimation { step = 3 }
        } catch { errorMessage = error.localizedDescription }
    }
}

// ── Root View ────────────────────────────────────────────────────────────────

struct CreateTransactionView: View {

    var preselectedProductId: String? = nil
    @StateObject private var vm = CreateTransactionViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    StepIndicator(current: vm.step, total: 3)
                        .padding(.vertical, 16)

                    Group {
                        switch vm.step {
                        case 1:  Step1SelectProduct(vm: vm)
                        case 2:  Step2SellerForm(vm: vm)
                        default: Step3Completion(vm: vm, dismiss: dismiss)
                        }
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing),
                                            removal: .move(edge: .leading)))
                    .animation(.easeInOut(duration: 0.25), value: vm.step)
                }
            }
            .navigationTitle("توثيق عملية شراء")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.step < 3 {
                        Button("إلغاء") { dismiss() }
                            .foregroundColor(.tSubtext)
                    }
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

// ── Step 1: اختر المنتج ───────────────────────────────────────────────────────

struct Step1SelectProduct: View {
    @ObservedObject var vm: CreateTransactionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("اختر المنتج").font(.tTitle2).foregroundColor(.tText)
                Text("اختر المنتج الذي اشتريته وتريد توثيق ملكيته")
                    .font(.tBody).foregroundColor(.tSubtext)
            }
            .padding(.horizontal, 20)

            if vm.products.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray").font(.system(size: 40)).foregroundColor(.tSubtext.opacity(0.3))
                    Text("لا توجد منتجات مسجّلة").font(.tBodyBold).foregroundColor(.tSubtext)
                    Text("سجّل منتجاً أولاً ثم وثّق شراءه")
                        .font(.tCaption).foregroundColor(.tSubtext.opacity(0.7))
                }
                .frame(maxWidth: .infinity).padding(.top, 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.products) { product in
                            Button {
                                vm.selectedProduct = product
                                withAnimation { vm.step = 2 }
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
            }
            Spacer()
        }
        .padding(.top, 8)
    }
}

// ── Step 2: بيانات البائع والصفقة ────────────────────────────────────────────

private let saudiCities = [
    "الرياض", "جدة", "مكة المكرمة", "المدينة المنورة",
    "الدمام", "الخبر", "الظهران", "الطائف", "بريدة",
    "تبوك", "أبها", "خميس مشيط", "الجبيل", "الأحساء",
    "حائل", "نجران", "جازان", "عرعر", "سكاكا", "الباحة",
]

struct Step2SellerForm: View {
    @ObservedObject var vm: CreateTransactionViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // ── بيانات البائع ────────────────────────────────────────────
                FormSectionLabel(title: "بيانات البائع", icon: "person.text.rectangle")

                TField(label: "رقم الهوية الوطنية أو الإقامة",
                       placeholder: "10 أرقام", text: $vm.sellerIdNumber)
                    .keyboardType(.numberPad)

                HStack(spacing: 10) {
                    TField(label: "الاسم الأول", placeholder: "محمد", text: $vm.sellerFirstName)
                    TField(label: "الاسم الأوسط", placeholder: "علي (اختياري)", text: $vm.sellerMiddleName)
                }

                TField(label: "الاسم الأخير (اسم الأب)", placeholder: "الأحمد", text: $vm.sellerLastName)

                TField(label: "رقم جوال البائع", placeholder: "05XXXXXXXX", text: $vm.sellerMobile)
                    .keyboardType(.phonePad)

                // City picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("المدينة").font(.tCaption).foregroundColor(.tSubtext)
                    Menu {
                        ForEach(saudiCities, id: \.self) { city in
                            Button(city) { vm.sellerCity = city }
                        }
                    } label: {
                        HStack {
                            Text(vm.sellerCity.isEmpty ? "اختر المدينة" : vm.sellerCity)
                                .font(.tBody)
                                .foregroundColor(vm.sellerCity.isEmpty ? .tSubtext.opacity(0.6) : .tText)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.tCaption).foregroundColor(.tSubtext)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 14)
                        .background(Color.tSurface).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.tBorder, lineWidth: 1))
                    }
                }

                Divider()

                // ── تفاصيل الصفقة ────────────────────────────────────────────
                FormSectionLabel(title: "تفاصيل الصفقة", icon: "tag")

                TField(label: "السعر بالريال السعودي (اختياري)",
                       placeholder: "0.00", text: $vm.price)
                    .keyboardType(.decimalPad)

                VStack(alignment: .leading, spacing: 8) {
                    Text("حالة الجهاز").font(.tCaption).foregroundColor(.tSubtext)
                    Picker("", selection: $vm.deviceCondition) {
                        Text("مستعمل").tag("used")
                        Text("جديد").tag("new")
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("شروط المشتري (اختياري)").font(.tCaption).foregroundColor(.tSubtext)

                    if !vm.noTerms {
                        ZStack(alignment: .topLeading) {
                            if vm.sellerTerms.isEmpty {
                                Text("اكتب الشروط هنا...")
                                    .font(.tBody).foregroundColor(.tSubtext.opacity(0.5))
                                    .padding(.horizontal, 14).padding(.top, 18)
                            }
                            TextEditor(text: $vm.sellerTerms)
                                .font(.tBody).frame(height: 100)
                                .padding(10).background(Color.clear)
                                .scrollContentBackground(.hidden)
                        }
                        .background(Color.tSurface).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.tBorder, lineWidth: 1))
                    }

                    Button {
                        vm.noTerms.toggle()
                        if vm.noTerms { vm.sellerTerms = "" }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: vm.noTerms ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(vm.noTerms ? .tPrimary : .tSubtext)
                            Text("لا توجد شروط").font(.tBody).foregroundColor(.tText)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("ملاحظات (اختياري)").font(.tCaption).foregroundColor(.tSubtext)
                    ZStack(alignment: .topLeading) {
                        if vm.notes.isEmpty {
                            Text("أي ملاحظات إضافية...")
                                .font(.tBody).foregroundColor(.tSubtext.opacity(0.5))
                                .padding(.horizontal, 14).padding(.top, 18)
                        }
                        TextEditor(text: $vm.notes)
                            .font(.tBody).frame(height: 80)
                            .padding(10).background(Color.clear)
                            .scrollContentBackground(.hidden)
                    }
                    .background(Color.tSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.tBorder, lineWidth: 1))
                }

                if let error = vm.errorMessage {
                    Text(error).font(.tCaption).foregroundColor(.tDanger)
                        .padding(12).background(Color.tDanger.opacity(0.08)).cornerRadius(8)
                }

                // ── Buttons ──────────────────────────────────────────────────
                HStack(spacing: 12) {
                    Button {
                        vm.errorMessage = nil
                        withAnimation { vm.step = 1 }
                    } label: {
                        Text("السابق").tSecondaryButton()
                    }

                    Button {
                        Task { await vm.submit() }
                    } label: {
                        if vm.isLoading {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.tPrimary).cornerRadius(10)
                        } else {
                            Text("اتمام عملية الشراء من بيانات أعلاه")
                                .tPrimaryButton()
                        }
                    }
                    .disabled(vm.isLoading || !vm.canSubmit)
                    .opacity(vm.canSubmit ? 1 : 0.6)
                }
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
}

// ── Step 3: اكتملت العملية ────────────────────────────────────────────────────

struct Step3Completion: View {
    @ObservedObject var vm: CreateTransactionViewModel
    let dismiss: DismissAction
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                // Success icon
                ZStack {
                    Circle()
                        .fill(Color.tSuccess.opacity(0.1))
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.tSuccess)
                }

                VStack(spacing: 8) {
                    Text("تمت عملية الشراء بنجاح")
                        .font(.tTitle2).foregroundColor(.tText)
                    Text("تم توثيق ملكية الجهاز على منصة تواتر")
                        .font(.tBody).foregroundColor(.tSubtext)
                        .multilineTextAlignment(.center)
                }

                // Product summary
                if let product = vm.selectedProduct {
                    HStack(spacing: 14) {
                        Image(systemName: product.categoryIcon)
                            .font(.title2).foregroundColor(.tPrimary)
                            .frame(width: 44, height: 44)
                            .background(Color.tPrimary.opacity(0.1)).cornerRadius(10)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(product.brand) \(product.model)")
                                .font(.tBodyBold).foregroundColor(.tText)
                            Text(product.categoryDisplay)
                                .font(.tCaption).foregroundColor(.tSubtext)
                        }
                        Spacer()
                        if let priceVal = Double(vm.price) {
                            Text(String(format: "%.0f ر.س", priceVal))
                                .font(.tBodyBold).foregroundColor(.tPrimary)
                        }
                    }
                    .padding(14).background(Color.tSurface).cornerRadius(12)
                }

                // Seller summary
                if let txn = vm.createdTransaction {
                    VStack(spacing: 0) {
                        if let name = txn.sellerFullName, !name.isEmpty {
                            CompletionRow(label: "اسم البائع", value: name)
                            Divider().padding(.leading, 16)
                        }
                        if let city = txn.sellerCity, !city.isEmpty {
                            CompletionRow(label: "المدينة", value: city)
                        }
                    }
                    .background(Color.tSurface).cornerRadius(12)

                    // Certificate
                    if let pdfUrlStr = txn.certificatePdfUrl,
                       let pdfUrl = URL(string: pdfUrlStr) {
                        Button {
                            openURL(pdfUrl)
                        } label: {
                            Label("تحميل شهادة الشراء PDF", systemImage: "doc.fill")
                                .tPrimaryButton()
                        }
                    } else {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text("جاري إنشاء الشهادة...")
                                .font(.tCaption).foregroundColor(.tSubtext)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14).background(Color.tSurface).cornerRadius(10)
                    }
                }

                Button { dismiss() } label: {
                    Text("العودة للرئيسية").tSecondaryButton()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
    }
}

// ── Shared components ─────────────────────────────────────────────────────────

struct FormSectionLabel: View {
    let title: String
    let icon: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.subheadline).foregroundColor(.tPrimary)
            Text(title).font(.tBodyBold).foregroundColor(.tText)
        }
    }
}

struct CompletionRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.tCaption).foregroundColor(.tSubtext)
            Spacer()
            Text(value).font(.tBody).foregroundColor(.tText)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

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
