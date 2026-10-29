// PhoneView.swift — Phone number entry screen (step 1 of auth).
// Design: "رقم الجوال" in UIDesign/gallery.html.

import SwiftUI

struct PhoneView: View {

    let purpose: AuthPurpose

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AuthViewModel()
    @State private var digits = ""          // national number without the leading 0, e.g. 558123941
    @FocusState private var focused: Bool

    var body: some View {
        AuthScreen(onBack: { dismiss() }) {
            Image("TawaturMark")
                .resizable().scaledToFit()
                .frame(height: 34)
                .accessibilityLabel("تواتر")
        } content: {
            AuthStepTitle(title: "أدخل رقم جوالك",
                          subtitle: Text("سنرسل لك رمز تحقق. لا تحتاج كلمة مرور."))

            HStack(spacing: 8) {
                Text(verbatim: "🇸🇦 +966")
                    .font(.tButton)
                    .foregroundColor(.tText)
                    .padding(.horizontal, 12)
                    .frame(height: 52)
                    .background(Color.tSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.tBorder, lineWidth: 1.5))

                TextField("5X XXX XXXX", text: Binding(
                    get: { Self.grouped(digits) },
                    set: { digits = Self.cleaned($0) }
                ))
                .font(.system(size: 17, design: .monospaced))
                .keyboardType(.numberPad)
                .textContentType(.telephoneNumber)
                .focused($focused)
                .tInputBox(focused: focused)
            }
            .environment(\.layoutDirection, .leftToRight)

            if let error = vm.errorMessage { AuthError(message: error) }

            Text("بالمتابعة توافق على \(Text("الشروط والأحكام").bold().foregroundStyle(Color.tSubtext)) و\(Text("سياسة الخصوصية").bold().foregroundStyle(Color.tSubtext))")
                .font(.custom("IBMPlexSansArabic-Regular", size: 12, relativeTo: .caption))
                .foregroundColor(.tFaint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        } footer: {
            AuthPrimaryButton(title: "إرسال الرمز", isLoading: vm.isLoading) {
                Task { await vm.requestOTP(phone: normalizedPhone, purpose: purpose) }
            }
            .disabled(digits.count < 9 || vm.isLoading)
        }
        .navigationDestination(isPresented: $vm.otpSent) {
            OTPView(phone: normalizedPhone, purpose: purpose, vm: vm)
        }
        .onAppear { focused = true }
    }

    /// "0558123941" — the format the backend expects.
    private var normalizedPhone: String { "0\(digits)" }

    /// Keep digits only, drop a typed leading 0 (or 966), max 9 digits.
    static func cleaned(_ text: String) -> String {
        var d = text.filter(\.isNumber)
        if d.hasPrefix("966") { d.removeFirst(3) }
        if d.hasPrefix("0") { d.removeFirst() }
        return String(d.prefix(9))
    }

    /// 558123941 → "55 812 3941"
    static func grouped(_ d: String) -> String {
        var out = ""
        for (i, ch) in d.enumerated() {
            if i == 2 || i == 5 { out.append(" ") }
            out.append(ch)
        }
        return out
    }
}
