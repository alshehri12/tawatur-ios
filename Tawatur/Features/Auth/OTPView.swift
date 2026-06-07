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
        RegistrationDetailView(phone: phone, otp: vm.otpCode)
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

// ── Registration detail (collect ID after OTP) ────────────────────────────────

struct RegistrationDetailView: View {

    let phone: String
    let otp: String

    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject var authState: AuthState

    @State private var accountType = "individual"
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
                        Text("بيانات الحساب")
                            .font(.tTitle)
                            .foregroundColor(.tText)
                        Text("اختر نوع حسابك وأدخل بيانات التحقق")
                            .font(.tBody)
                            .foregroundColor(.tSubtext)
                    }
                    .padding(.top, 8)

                    // Account type picker
                    Picker("نوع الحساب", selection: $accountType) {
                        Text("فرد").tag("individual")
                        Text("جهة تجارية").tag("business")
                    }
                    .pickerStyle(.segmented)

                    if accountType == "individual" {
                        TField(label: "رقم الهوية الوطنية", placeholder: "10 أرقام", text: $nationalId)
                            .keyboardType(.numberPad)
                        Text("أو").font(.tCaption).foregroundColor(.tSubtext).frame(maxWidth: .infinity)
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
    }

    private var isValid: Bool {
        if accountType == "individual" {
            return !nationalId.isEmpty || !iqama.isEmpty
        } else {
            return !crNumber.isEmpty && !businessName.isEmpty
        }
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
