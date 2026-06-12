// OTPView.swift — 6-digit OTP entry screen (step 2 of auth).

import SwiftUI

struct OTPView: View {

    let phone: String
    let purpose: AuthPurpose
    @ObservedObject var vm: AuthViewModel

    @EnvironmentObject var authState: AuthState
    @State private var showRegisterDetail = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.tBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("رمز التحقق")
                        .font(.tTitle)
                        .foregroundColor(.tText)
                    Text("تم إرسال رمز مكوّن من 6 أرقام إلى \(phone)")
                        .font(.tBody)
                        .foregroundColor(.tSubtext)
                }
                .padding(.top, 8)

                // DEBUG only — shows OTP returned by dev backend
                #if DEBUG
                if let debug = vm.otpDebug {
                    HStack {
                        Image(systemName: "ant.fill").foregroundColor(.tWarning)
                        Text("رمز التطوير: \(debug)")
                            .font(.tBodyBold)
                            .foregroundColor(.tWarning)
                    }
                    .padding(12)
                    .background(Color.tWarning.opacity(0.1))
                    .cornerRadius(8)
                }
                #endif

                // OTP input
                VStack(alignment: .leading, spacing: 8) {
                    Text("رمز التحقق")
                        .font(.tCaption)
                        .foregroundColor(.tSubtext)

                    TextField("------", text: $vm.otpCode)
                        .keyboardType(.numberPad)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .tracking(12)
                        .focused($focused)
                        .padding(16)
                        .background(Color.tSurface)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(focused ? Color.tPrimary : Color.tBorder, lineWidth: 1.5)
                        )
                        .onChange(of: vm.otpCode) { val in
                            // Limit to 6 digits
                            if val.count > 6 { vm.otpCode = String(val.prefix(6)) }
                        }
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.tCaption)
                        .foregroundColor(.tDanger)
                        .padding(12)
                        .background(Color.tDanger.opacity(0.08))
                        .cornerRadius(8)
                }

                Spacer()

                // Route to registration detail if needed
                NavigationLink(destination: registrationDestination,
                               isActive: $showRegisterDetail) { EmptyView() }

                Button {
                    Task { await handleConfirm() }
                } label: {
                    if vm.isLoading {
                        ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.tPrimary).cornerRadius(10)
                    } else {
                        Text("تأكيد").tPrimaryButton()
                    }
                }
                .disabled(vm.otpCode.count < 6 || vm.isLoading)
                .opacity(vm.otpCode.count < 6 ? 0.6 : 1)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focused = true }
    }

    @ViewBuilder
    private var registrationDestination: some View {
        UserTypeSelectionView(phone: phone, otp: vm.otpCode)
    }

    private func handleConfirm() async {
        if purpose == .login {
            await vm.login(phone: phone, otp: vm.otpCode, authState: authState)
        } else {
            // Go to registration detail screen to collect ID / CR
            showRegisterDetail = true
        }
    }
}

// ── User type selection screen ────────────────────────────────────────────────

struct UserTypeSelectionView: View {

    let phone: String
    let otp: String

    var body: some View {
        ZStack {
            Color.tBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("نوع الحساب")
                        .font(.tTitle)
                        .foregroundColor(.tText)
                    Text("اختر نوع حسابك للمتابعة")
                        .font(.tBody)
                        .foregroundColor(.tSubtext)
                }
                .padding(.top, 16)
                .padding(.bottom, 32)

                VStack(spacing: 16) {
                    NavigationLink(destination: RegistrationDetailView(phone: phone, otp: otp, accountType: "individual")) {
                        UserTypeCard(
                            icon: "person.fill",
                            color: .tPrimary,
                            title: "فرد",
                            subtitle: "مواطن أو مقيم يرغب في بيع أو شراء جهاز"
                        )
                    }

                    NavigationLink(destination: RegistrationDetailView(phone: phone, otp: otp, accountType: "business")) {
                        UserTypeCard(
                            icon: "building.2.fill",
                            color: .tSuccess,
                            title: "محل تجاري",
                            subtitle: "منشأة تجارية مسجلة في وزارة التجارة"
                        )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UserTypeCard: View {

    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.tHeadline)
                    .foregroundColor(.tText)
                Text(subtitle)
                    .font(.tCaption)
                    .foregroundColor(.tSubtext)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.left")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.tSubtext)
        }
        .padding(20)
        .background(Color.tSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.tBorder, lineWidth: 1)
        )
    }
}

// ── Registration detail (collect ID / CR after type selection) ────────────────

struct RegistrationDetailView: View {

    let phone: String
    let otp: String
    let accountType: String   // "individual" or "business" — passed from UserTypeSelectionView

    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject var authState: AuthState

    @State private var nationalId = ""
    @State private var iqama = ""
    @State private var crNumber = ""
    @State private var businessName = ""

    var body: some View {
        ZStack {
            Color.tBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    VStack(alignment: .leading, spacing: 6) {
                        Text(accountType == "individual" ? "بيانات الهوية" : "بيانات المنشأة")
                            .font(.tTitle)
                            .foregroundColor(.tText)
                        Text(accountType == "individual"
                             ? "أدخل رقم هويتك لإتمام التسجيل"
                             : "أدخل بيانات سجلك التجاري لإتمام التسجيل")
                            .font(.tBody)
                            .foregroundColor(.tSubtext)
                    }
                    .padding(.top, 8)

                    if accountType == "individual" {
                        TField(label: "رقم الهوية الوطنية", placeholder: "10 أرقام", text: $nationalId)
                            .keyboardType(.numberPad)
                        Text("أو")
                            .font(.tCaption)
                            .foregroundColor(.tSubtext)
                            .frame(maxWidth: .infinity)
                        TField(label: "رقم الإقامة", placeholder: "10 أرقام", text: $iqama)
                            .keyboardType(.numberPad)
                    } else {
                        TField(label: "رقم السجل التجاري", placeholder: "أدخل رقم السجل التجاري", text: $crNumber)
                            .keyboardType(.numberPad)
                        TField(label: "اسم المنشأة", placeholder: "كما هو في السجل التجاري", text: $businessName)
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.tCaption)
                            .foregroundColor(.tDanger)
                            .padding(12)
                            .background(Color.tDanger.opacity(0.08))
                            .cornerRadius(8)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if vm.isLoading {
                            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.tPrimary).cornerRadius(10)
                        } else {
                            Text("إنشاء الحساب").tPrimaryButton()
                        }
                    }
                    .disabled(vm.isLoading || !isValid)
                    .opacity(isValid ? 1 : 0.6)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isValid: Bool {
        accountType == "individual"
            ? (!nationalId.isEmpty || !iqama.isEmpty)
            : (!crNumber.isEmpty && !businessName.isEmpty)
    }

    private func submit() async {
        if accountType == "individual" {
            await vm.registerIndividual(
                phone: phone, otp: otp,
                nationalId: nationalId.isEmpty ? nil : nationalId,
                iqama: iqama.isEmpty ? nil : iqama,
                authState: authState
            )
        } else {
            await vm.registerBusiness(
                phone: phone, otp: otp,
                crNumber: crNumber, businessName: businessName,
                authState: authState
            )
        }
    }
}

// ── Shared text field component ───────────────────────────────────────────────

struct TField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.tCaption)
                .foregroundColor(.tSubtext)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(.tBody)
                .padding(12)
                .background(Color.tSurface)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.tBorder, lineWidth: 1))
        }
    }
}
