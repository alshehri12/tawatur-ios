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

                // Shown only when the backend includes the OTP in the response
                // (OTP_EXPOSE_IN_RESPONSE — dev/testing servers only, never production).
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
        // All new accounts register as individuals — business accounts
        // aren't offered during registration for now.
        RegistrationDetailView(phone: phone, otp: vm.otpCode, accountType: "individual")
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

// ── Registration detail (collect national ID / Iqama right after OTP) ────────

struct RegistrationDetailView: View {

    let phone: String
    let otp: String
    let accountType: String   // always "individual" for now — business registration isn't offered

    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject var authState: AuthState

    @State private var fullName = ""
    @State private var nationalId = ""
    @State private var iqama = ""

    var body: some View {
        ZStack {
            Color.tBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    VStack(alignment: .leading, spacing: 6) {
                        Text("بيانات الهوية")
                            .font(.tTitle)
                            .foregroundColor(.tText)
                        Text("هذه البيانات تظهر على الشهادات والعقود عند إتمام أي عملية")
                            .font(.tBody)
                            .foregroundColor(.tSubtext)
                    }
                    .padding(.top, 8)

                    TField(label: "الاسم الكامل", placeholder: "مثال: محمد عبدالله السالم", text: $fullName)

                    TField(label: "رقم الهوية الوطنية", placeholder: "10 أرقام", text: $nationalId)
                        .keyboardType(.numberPad)
                    Text("أو")
                        .font(.tCaption)
                        .foregroundColor(.tSubtext)
                        .frame(maxWidth: .infinity)
                    TField(label: "رقم الإقامة", placeholder: "10 أرقام", text: $iqama)
                        .keyboardType(.numberPad)

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
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && (!nationalId.isEmpty || !iqama.isEmpty)
    }

    private func submit() async {
        await vm.registerIndividual(
            phone: phone, otp: otp, fullName: fullName.trimmingCharacters(in: .whitespaces),
            nationalId: nationalId.isEmpty ? nil : nationalId,
            iqama: iqama.isEmpty ? nil : iqama,
            authState: authState
        )
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
