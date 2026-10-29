// IdentityView.swift — "عرّفنا بنفسك": full name + national ID / Iqama.
// Used in two places:
//   • register — last step of sign-up; submits phone + OTP + identity together.
//   • verify   — signed-in individual who hasn't submitted identity yet
//                (shown by VerificationGateView).
// Nafath is shown as "قريباً" until the integration exists.
// Design: "التحقق من الهوية" in UIDesign/gallery.html.

import SwiftUI

struct IdentityView: View {

    enum Mode {
        case register(phone: String, otp: String)
        case verify
    }

    let mode: Mode

    @EnvironmentObject var authState: AuthState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var verifyVM = VerificationViewModel()
    @State private var fullName = ""
    @State private var idNumber = ""
    @FocusState private var focus: Field?

    private enum Field { case name, id }

    private var isRegister: Bool { if case .register = mode { return true } else { return false } }
    private var isLoading: Bool { authVM.isLoading || verifyVM.isLoading }
    private var errorMessage: String? { authVM.errorMessage ?? verifyVM.errorMessage }

    /// Saudi national IDs start with 1, Iqamas with 2 — both are 10 digits.
    private var idIsValid: Bool {
        idNumber.count == 10 && (idNumber.hasPrefix("1") || idNumber.hasPrefix("2"))
    }
    private var canSubmit: Bool {
        fullName.trimmingCharacters(in: .whitespaces).split(separator: " ").count >= 2 && idIsValid
    }

    var body: some View {
        AuthScreen(onBack: isRegister ? { dismiss() } : nil) {
            Text("خطوة أخيرة").font(.tCaption).foregroundColor(.tSubtext)
        } content: {
            AuthStepTitle(title: "عرّفنا بنفسك",
                          subtitle: Text("نحتاجها لتظهر في شهادات الملكية. تُحفظ مشفّرة."))

            nafathCard

            HStack(spacing: 12) {
                Rectangle().fill(Color.tBorder).frame(height: 1)
                Text("أو أدخل بياناتك").font(.tSmall).foregroundColor(.tFaint).fixedSize()
                Rectangle().fill(Color.tBorder).frame(height: 1)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("الاسم الكامل كما في الهوية").font(.tCaptionBold).foregroundColor(.tSubtext)
                TextField("مثال: محمد عبدالله السالم", text: $fullName)
                    .font(.tInput)
                    .textContentType(.name)
                    .focused($focus, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focus = .id }
                    .tInputBox(focused: focus == .name)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("رقم الهوية الوطنية أو الإقامة").font(.tCaptionBold).foregroundColor(.tSubtext)
                TextField("1XXX XXX XXX", text: Binding(
                    get: { Self.grouped(idNumber) },
                    set: { idNumber = String($0.filter(\.isNumber).prefix(10)) }
                ))
                .font(.system(size: 15, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .focused($focus, equals: .id)
                .environment(\.layoutDirection, .leftToRight)
                .tInputBox(focused: focus == .id)

                if idIsValid {
                    Label("رقم صالح", systemImage: "checkmark")
                        .font(.tCaptionBold).foregroundColor(.tGreenDeep)
                } else if idNumber.count == 10 {
                    Text("رقم الهوية يبدأ بـ 1 والإقامة بـ 2")
                        .font(.tCaptionBold).foregroundColor(.tDanger)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock").foregroundColor(.tGreenDeep)
                Text("بياناتك مشفّرة ولا يراها أحد إلا طرف المعاملة في الشهادة.")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.custom("IBMPlexSansArabic-Regular", size: 13.5, relativeTo: .footnote))
            .foregroundColor(.tForest)
            .lineSpacing(3)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color.tMint)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let errorMessage { AuthError(message: errorMessage) }
        } footer: {
            AuthPrimaryButton(title: "متابعة", isLoading: isLoading) {
                Task { await submit() }
            }
            .disabled(!canSubmit || isLoading)

            if !isRegister {
                Button("تسجيل الخروج") { Task { await authState.logout() } }
                    .font(.tCaption).foregroundColor(.tSubtext)
                    .frame(minHeight: 32)
            }
        }
        .onAppear { focus = .name }
    }

    private var nafathCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 20)).foregroundColor(.tForest)
                .frame(width: 44, height: 44)
                .background(Color.tSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text("التحقق عبر نفاذ").font(.tBodyBold).foregroundColor(.tText)
                Text("أسرع وأوثق · متاح قريباً").font(.tSmall).foregroundColor(.tFaint)
            }
            Spacer()
            Text("قريباً")
                .font(.tSmall).foregroundColor(.tSubtext)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.tSurface).clipShape(Capsule())
        }
        .padding(16)
        .background(Color.tBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.tBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        .opacity(0.75)
        .accessibilityElement(children: .combine)
        .accessibilityHint("غير متاح بعد")
    }

    /// 1098765432 → "1098 765 432"
    static func grouped(_ d: String) -> String {
        var out = ""
        for (i, ch) in d.enumerated() {
            if i == 4 || i == 7 { out.append(" ") }
            out.append(ch)
        }
        return out
    }

    private func submit() async {
        let name = fullName.trimmingCharacters(in: .whitespaces)
        let nationalId = idNumber.hasPrefix("1") ? idNumber : nil
        let iqama = idNumber.hasPrefix("2") ? idNumber : nil
        switch mode {
        case .register(let phone, let otp):
            await authVM.registerIndividual(phone: phone, otp: otp, fullName: name,
                                            nationalId: nationalId, iqama: iqama, authState: authState)
        case .verify:
            await verifyVM.submitIndividual(fullName: name, nationalId: nationalId, iqama: iqama,
                                            authState: authState)
        }
    }
}
