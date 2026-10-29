// NewPurchaseView.swift — "توثيق عملية شراء": the buyer registers the device
// they just bought and names the seller, in one flow:
// الجهاز → البائع → المراجعة → أُرسل الطلب (share the confirm link).
//
// The transaction is created PENDING — the seller reviews and confirms it via
// the shared link (no Tawatur account needed on their side) before the
// certificate is issued.
// Design: "توثيق عملية شراء" in UIDesign/gallery.html.

import SwiftUI
import Combine

// ── ViewModel ────────────────────────────────────────────────────────────────

final class NewPurchaseViewModel: ObservableObject {

    enum IdentifierCheck { case none, checking, free, taken, invalid }

    static let categories: [(code: String, title: String, icon: String)] = [
        ("smartphone",     "هاتف ذكي",    "iphone"),
        ("tablet",         "جهاز لوحي",   "ipad"),
        ("laptop",         "حاسوب محمول", "laptopcomputer"),
        ("smartwatch",     "ساعة ذكية",   "applewatch"),
        ("gaming_console", "جهاز ألعاب",  "gamecontroller"),
        ("camera",         "كاميرا",      "camera"),
    ]
    static let conditions = [("new", "جديد"), ("used", "مستعمل")]

    // Device
    @Published var category = "smartphone"
    @Published var brand = ""
    @Published var model = ""
    @Published var condition = "used"
    @Published var identifier = ""
    @Published var productNotes = ""
    @Published var identifierCheck = IdentifierCheck.none
    /// Off in previews so the sample keeps its "رقم صالح" line without a network call.
    var checksIdentifier = true

    // Seller
    @Published var sellerIdNumber   = ""   // 10 digits
    @Published var sellerFirstName  = ""
    @Published var sellerFatherName = ""
    @Published var sellerFamilyName = ""
    @Published var sellerPhone      = ""   // 9 digits, without the leading 0
    @Published var sellerCity       = ""

    // Review
    @Published var price = ""              // digits only, in riyals
    @Published var sellerTerms = ""
    @Published var noTerms = false
    @Published var notes = ""
    @Published var agreedToTerms = false

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var createdTransaction: Transaction?

    var categoryTitle: String { Self.categories.first { $0.code == category }?.title ?? "" }
    var conditionTitle: String { Self.conditions.first { $0.0 == condition }?.1 ?? "" }
    var deviceName: String { "\(brand.trimmed) \(model.trimmed)" }
    var identifierIsIMEI: Bool { identifier.allSatisfy(\.isNumber) && (14...15).contains(identifier.count) }
    var priceValue: Double? { Double(price) }

    var sellerFullName: String {
        [sellerFirstName, sellerFatherName, sellerFamilyName]
            .map(\.trimmed).filter { !$0.isEmpty }.joined(separator: " ")
    }
    /// "خالد العتيبي"
    var sellerShortName: String {
        [sellerFirstName, sellerFamilyName].map(\.trimmed).filter { !$0.isEmpty }.joined(separator: " ")
    }
    var sellerIdIsValid: Bool {
        sellerIdNumber.count == 10 && (sellerIdNumber.hasPrefix("1") || sellerIdNumber.hasPrefix("2"))
    }
    var sellerPhoneIsValid: Bool { sellerPhone.count == 9 && sellerPhone.hasPrefix("5") }

    var canContinueFromDevice: Bool {
        !brand.trimmed.isEmpty && !model.trimmed.isEmpty && !identifier.isEmpty
            && identifierCheck != .taken && identifierCheck != .invalid
    }
    var canContinueFromSeller: Bool {
        sellerIdIsValid && !sellerFirstName.trimmed.isEmpty && !sellerFamilyName.trimmed.isEmpty
            && sellerPhoneIsValid && !sellerCity.isEmpty
    }

    /// Checks the typed IMEI / serial: checksum first, then whether the device
    /// is already registered to someone (registration would be refused).
    func checkIdentifier() async {
        guard checksIdentifier else { return }
        let id = identifier
        identifierCheck = .none
        let isDigits = id.allSatisfy(\.isNumber)
        if isDigits && id.count < 14 { return }
        if !isDigits && id.count < 6 { return }
        if isDigits && id.count == 15 && !Self.passesLuhn(id) { identifierCheck = .invalid; return }

        try? await Task.sleep(for: .milliseconds(400))   // wait until typing pauses
        guard !Task.isCancelled else { return }
        identifierCheck = .checking
        let lookup: APIEndpoint = identifierIsIMEI ? .productLookup(imei: id) : .productLookup(serial: id)
        do {
            _ = try await APIClient.shared.request(lookup, as: LookupHit.self)
            if id == identifier { identifierCheck = .taken }
        } catch NetworkError.httpError(statusCode: 404, _) {
            if id == identifier { identifierCheck = .free }
        } catch {
            if id == identifier { identifierCheck = .none }
        }
    }

    func submit() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let txn = try await APIClient.shared.request(
                .createRegisteredPurchase(
                    category: category, brand: brand.trimmed, model: model.trimmed,
                    condition: condition, identifier: identifier,
                    productNotes: productNotes.trimmed.isEmpty ? nil : productNotes.trimmed,
                    sellerFullName: sellerFullName,
                    sellerIdNumber: sellerIdNumber,
                    sellerMobile: "0\(sellerPhone)",
                    sellerCity: sellerCity,
                    price: priceValue,
                    sellerTerms: noTerms || sellerTerms.trimmed.isEmpty ? nil : sellerTerms.trimmed,
                    notes: notes.trimmed.isEmpty ? nil : notes.trimmed
                ),
                as: Transaction.self
            )
            withAnimation(.easeInOut(duration: 0.25)) { createdTransaction = txn }
        } catch { errorMessage = error.localizedDescription }
    }

    /// IMEI check digit (Luhn).
    static func passesLuhn(_ digits: String) -> Bool {
        var sum = 0
        for (i, ch) in digits.reversed().enumerated() {
            var n = ch.wholeNumberValue ?? 0
            if i % 2 == 1 { n *= 2; if n > 9 { n -= 9 } }
            sum += n
        }
        return sum % 10 == 0
    }

    private struct LookupHit: Decodable { let id: String }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// ── Root ─────────────────────────────────────────────────────────────────────

enum PurchaseStep: Hashable { case seller, review }

struct NewPurchaseView: View {

    /// Called with the new transaction's id when the buyer taps "عرض الطلب".
    var onOpenTransaction: ((String) -> Void)?

    @StateObject private var vm: NewPurchaseViewModel
    @State private var path: [PurchaseStep]
    @Environment(\.dismiss) private var dismiss

    init(viewModel: NewPurchaseViewModel = NewPurchaseViewModel(),
         startAt path: [PurchaseStep] = [],
         onOpenTransaction: ((String) -> Void)? = nil) {
        _vm = StateObject(wrappedValue: viewModel)
        _path = State(initialValue: path)
        self.onOpenTransaction = onOpenTransaction
    }

    var body: some View {
        ZStack {
            if let txn = vm.createdTransaction {
                PurchaseSentView(vm: vm, transaction: txn,
                                 onOpen: { dismiss(); onOpenTransaction?(txn.id) },
                                 onHome: { dismiss() })
                    .transition(.opacity)
            } else {
                NavigationStack(path: $path) {
                    PurchaseDeviceStep(vm: vm, onClose: { dismiss() }, onNext: { path.append(.seller) })
                        .navigationDestination(for: PurchaseStep.self) { step in
                            switch step {
                            case .seller:
                                PurchaseSellerStep(vm: vm, onBack: { path.removeLast() },
                                                   onClose: { dismiss() }, onNext: { path.append(.review) })
                            case .review:
                                PurchaseReviewStep(vm: vm, onBack: { path.removeLast() }, onClose: { dismiss() },
                                                   onEditDevice: { path = [] }, onEditSeller: { path = [.seller] })
                            }
                        }
                }
            }
        }
    }
}

// ── Step 1: الجهاز ───────────────────────────────────────────────────────────

struct PurchaseDeviceStep: View {
    @ObservedObject var vm: NewPurchaseViewModel
    let onClose: () -> Void
    let onNext: () -> Void

    private enum Field { case brand, model, identifier, notes }
    @FocusState private var focus: Field?
    @State private var showScanner = false
    @State private var showNotes = false

    var body: some View {
        PurchaseStepScreen(step: 0, onClose: onClose) {
            AuthStepTitle(title: "ما الجهاز الذي اشتريته؟",
                          subtitle: Text("هذه البيانات ستظهر في شهادة الملكية."))

            PurchaseCard {
                PurchaseField(label: "الفئة") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(NewPurchaseViewModel.categories, id: \.code) { cat in
                            PurchaseCategoryTile(title: cat.title, icon: cat.icon, isOn: vm.category == cat.code) {
                                vm.category = cat.code
                            }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    PurchaseField(label: "الماركة") {
                        TextField("مثال: Apple", text: $vm.brand)
                            .font(.tInput)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .environment(\.layoutDirection, .leftToRight)
                            .focused($focus, equals: .brand)
                            .submitLabel(.next)
                            .onSubmit { focus = .model }
                            .tInputBox(focused: focus == .brand)
                    }
                    PurchaseField(label: "الموديل") {
                        TextField("مثال: iPhone 15", text: $vm.model)
                            .font(.tInput)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .environment(\.layoutDirection, .leftToRight)
                            .focused($focus, equals: .model)
                            .submitLabel(.next)
                            .onSubmit { focus = .identifier }
                            .tInputBox(focused: focus == .model)
                    }
                }

                PurchaseField(label: "الحالة") {
                    PurchaseSegmented(selection: $vm.condition, options: NewPurchaseViewModel.conditions)
                }
            }

            PurchaseCard {
                PurchaseField(label: "رقم IMEI أو الرقم التسلسلي") {
                    HStack(spacing: 8) {
                        TextField("أدخل الرقم", text: Binding(
                            get: { vm.identifier },
                            set: { vm.identifier = String($0.filter { !$0.isWhitespace }.uppercased().prefix(25)) }
                        ))
                        .font(.tMono)
                        .tracking(0.4)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .identifier)
                        .environment(\.layoutDirection, .leftToRight)
                        .tInputBox(focused: focus == .identifier)

                        Button { showScanner = true } label: {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 21, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 52, height: 52)
                                .background(Color.tForest)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .accessibilityLabel("مسح الباركود")
                    }

                    identifierStatus

                    Text("اطلب من البائع الاتصال بـ \(Text(verbatim: "\u{2066}*#06#\u{2069}").font(.tHintBold).foregroundStyle(Color.tSubtext)) ليظهر الرقم على شاشته.")
                        .font(.tHint)
                        .foregroundColor(.tFaint)
                }

                if showNotes || !vm.productNotes.isEmpty {
                    PurchaseField(label: "ملاحظة عن الجهاز", optional: true) {
                        PurchaseTextArea(placeholder: "مثال: خدش بسيط في الإطار",
                                         text: $vm.productNotes, focused: focus == .notes)
                            .focused($focus, equals: .notes)
                    }
                } else {
                    Button {
                        showNotes = true
                        focus = .notes
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                            Text("إضافة ملاحظة عن الجهاز")
                        }
                        .font(.custom("IBMPlexSansArabic-SemiBold", size: 14, relativeTo: .subheadline))
                        .foregroundColor(.tGreenDeep)
                    }
                    .buttonStyle(.plain)
                }
            }
        } footer: {
            Button(action: onNext) { Text("التالي: بيانات البائع").tPrimaryButton() }
                .disabled(!vm.canContinueFromDevice)
        }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerSheet(scannedCode: $vm.identifier)
        }
        .task(id: vm.identifier) { await vm.checkIdentifier() }
    }

    @ViewBuilder private var identifierStatus: some View {
        switch vm.identifierCheck {
        case .free:
            PurchaseStatusLine(icon: "checkmark", text: "رقم صالح · لم يُسجَّل باسم أحد من قبل", color: .tGreenDeep)
        case .taken:
            PurchaseStatusLine(icon: "exclamationmark.circle", text: "هذا الجهاز مسجّل في تواتر باسم مالك آخر", color: .tDanger)
        case .invalid:
            PurchaseStatusLine(icon: "exclamationmark.circle", text: "رقم IMEI غير صحيح، تأكد منه", color: .tDanger)
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("جارٍ التحقق من الرقم…")
            }
            .font(.tHint).foregroundColor(.tFaint)
        case .none:
            EmptyView()
        }
    }
}

// ── Step 2: البائع ───────────────────────────────────────────────────────────

private let saudiCities = [
    "الرياض", "جدة", "مكة المكرمة", "المدينة المنورة",
    "الدمام", "الخبر", "الظهران", "الطائف", "بريدة",
    "تبوك", "أبها", "خميس مشيط", "الجبيل", "الأحساء",
    "حائل", "نجران", "جازان", "عرعر", "سكاكا", "الباحة",
]

struct PurchaseSellerStep: View {
    @ObservedObject var vm: NewPurchaseViewModel
    let onBack: () -> Void
    let onClose: () -> Void
    let onNext: () -> Void

    private enum Field { case id, first, father, family, phone }
    @FocusState private var focus: Field?

    var body: some View {
        PurchaseStepScreen(step: 1, onBack: onBack, onClose: onClose) {
            AuthStepTitle(title: "من باعك الجهاز؟",
                          subtitle: Text("اكتب البيانات كما في هوية البائع."))

            PurchaseInfo(icon: "key",
                         text: "سيصل للبائع رابط يؤكد منه البيع برمز على جواله. لا يحتاج حساباً في تواتر.")

            PurchaseCard {
                PurchaseField(label: "رقم الهوية الوطنية أو الإقامة") {
                    TextField("1XXX XXX XXX", text: Binding(
                        get: { IdentityView.grouped(vm.sellerIdNumber) },
                        set: { vm.sellerIdNumber = String($0.filter(\.isNumber).prefix(10)) }
                    ))
                    .font(.tMono)
                    .tracking(0.4)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .focused($focus, equals: .id)
                    .environment(\.layoutDirection, .leftToRight)
                    .tInputBox(focused: focus == .id)

                    if vm.sellerIdNumber.count == 10 && !vm.sellerIdIsValid {
                        PurchaseStatusLine(icon: "exclamationmark.circle",
                                           text: "رقم الهوية يبدأ بـ 1 والإقامة بـ 2", color: .tDanger)
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    PurchaseField(label: "الاسم الأول") {
                        TextField("", text: $vm.sellerFirstName)
                            .font(.tInput)
                            .textContentType(.givenName)
                            .focused($focus, equals: .first)
                            .submitLabel(.next)
                            .onSubmit { focus = .father }
                            .tInputBox(focused: focus == .first)
                    }
                    PurchaseField(label: "اسم الأب", optional: true) {
                        TextField("", text: $vm.sellerFatherName)
                            .font(.tInput)
                            .focused($focus, equals: .father)
                            .submitLabel(.next)
                            .onSubmit { focus = .family }
                            .tInputBox(focused: focus == .father)
                    }
                }

                PurchaseField(label: "اسم العائلة") {
                    TextField("", text: $vm.sellerFamilyName)
                        .font(.tInput)
                        .textContentType(.familyName)
                        .focused($focus, equals: .family)
                        .submitLabel(.next)
                        .onSubmit { focus = .phone }
                        .tInputBox(focused: focus == .family)
                }
            }

            PurchaseCard {
                PurchaseField(label: "رقم جوال البائع") {
                    HStack(spacing: 8) {
                        Text(verbatim: "🇸🇦 +966")
                            .font(.custom("IBMPlexSansArabic-SemiBold", size: 15, relativeTo: .body))
                            .foregroundColor(.tText)
                            .padding(.horizontal, 12)
                            .frame(height: 52)
                            .background(Color.tSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.tBorder, lineWidth: 1.5))

                        TextField("5X XXX XXXX", text: Binding(
                            get: { PhoneView.grouped(vm.sellerPhone) },
                            set: { vm.sellerPhone = PhoneView.cleaned($0) }
                        ))
                        .font(.tMono)
                        .tracking(0.4)
                        .keyboardType(.numberPad)
                        .focused($focus, equals: .phone)
                        .tInputBox(focused: focus == .phone)
                    }
                    .environment(\.layoutDirection, .leftToRight)

                    Text("الجوال الذي سيستقبل رمز التأكيد.")
                        .font(.tHint).foregroundColor(.tFaint)
                }

                PurchaseField(label: "المدينة") {
                    Menu {
                        ForEach(saudiCities, id: \.self) { city in
                            Button(city) { vm.sellerCity = city }
                        }
                    } label: {
                        HStack {
                            Text(vm.sellerCity.isEmpty ? "اختر المدينة" : vm.sellerCity)
                                .font(.tInput)
                                .foregroundStyle(vm.sellerCity.isEmpty ? Color.tFaint : Color.tText)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.tSubtext)
                        }
                        .tInputBox(focused: false)
                    }
                }
            }
        } footer: {
            PurchaseFootBackButton(action: onBack)
            Button(action: onNext) { Text("التالي: المراجعة").tPrimaryButton() }
                .disabled(!vm.canContinueFromSeller)
        }
    }
}

// ── Step 3: المراجعة والإرسال ────────────────────────────────────────────────

struct PurchaseReviewStep: View {
    @ObservedObject var vm: NewPurchaseViewModel
    let onBack: () -> Void
    let onClose: () -> Void
    let onEditDevice: () -> Void
    let onEditSeller: () -> Void

    private enum Field { case price, terms, notes }
    @FocusState private var focus: Field?
    @State private var showTerms = false

    var body: some View {
        PurchaseStepScreen(step: 2, onBack: onBack, onClose: onClose) {
            AuthStepTitle(title: "راجع قبل الإرسال",
                          subtitle: Text("سيرى البائع هذه البيانات نفسها في رابط التأكيد."))

            PurchaseCard {
                PurchaseField(label: "السعر المتفق عليه") {
                    HStack(spacing: 8) {
                        TextField("0", text: Binding(
                            get: { vm.priceValue.map(TFormat.price) ?? "" },
                            set: { vm.price = String($0.filter(\.isNumber).prefix(7)) }
                        ))
                        .font(.custom("ReadexPro-SemiBold", size: 22, relativeTo: .title2))
                        .multilineTextAlignment(.trailing)
                        .environment(\.layoutDirection, .leftToRight)
                        .keyboardType(.numberPad)
                        .focused($focus, equals: .price)
                        Text("ر.س")
                            .font(.custom("IBMPlexSansArabic-Medium", size: 14, relativeTo: .subheadline))
                            .foregroundColor(.tSubtext)
                    }
                    .tInputBox(focused: focus == .price, height: 60)
                }

                PurchaseField(label: "الشروط الخاصة", optional: true) {
                    if !vm.noTerms {
                        PurchaseTextArea(placeholder: "مثال: ضمان أسبوع على البطارية",
                                         text: $vm.sellerTerms, focused: focus == .terms)
                            .focused($focus, equals: .terms)
                    }
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            vm.noTerms.toggle()
                            if vm.noTerms { vm.sellerTerms = ""; focus = nil }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            PurchaseCheckBox(isOn: vm.noTerms)
                            Text("لا توجد شروط")
                                .font(.custom("IBMPlexSansArabic-Regular", size: 14, relativeTo: .subheadline))
                                .foregroundColor(.tText)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(vm.noTerms ? .isSelected : [])
                }

                PurchaseField(label: "ملاحظات على الصفقة", optional: true) {
                    PurchaseTextArea(placeholder: "أي تفاصيل أخرى اتفقتما عليها",
                                     text: $vm.notes, focused: focus == .notes)
                        .focused($focus, equals: .notes)
                }
            }

            PurchaseCard {
                PurchaseReviewHead(title: "الجهاز", onEdit: onEditDevice)
                VStack(spacing: 0) {
                    PurchaseKVRow(label: "الجهاز", value: vm.deviceName)
                    PurchaseKVRow(label: "الحالة", value: vm.conditionTitle)
                    PurchaseKVRow(label: vm.identifierIsIMEI ? "IMEI" : "الرقم التسلسلي", value: ltr(vm.identifier))
                    if !vm.productNotes.trimmed.isEmpty {
                        PurchaseKVRow(label: "ملاحظة", value: vm.productNotes.trimmed)
                    }
                }
            }

            PurchaseCard {
                PurchaseReviewHead(title: "البائع", onEdit: onEditSeller)
                VStack(spacing: 0) {
                    PurchaseKVRow(label: "الاسم", value: vm.sellerFullName)
                    PurchaseKVRow(label: "الهوية", value: ltr(maskedId))
                    PurchaseKVRow(label: "الجوال", value: ltr("+966 \(PhoneView.grouped(vm.sellerPhone))"))
                    PurchaseKVRow(label: "المدينة", value: vm.sellerCity)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                PurchaseCheckBox(isOn: vm.agreedToTerms)
                    .padding(.top, 1)
                Text(termsText)
                    .font(.custom("IBMPlexSansArabic-Regular", size: 14, relativeTo: .subheadline))
                    .foregroundColor(.tText)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(2)
            .contentShape(Rectangle())
            .onTapGesture { vm.agreedToTerms.toggle() }
            .environment(\.openURL, OpenURLAction { _ in showTerms = true; return .handled })
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(vm.agreedToTerms ? [.isButton, .isSelected] : .isButton)

            if let error = vm.errorMessage { AuthError(message: error) }
        } footer: {
            PurchaseFootBackButton(action: onBack)
            AuthPrimaryButton(title: "إرسال للبائع للتأكيد", isLoading: vm.isLoading) {
                focus = nil
                Task { await vm.submit() }
            }
            .disabled(!vm.agreedToTerms || vm.isLoading)
        }
        .sheet(isPresented: $showTerms) { TermsSheet() }
    }

    /// "1087••••21"
    private var maskedId: String {
        let id = vm.sellerIdNumber
        guard id.count == 10 else { return id }
        return "\(id.prefix(4))••••\(id.suffix(2))"
    }

    private var termsText: AttributedString {
        var text = AttributedString("أقرّ بصحة البيانات وأوافق على ")
        var link = AttributedString("الشروط والأحكام")
        link.link = URL(string: "tawatur-local://terms")
        link.foregroundColor = .tGreenDeep
        link.font = .custom("IBMPlexSansArabic-SemiBold", size: 14, relativeTo: .subheadline)
        text.append(link)
        return text
    }
}

// ── Done: أُرسل الطلب ─────────────────────────────────────────────────────────

struct PurchaseSentView: View {
    @ObservedObject var vm: NewPurchaseViewModel
    let transaction: Transaction
    let onOpen: () -> Void
    let onHome: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.tGreen.opacity(0.22)).frame(width: 84, height: 84)
                        Circle().fill(Color.tGreen).frame(width: 60, height: 60)
                        Image(systemName: "checkmark")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("أُرسل الطلب")
                        .font(.custom("ReadexPro-SemiBold", size: 26, relativeTo: .title))
                        .foregroundColor(.white)
                        .baselineOffset(-6)        // room for the damma; SwiftUI clips marks above the font's ascent
                        .padding(.top, 6)
                    Text("بقيت خطوة واحدة: أرسل الرابط ل\(vm.sellerFirstName.trimmed) ليؤكد البيع، وتصدر شهادتك فوراً.")
                        .font(.custom("IBMPlexSansArabic-Regular", size: 14.5, relativeTo: .subheadline))
                        .foregroundColor(Color(hex: "#B9D3C8"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .frame(maxWidth: 270)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 33)
                .padding(.bottom, 24)

                card.padding(.horizontal, 16)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                Button(action: onOpen) {
                    Text("عرض الطلب")
                        .font(.tButton)
                        .foregroundColor(.tForest)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                Button(action: onHome) {
                    Text("العودة للرئيسية")
                        .font(.tButton)
                        .foregroundColor(Color(hex: "#CFE6DC"))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(PurchaseForestBackground().ignoresSafeArea())
        .tStatusBar(.lightContent)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                DeviceIcon(category: vm.categoryTitle, size: 44)
                VStack(alignment: .leading, spacing: 0) {
                    Text(vm.model.trimmed).font(.tBodyBold).foregroundColor(.tText)
                    Text("من \(vm.sellerShortName)")
                        .font(.custom("IBMPlexSansArabic-Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(.tFaint)
                }
                Spacer(minLength: 8)
                if let price = transaction.price ?? vm.priceValue {
                    PriceText(value: price, font: .custom("ReadexPro-SemiBold", size: 17, relativeTo: .body))
                }
            }

            if let link = transaction.confirmUrl {
                HStack(spacing: 8) {
                    Text(verbatim: Self.displayLink(link))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.tText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Button {
                        UIPasteboard.general.string = link
                        withAnimation(.easeOut(duration: 0.15)) { copied = true }
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { copied = false }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12, weight: .semibold))
                            Text(copied ? "تم النسخ" : "نسخ")
                        }
                        .font(.tCaptionBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(copied ? Color.tGreen : Color.tForest)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
                .padding(.leading, 14)
                .padding(.trailing, 6)
                .background(Color.tSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    if let url = whatsAppURL(link: link) { openURL(url) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "message").font(.system(size: 16, weight: .medium))
                        Text("إرسال عبر واتساب")
                    }
                    .font(.custom("IBMPlexSansArabic-SemiBold", size: 15, relativeTo: .body))
                    .foregroundColor(Color(hex: "#128C4A"))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color(hex: "#E7F8EE"))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.tBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// "https://tawatur.sa/confirm/7f3c2a91/" → "tawatur.sa/confirm/7f3c2a91"
    static func displayLink(_ link: String) -> String {
        var s = link
        for prefix in ["https://", "http://"] where s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
        if s.hasSuffix("/") { s.removeLast() }
        return s
    }

    /// Opens a WhatsApp chat with the seller, pre-filled with the confirm link.
    private func whatsAppURL(link: String) -> URL? {
        let message = "مرحباً \(vm.sellerFirstName.trimmed)، وثّقت في تطبيق تواتر شرائي منك \(vm.deviceName). افتح الرابط لمراجعة البيانات وتأكيد البيع:\n\(link)"
        var components = URLComponents(string: "https://wa.me/966\(vm.sellerPhone)")
        components?.queryItems = [URLQueryItem(name: "text", value: message)]
        return components?.url
    }
}

/// Forest green with a soft glow in the top-left corner (the "تم" screens).
private struct PurchaseForestBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(stops: [.init(color: .tForest2, location: 0), .init(color: .tForest, location: 0.6)],
                               startPoint: UnitPoint(x: 0.3, y: -0.025), endPoint: UnitPoint(x: 0.7, y: 1.025))
                EllipticalGradient(colors: [Color.tGreen.opacity(0.32), Color.tGreen.opacity(0)],
                                   center: .center, endRadiusFraction: 0.55)
                    .frame(width: geo.size.width * 2.4, height: geo.size.height * 1.4)
                    .position(x: 0, y: 0)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

// ── Shared pieces ────────────────────────────────────────────────────────────

/// Step screen: top bar (back / title / close), 3-part progress, scrollable
/// cards and a pinned footer. Light page background.
private struct PurchaseStepScreen<Content: View, Footer: View>: View {
    let step: Int
    var onBack: (() -> Void)?
    let onClose: () -> Void
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    private let titles = ["الجهاز", "البائع", "المراجعة"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) { content }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    if let onBack {
                        PurchaseRoundButton(icon: "chevron.backward", label: "رجوع", action: onBack)
                    } else {
                        Color.clear.frame(width: 40, height: 40)
                    }
                    Spacer()
                    Text("توثيق عملية شراء").font(.tButton).foregroundColor(.tText)
                    Spacer()
                    PurchaseRoundButton(icon: "xmark", label: "إغلاق", action: onClose)
                }
                .frame(minHeight: 46)
                .padding(.horizontal, 16)
                .padding(.top, 3)

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(i <= step ? Color.tGreen : Color.tBorder)
                                .frame(height: 5)
                            Text(titles[i])
                                .font(.custom(i == step ? "IBMPlexSansArabic-SemiBold" : "IBMPlexSansArabic-Medium",
                                              size: 12, relativeTo: .caption))
                                .foregroundColor(i < step ? .tGreenDeep : i == step ? .tText : .tFaint)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("الخطوة \(step + 1) من 3: \(titles[step])")
            }
            .background(Color.tSurface)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 10) { footer }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .background(Color.tSurface)
                .overlay(alignment: .top) { Rectangle().fill(Color.tBorder).frame(height: 1) }
        }
        .background(Color.tSurface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .tStatusBar(.darkContent)
    }
}

/// 40pt white circle in the top bar.
private struct PurchaseRoundButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.tText)
                .frame(width: 40, height: 40)
                .background(Color.tBackground)
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
    }
}

/// Square 54pt "previous step" button next to the main footer button.
private struct PurchaseFootBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.tText)
                .frame(width: 54, height: 54)
                .background(Color.tBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .accessibilityLabel("السابق")
    }
}

private struct PurchaseCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.tBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Grey label above an input.
private struct PurchaseField<Content: View>: View {
    let label: String
    var optional = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) {
                Text(label).font(.tCaptionBold).foregroundColor(.tSubtext)
                if optional {
                    Text("(اختياري)")
                        .font(.custom("IBMPlexSansArabic-Medium", size: 13, relativeTo: .caption))
                        .foregroundColor(.tFaint)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PurchaseCategoryTile: View {
    let title: String
    let icon: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .regular))
                    .frame(height: 24)
                Text(title)
                    .font(.custom(isOn ? "IBMPlexSansArabic-SemiBold" : "IBMPlexSansArabic-Medium",
                                  size: 12.5, relativeTo: .caption))
            }
            .foregroundColor(isOn ? .tGreenDeep : .tSubtext)
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .background(isOn ? Color.tMint : Color.tSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isOn ? Color.tGreen : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Two-option switch ("جديد / مستعمل").
private struct PurchaseSegmented: View {
    @Binding var selection: String
    let options: [(String, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { option in
                let isOn = option.0 == selection
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = option.0 }
                } label: {
                    Text(option.1)
                        .font(.custom(isOn ? "IBMPlexSansArabic-SemiBold" : "IBMPlexSansArabic-Medium",
                                      size: 14.5, relativeTo: .subheadline))
                        .foregroundColor(isOn ? .tText : .tSubtext)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background {
                            if isOn {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color.tBackground)
                                    .shadow(color: Color.tForest.opacity(0.08), radius: 4, y: 2)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.tSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Small coloured line under an input ("رقم صالح …").
private struct PurchaseStatusLine: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11.5, weight: .bold))
            Text(text)
        }
        .font(.custom("IBMPlexSansArabic-SemiBold", size: 12.5, relativeTo: .caption))
        .foregroundColor(color)
    }
}

/// 24pt rounded checkbox: grey outline, green fill with a tick when on.
private struct PurchaseCheckBox: View {
    let isOn: Bool

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .heavy))
            .foregroundColor(isOn ? .white : .clear)
            .frame(width: 24, height: 24)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isOn ? Color.tGreen : .clear))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isOn ? Color.tGreen : Color.tFaint, lineWidth: 2))
    }
}

/// 80pt multi-line input (notes, terms).
private struct PurchaseTextArea: View {
    let placeholder: String
    @Binding var text: String
    let focused: Bool

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .font(.tInput)
            .lineLimit(2...4)
            .padding(.vertical, 12)
            .frame(maxHeight: .infinity, alignment: .top)
            .tInputBox(focused: focused, height: 80)
    }
}

/// Mint note with an icon.
private struct PurchaseInfo: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.tGreenDeep)
                .padding(.top, 3)
            Text(text).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.custom("IBMPlexSansArabic-Regular", size: 13.5, relativeTo: .footnote))
        .foregroundColor(.tForest)
        .lineSpacing(3)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.tMint)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// "✓ الجهاز ............ تعديل"
private struct PurchaseReviewHead: View {
    let title: String
    let onEdit: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.tGreen)
                    .clipShape(Circle())
                Text(title).font(.tBodyBold).foregroundColor(.tText)
            }
            Spacer()
            Button("تعديل", action: onEdit)
                .font(.tCaptionBold)
                .foregroundColor(.tGreenDeep)
        }
    }
}

/// Label on the right, value on the left, hairline above.
private struct PurchaseKVRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).foregroundColor(.tSubtext)
            Spacer(minLength: 12)
            Text(verbatim: value)
                .font(.custom("IBMPlexSansArabic-SemiBold", size: 14, relativeTo: .subheadline))
                .foregroundColor(.tText)
                .multilineTextAlignment(.trailing)
        }
        .font(.custom("IBMPlexSansArabic-Regular", size: 14, relativeTo: .subheadline))
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(Color.tBorder).frame(height: 1) }
    }
}

/// Keeps "+966 55 …" and IMEI digits in left-to-right order inside Arabic text.
private func ltr(_ s: String) -> String { "\u{2066}\(s)\u{2069}" }

private extension Font {
    static let tMono     = Font.system(size: 15, design: .monospaced)
    static let tHint     = Font.custom("IBMPlexSansArabic-Regular", size: 12, relativeTo: .caption)
    static let tHintBold = Font.custom("IBMPlexSansArabic-SemiBold", size: 12, relativeTo: .caption)
}
