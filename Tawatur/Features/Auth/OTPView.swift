// OTPView.swift — 6-digit OTP entry screen (step 2 of auth).
// Six boxes, resend countdown, continues by itself after the sixth digit.
// Login → signs in. Register → identity step, which submits the OTP with the
// name + ID. Design: "رمز التحقق" in UIDesign/gallery.html.

import SwiftUI
import Combine

struct OTPView: View {

    let phone: String
    let purpose: AuthPurpose
    @ObservedObject var vm: AuthViewModel

    @EnvironmentObject var authState: AuthState
    @Environment(\.dismiss) private var dismiss
    @State private var showIdentity = false
    @State private var resendIn = 30
    @FocusState private var focused: Bool

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        AuthScreen(onBack: { dismiss() }) {
            EmptyView()
        } content: {
            AuthStepTitle(title: "أدخل رمز التحقق", subtitle: subtitle)

            OTPBoxes(code: vm.otpCode, isFocused: focused)
                .contentShape(Rectangle())
                .onTapGesture { focused = true }
                .overlay {
                    // The real input: invisible, drives the boxes.
                    TextField("", text: $vm.otpCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($focused)
                        .foregroundStyle(.clear)
                        .tint(.clear)
                        .accessibilityLabel("رمز التحقق")
                }

            HStack {
                Text("لم يصلك الرمز؟").foregroundColor(.tSubtext)
                Spacer()
                if vm.isLoading {
                    ProgressView().tint(.tGreenDeep)
                } else if resendIn > 0 {
                    Text("إعادة الإرسال بعد \(Text(verbatim: String(format: "0:%02d", resendIn)))")
                        .font(.tCaptionBold).foregroundColor(.tSubtext)
                } else {
                    Button("إعادة الإرسال") {
                        vm.otpCode = ""
                        resendIn = 30
                        Task { await vm.requestOTP(phone: phone, purpose: purpose) }
                    }
                    .font(.tCaptionBold).foregroundColor(.tGreenDeep)
                }
            }
            .font(.tCaption)

            // Only when the backend includes the OTP in the response
            // (OTP_EXPOSE_IN_RESPONSE — dev/TestFlight servers, never production).
            if let debug = vm.otpDebug {
                Text("رمز التجربة: \(Text(verbatim: debug).font(.system(.caption, design: .monospaced).bold()))")
                    .font(.tSmall).foregroundColor(.tWarning)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.tWarningBg).clipShape(Capsule())
                    .frame(maxWidth: .infinity)
            }

            if let error = vm.errorMessage { AuthError(message: error) }
        } footer: {
            EmptyView()
        }
        .navigationDestination(isPresented: $showIdentity) {
            IdentityView(mode: .register(phone: phone, otp: vm.otpCode))
        }
        .onChange(of: vm.otpCode) { _, value in
            let clean = String(value.filter(\.isNumber).prefix(6))
            if clean != value { vm.otpCode = clean; return }
            if clean.count == 6 { Task { await submit() } }
        }
        .onReceive(ticker) { _ in if resendIn > 0 { resendIn -= 1 } }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "tawatur-local" else { return .systemAction }
            dismiss()
            return .handled
        })
        .onAppear { focused = true }
    }

    /// "أرسلناه إلى +966 55 812 3941 · تغيير" — "تغيير" goes back to the phone step.
    private var subtitle: Text {
        var phonePart = AttributedString("\u{2066}\(displayPhone)\u{2069}")   // LTR isolate inside Arabic
        phonePart.foregroundColor = .tText
        phonePart.font = .tBodyBold
        var change = AttributedString("تغيير")
        change.link = URL(string: "tawatur-local://change-phone")
        change.font = .tBodyBold
        change.foregroundColor = .tGreenDeep
        return Text(AttributedString("أرسلناه إلى ") + phonePart + AttributedString(" · ") + change)
    }

    /// "0558123941" → "+966 55 812 3941"
    private var displayPhone: String {
        let national = phone.hasPrefix("0") ? String(phone.dropFirst()) : phone
        return "+966 " + PhoneView.grouped(national)
    }

    private func submit() async {
        guard !vm.isLoading else { return }
        if purpose == .login {
            await vm.login(phone: phone, otp: vm.otpCode, authState: authState)
            if vm.errorMessage != nil { vm.otpCode = "" }
        } else {
            showIdentity = true
        }
    }
}

/// Six 48×58 boxes; the next empty one is highlighted with a blinking caret.
struct OTPBoxes: View {
    let code: String
    var isFocused = true

    @State private var caretOn = true

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { i in
                let chars = Array(code)
                let isCurrent = isFocused && i == chars.count
                ZStack {
                    if i < chars.count {
                        Text(verbatim: String(chars[i]))
                            .font(.custom("ReadexPro-SemiBold", size: 24, relativeTo: .title))
                            .foregroundColor(.tText)
                    } else if isCurrent {
                        Rectangle().fill(Color.tGreen).frame(width: 2, height: 24).opacity(caretOn ? 1 : 0)
                    }
                }
                .frame(width: 48, height: 58)
                .background(isCurrent ? Color.tBackground : Color.tSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isCurrent ? Color.tGreen : Color.tBorder, lineWidth: 1.5))
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isCurrent ? Color.tMint : .clear).padding(-4))
            }
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .leftToRight)
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in caretOn.toggle() }
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
