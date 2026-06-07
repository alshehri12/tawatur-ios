// PhoneView.swift — Phone number entry screen (step 1 of auth).

import SwiftUI

struct PhoneView: View {

    let purpose: AuthPurpose

    @StateObject private var vm = AuthViewModel()
    @State private var phone = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.tBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 6) {
                    Text(purpose == .login ? "تسجيل الدخول" : "إنشاء حساب")
                        .font(.tTitle).foregroundColor(.tText)
                    Text("أدخل رقم جوالك للمتابعة")
                        .font(.tBody).foregroundColor(.tSubtext)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("رقم الجوال").font(.tCaption).foregroundColor(.tSubtext)

                    HStack(spacing: 10) {
                        Text("🇸🇦 +966")
                            .font(.tBody).foregroundColor(.tSubtext)
                            .padding(.horizontal, 12).padding(.vertical, 14)
                            .background(Color.tSurface).cornerRadius(10)

                        TextField("05XXXXXXXX", text: $phone)
                            .keyboardType(.phonePad)
                            .font(.tBody)
                            .focused($focused)
                            .padding(.horizontal, 12).padding(.vertical, 14)
                            .background(Color.tSurface).cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(focused ? Color.tPrimary : Color.tBorder, lineWidth: 1.5)
                            )
                    }
                }

                if let error = vm.errorMessage {
                    Text(error).font(.tCaption).foregroundColor(.tDanger)
                        .padding(12).background(Color.tDanger.opacity(0.08)).cornerRadius(8)
                }

                Spacer()

                NavigationLink(
                    destination: OTPView(phone: normalizedPhone, purpose: purpose, vm: vm),
                    isActive: $vm.otpSent
                ) { EmptyView() }

                Button {
                    Task { await vm.requestOTP(phone: normalizedPhone, purpose: purpose) }
                } label: {
                    if vm.isLoading {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                            .padding(.vertical, 14).background(Color.tPrimary).cornerRadius(10)
                    } else {
                        Text("إرسال رمز التحقق").tPrimaryButton()
                    }
                }
                .disabled(phone.count < 9 || vm.isLoading)
                .opacity(phone.count < 9 ? 0.6 : 1)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focused = true }
    }

    private var normalizedPhone: String {
        let stripped = phone.replacingOccurrences(of: " ", with: "")
        if stripped.hasPrefix("5") { return "0\(stripped)" }
        return stripped
    }
}
