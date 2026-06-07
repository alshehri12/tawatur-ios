// OnboardingView.swift — Welcome screen shown to unauthenticated users.
// Explains the platform, then routes to phone entry.

import SwiftUI

struct OnboardingView: View {

    @State private var showAuth = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tBackground.ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Hero section ──────────────────────────────────────────
                    VStack(spacing: 16) {
                        Spacer(minLength: 60)

                        // Logo
                        ZStack {
                            Circle()
                                .fill(Color.tPrimary.opacity(0.1))
                                .frame(width: 110, height: 110)
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.tPrimary)
                        }

                        Text("تواتر")
                            .font(.tLargeTitle)
                            .foregroundColor(.tPrimary)

                        Text("منصة توثيق الملكية الموثوقة في المملكة العربية السعودية")
                            .font(.tBody)
                            .foregroundColor(.tSubtext)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer()

                    // ── Features list ─────────────────────────────────────────
                    VStack(spacing: 16) {
                        FeatureRow(icon: "person.badge.shield.checkmark",
                                   title: "تحقق من الهوية",
                                   subtitle: "كل مستخدم موثق بهويته الوطنية أو سجله التجاري")

                        FeatureRow(icon: "link.circle.fill",
                                   title: "سلسلة ملكية موثقة",
                                   subtitle: "تتبع تاريخ ملكية أي جهاز بشكل موثوق وشفاف")

                        FeatureRow(icon: "checkmark.seal.fill",
                                   title: "شهادات رقمية",
                                   subtitle: "شهادة ملكية رسمية لكل عملية نقل موثقة")
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // ── CTA buttons ───────────────────────────────────────────
                    VStack(spacing: 12) {
                        NavigationLink(destination: PhoneView(purpose: .register)) {
                            Text("إنشاء حساب جديد")
                                .tPrimaryButton()
                        }

                        NavigationLink(destination: PhoneView(purpose: .login)) {
                            Text("تسجيل الدخول")
                                .tSecondaryButton()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.tPrimary)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.tBodyBold)
                    .foregroundColor(.tText)
                Text(subtitle)
                    .font(.tCaption)
                    .foregroundColor(.tSubtext)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.tSurface)
        .cornerRadius(10)
    }
}
