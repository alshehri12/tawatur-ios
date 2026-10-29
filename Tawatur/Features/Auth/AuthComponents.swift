// AuthComponents.swift — Pieces shared by the sign-in screens (phone, OTP,
// identity): the white page with a custom top bar, the big step title, and
// the pinned bottom button. Design: "الدخول والتسجيل" in UIDesign/gallery.html.

import SwiftUI

/// Round 40pt back button on a light fill.
struct AuthBackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.tText)
                .frame(width: 40, height: 40)
                .background(Color.tSurface)
                .clipShape(Circle())
        }
        .accessibilityLabel("رجوع")
    }
}

/// White screen with: top bar (back + centre content), scrollable body and a
/// bottom area that rides above the keyboard.
struct AuthScreen<Center: View, Content: View, Footer: View>: View {
    var onBack: (() -> Void)?
    @ViewBuilder var center: Center
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) { content }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.never)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                if let onBack { AuthBackButton(action: onBack) } else { Color.clear.frame(width: 40, height: 40) }
                Spacer()
                center
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .frame(minHeight: 46)
            .padding(.horizontal, 16)
            .background(Color.tBackground)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) { footer }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(Color.tBackground)
        }
        .background(Color.tBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// "أدخل رقم جوالك" + grey subtitle.
struct AuthStepTitle: View {
    let title: String
    let subtitle: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.tStepTitle).foregroundColor(.tText)
            subtitle.font(.tBody).foregroundColor(.tSubtext)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }
}

/// Red error line shown under a form.
struct AuthError: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
            Text(message).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.tCaption)
        .foregroundColor(.tDanger)
        .padding(12)
        .background(Color.tDangerBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Primary button that swaps its label for a spinner while loading.
struct AuthPrimaryButton: View {
    let title: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView().tint(.white) }
            }
            .tPrimaryButton()
        }
    }
}
