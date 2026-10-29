// OnboardingView.swift — Welcome screen shown to unauthenticated users.
// Green artwork (tilted phone + three trust chips), headline, then routes to
// phone entry. Design: "الترحيب" in UIDesign/gallery.html.

import SwiftUI

struct OnboardingView: View {

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingArt()
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 10) {
                    Text("اشترِ جهازك المستعمل وأنت مطمئن")
                        .font(.custom("ReadexPro-SemiBold", size: 28, relativeTo: .largeTitle))
                        .foregroundColor(.tText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("وثّق كل عملية شراء مع البائع، واحصل على شهادة ملكية باسمك يمكن لأي أحد التحقق منها.")
                        .font(.tBody)
                        .foregroundColor(.tSubtext)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 26)

                HStack(spacing: 6) {
                    Capsule().fill(Color.tForest).frame(width: 24, height: 8)
                    Circle().fill(Color.tBorder).frame(width: 8, height: 8)
                    Circle().fill(Color.tBorder).frame(width: 8, height: 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)

                Spacer(minLength: 12)

                VStack(spacing: 8) {
                    NavigationLink(destination: PhoneView(purpose: .register)) {
                        Text("ابدأ الآن").tPrimaryButton()
                    }
                    NavigationLink(destination: PhoneView(purpose: .login)) {
                        Text("لدي حساب، تسجيل الدخول")
                            .font(.tButton)
                            .foregroundColor(.tGreenDeep)
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                }
                .padding(.horizontal, 16)
            }
            .background(Color.tBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// ── Artwork ───────────────────────────────────────────────────────────────────
// Laid out in physical (left-to-right) coordinates so the chips sit exactly
// where the design puts them, whatever the app's RTL setting.

private struct OnboardingArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [.tForest2, .tForest],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(RadialGradient(colors: [Color.tGreen.opacity(0.35), .clear],
                                     center: UnitPoint(x: 0.3, y: 0.2), startRadius: 0, endRadius: 260))

            MiniPhone()
                .rotationEffect(.degrees(-6))
                .shadow(color: .black.opacity(0.35), radius: 30, y: 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 64)

            TrustChip(icon: "checkmark.shield", title: "هوية موثّقة")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 46).padding(.trailing, 18)
            TrustChip(icon: "key", title: "تأكيد برمز الجوال")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.bottom, 70).padding(.leading, 14)
            TrustChip(icon: "checkmark.seal", title: "شهادة ملكية")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.bottom, 28).padding(.trailing, 30)
        }
        .frame(height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("هوية موثّقة، تأكيد برمز الجوال، شهادة ملكية")
    }
}

private struct MiniPhone: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 26, weight: .regular))
                .foregroundColor(.tGreenDeep)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Color.tMint)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            line(1)
            line(0.6)
            line(1)
            line(0.6)
            Image(systemName: "link")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.tFaint)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Color.tSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(width: 150, height: 270, alignment: .top)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private func line(_ fraction: CGFloat) -> some View {
        GeometryReader { geo in
            Capsule().fill(Color.tBorder).frame(width: geo.size.width * fraction, height: 8)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 8)
    }
}

private struct TrustChip: View {
    let icon: String
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.custom("IBMPlexSansArabic-SemiBold", size: 12.5, relativeTo: .caption))
                .foregroundColor(.tText)
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.tGreenDeep)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 15, y: 14)
    }
}
