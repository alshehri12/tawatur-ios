// NewPurchaseView.swift — the "+" button flow.
// Step 1: بيانات الجهاز  →  Step 2: بيانات البائع والصفقة  →  Step 3: بانتظار موافقة البائع
//
// Replaces the old two-step "register a product" (which just ended at
// "منتجاتي") followed separately by "document a purchase". Now it's one
// flow: register the device you just bought AND document who you bought it
// from, in one go. The transaction is created PENDING — the seller reviews
// and confirms it via a shared link (no Tawatur account needed on their
// side) before the certificate is issued.

import SwiftUI
import Combine

// ── ViewModel ────────────────────────────────────────────────────────────────

final class NewPurchaseViewModel: ObservableObject {
    @Published var step = 1

    // Product fields
    @Published var category = "smartphone"
    @Published var brand = ""
    @Published var model = ""
    @Published var condition = "used"
    @Published var identifier = ""
    @Published var productNotes = ""
    @Published var showScanner = false

    // Seller info
    @Published var sellerIdNumber   = ""
    @Published var sellerFirstName  = ""
    @Published var sellerMiddleName = ""
    @Published var sellerLastName   = ""
    @Published var sellerMobile     = ""
    @Published var sellerCity       = ""

    // Deal details
    @Published var price       = ""
    @Published var noTerms     = false
    @Published var sellerTerms = ""
    @Published var notes       = ""

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var createdTransaction: Transaction?

    var sellerFullName: String {
        [sellerFirstName, sellerMiddleName, sellerLastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var canSubmitStep1: Bool {
        !brand.isEmpty && !model.isEmpty && !identifier.isEmpty
    }

    var canSubmitStep2: Bool {
        !sellerIdNumber.isEmpty && !sellerFirstName.isEmpty &&
        !sellerLastName.isEmpty && !sellerMobile.isEmpty && !sellerCity.isEmpty
    }

    func submit() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            createdTransaction = try await APIClient.shared.request(
                .createRegisteredPurchase(
                    category: category, brand: brand, model: model,
                    condition: condition, identifier: identifier,
                    productNotes: productNotes.isEmpty ? nil : productNotes,
                    sellerFullName: sellerFullName,
                    sellerIdNumber: sellerIdNumber,
                    sellerMobile: sellerMobile,
                    sellerCity: sellerCity,
                    price: Double(price),
                    sellerTerms: noTerms ? nil : (sellerTerms.isEmpty ? nil : sellerTerms),
                    notes: notes.isEmpty ? nil : notes
                ),
                as: Transaction.self
            )
            withAnimation { step = 3 }
        } catch { errorMessage = error.localizedDescription }
    }
}

// ── Root View ────────────────────────────────────────────────────────────────

struct NewPurchaseView: View {

    @StateObject private var vm = NewPurchaseViewModel()
    @EnvironmentObject var router: TabRouter
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
                        case 1:  NewPurchaseStep1Product(vm: vm)
                        case 2:  NewPurchaseStep2Seller(vm: vm)
                        default: NewPurchaseStep3Pending(vm: vm, router: router, dismiss: dismiss)
                        }
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing),
                                            removal: .move(edge: .leading)))
                    .animation(.easeInOut(duration: 0.25), value: vm.step)
                }
            }
            .navigationTitle("عملية شراء جديدة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.step < 3 {
                        Button("إلغاء") { dismiss() }
                            .foregroundColor(.tSubtext)
                    }
                }
            }
            .sheet(isPresented: $vm.showScanner) {
                BarcodeScannerSheet(scannedCode: $vm.identifier)
            }
        }
    }
}

// ── Step 1: بيانات الجهاز ─────────────────────────────────────────────────────

struct NewPurchaseStep1Product: View {
    @ObservedObject var vm: NewPurchaseViewModel

    let categories = [
        ("smartphone", "هاتف ذكي"),
        ("tablet", "جهاز لوحي"),
        ("laptop", "حاسوب محمول"),
        ("smartwatch", "ساعة ذكية"),
        ("gaming_console", "جهاز ألعاب"),
        ("camera", "كاميرا"),
    ]
    let conditions = [("new", "جديد"), ("used", "مستعمل")]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                FormSectionLabel(title: "بيانات الجهاز", icon: "cube.box")

                VStack(alignment: .leading, spacing: 8) {
                    Text("الفئة").font(.tCaption).foregroundColor(.tSubtext)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.0) { cat in
                                Button { vm.category = cat.0 } label: {
                                    Text(cat.1)
                                        .font(.tCaption)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(vm.category == cat.0 ? Color.tPrimary : Color.tSurface)
                                        .foregroundColor(vm.category == cat.0 ? .white : .tText)
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }
                }

                TField(label: "الماركة", placeholder: "مثال: Apple", text: $vm.brand)
                TField(label: "الموديل", placeholder: "مثال: iPhone 16 Pro", text: $vm.model)

                VStack(alignment: .leading, spacing: 8) {
                    Text("الحالة").font(.tCaption).foregroundColor(.tSubtext)
                    Picker("الحالة", selection: $vm.condition) {
                        ForEach(conditions, id: \.0) { c in Text(c.1).tag(c.0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("معرّف الجهاز (مطلوب)").font(.tCaption).foregroundColor(.tSubtext)
                    Text("IMEI أو الرقم التسلسلي — اطلب من البائع الاتصال بـ *#06#")
                        .font(.tSmall).foregroundColor(.tSubtext.opacity(0.7))

                    HStack(spacing: 10) {
                        TField(label: "", placeholder: "أدخل IMEI أو الرقم التسلسلي", text: $vm.identifier)
                            .onChange(of: vm.identifier) { newVal in
                                if newVal.count > 25 { vm.identifier = String(newVal.prefix(25)) }
                            }
                        Button { vm.showScanner = true } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "barcode.viewfinder").font(.system(size: 22))
                                Text("مسح").font(.tSmall)
                            }
                            .foregroundColor(.tPrimary)
                            .frame(width: 64, height: 56)
                            .background(Color.tPrimary.opacity(0.1))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.tPrimary.opacity(0.3), lineWidth: 1))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("ملاحظات عن الجهاز (اختياري)").font(.tCaption).foregroundColor(.tSubtext)
                    ZStack(alignment: .topLeading) {
                        if vm.productNotes.isEmpty {
                            Text("أي ملاحظات إضافية عن الجهاز...")
                                .font(.tBody).foregroundColor(.tSubtext.opacity(0.5))
                                .padding(.horizontal, 14).padding(.top, 18)
                        }
                        TextEditor(text: $vm.productNotes)
                            .font(.tBody).frame(height: 70)
                            .padding(10).background(Color.clear)
                            .scrollContentBackground(.hidden)
                    }
                    .background(Color.tSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.tBorder, lineWidth: 1))
                }

                Button {
                    withAnimation { vm.step = 2 }
                } label: {
                    Text("التالي: بيانات البائع").tPrimaryButton()
                }
                .disabled(!vm.canSubmitStep1)
                .opacity(vm.canSubmitStep1 ? 1 : 0.6)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
}

// ── Step 2: بيانات البائع والصفقة ────────────────────────────────────────────

private let saudiCities = [
    "الرياض", "جدة", "مكة المكرمة", "المدينة المنورة",
    "الدمام", "الخبر", "الظهران", "الطائف", "بريدة",
    "تبوك", "أبها", "خميس مشيط", "الجبيل", "الأحساء",
    "حائل", "نجران", "جازان", "عرعر", "سكاكا", "الباحة",
]

struct NewPurchaseStep2Seller: View {
    @ObservedObject var vm: NewPurchaseViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

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

                FormSectionLabel(title: "تفاصيل الصفقة", icon: "tag")

                TField(label: "السعر بالريال السعودي (اختياري)",
                       placeholder: "0.00", text: $vm.price)
                    .keyboardType(.decimalPad)

                VStack(alignment: .leading, spacing: 8) {
                    Text("شروط البائع (اختياري)").font(.tCaption).foregroundColor(.tSubtext)

                    if !vm.noTerms {
                        ZStack(alignment: .topLeading) {
                            if vm.sellerTerms.isEmpty {
                                Text("اكتب الشروط هنا...")
                                    .font(.tBody).foregroundColor(.tSubtext.opacity(0.5))
                                    .padding(.horizontal, 14).padding(.top, 18)
                            }
                            TextEditor(text: $vm.sellerTerms)
                                .font(.tBody).frame(height: 90)
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
                    Text("ملاحظات على الصفقة (اختياري)").font(.tCaption).foregroundColor(.tSubtext)
                    ZStack(alignment: .topLeading) {
                        if vm.notes.isEmpty {
                            Text("أي ملاحظات إضافية...")
                                .font(.tBody).foregroundColor(.tSubtext.opacity(0.5))
                                .padding(.horizontal, 14).padding(.top, 18)
                        }
                        TextEditor(text: $vm.notes)
                            .font(.tBody).frame(height: 70)
                            .padding(10).background(Color.clear)
                            .scrollContentBackground(.hidden)
                    }
                    .background(Color.tSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.tBorder, lineWidth: 1))
                }

                HStack(spacing: 8) {
                    Image(systemName: "info.circle").foregroundColor(.tPrimary)
                    Text("سيراجع البائع هذه البيانات عبر رابط تُرسله له لتأكيد البيع.")
                        .font(.tSmall).foregroundColor(.tSubtext)
                }
                .padding(12).background(Color.tPrimary.opacity(0.06)).cornerRadius(10)

                if let error = vm.errorMessage {
                    Text(error).font(.tCaption).foregroundColor(.tDanger)
                        .padding(12).background(Color.tDanger.opacity(0.08)).cornerRadius(8)
                }

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
                            Text("إرسال للبائع للتأكيد").tPrimaryButton()
                        }
                    }
                    .disabled(vm.isLoading || !vm.canSubmitStep2)
                    .opacity(vm.canSubmitStep2 ? 1 : 0.6)
                }
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
}

// ── Step 3: بانتظار موافقة البائع ────────────────────────────────────────────

struct NewPurchaseStep3Pending: View {
    @ObservedObject var vm: NewPurchaseViewModel
    let router: TabRouter
    let dismiss: DismissAction

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                ZStack {
                    Circle().fill(Color.tWarning.opacity(0.1)).frame(width: 100, height: 100)
                    Image(systemName: "clock.fill")
                        .font(.system(size: 52)).foregroundColor(.tWarning)
                }

                VStack(spacing: 8) {
                    Text("بانتظار موافقة البائع").font(.tTitle2).foregroundColor(.tText)
                    Text("تم تسجيل الجهاز وإرسال طلب تأكيد إلى البائع.\nستظهر العملية في قائمة معاملاتي.")
                        .font(.tBody).foregroundColor(.tSubtext)
                        .multilineTextAlignment(.center)
                }

                if let txn = vm.createdTransaction {
                    VStack(spacing: 0) {
                        CompletionRow(label: "الجهاز", value: "\(vm.brand) \(vm.model)")
                        Divider().padding(.leading, 16)
                        CompletionRow(label: "البائع", value: vm.sellerFullName)
                        Divider().padding(.leading, 16)
                        CompletionRow(label: "المدينة", value: vm.sellerCity)
                        if let price = txn.price {
                            Divider().padding(.leading, 16)
                            CompletionRow(label: "السعر", value: String(format: "%.0f ر.س", price))
                        }
                    }
                    .background(Color.tSurface).cornerRadius(12)

                    if let urlStr = txn.confirmUrl, let url = URL(string: urlStr) {
                        ShareLink(item: url,
                                  subject: Text("تأكيد عملية بيع — تواتر"),
                                  message: Text("مرحباً، سجّلت في تطبيق تواتر أنني اشتريت منك جهازك. يرجى فتح الرابط لمراجعة التفاصيل وتأكيد العملية:")) {
                            Label("مشاركة رابط التأكيد مع البائع", systemImage: "square.and.arrow.up")
                                .tPrimaryButton()
                        }
                    }
                }

                Button {
                    router.selectedTab = TabRouter.transactions
                    dismiss()
                } label: {
                    Text("الانتقال إلى معاملاتي").tSecondaryButton()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
    }
}
