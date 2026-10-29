// Components.swift — Small building blocks shared across screens:
// formatting (Western digits inside Arabic text), device icons, prices,
// status flags, progress bars and the verification badge.

import SwiftUI

// ── Formatting ────────────────────────────────────────────────────────────────

enum TFormat {
    /// Arabic words with Western digits — matches the approved designs ("14 سبتمبر").
    static let locale = Locale(identifier: "ar@numbers=latn")

    private static let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        return f
    }()

    /// 3800 → "3,800"
    static func price(_ value: Double) -> String {
        priceFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    /// "الأحد" within the last week, otherwise "14 سبتمبر".
    static func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
        f.dateFormat = days < 7 ? "EEEE" : "d MMMM"
        return f.string(from: date)
    }

    /// "قبل 12 دقيقة"
    static func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = locale
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: .now)
    }

    /// Time left on a confirm link: "21 ساعة", "4 ساعات", "35 دقيقة", "انتهت".
    static func remaining(until date: Date) -> String {
        let seconds = Int(date.timeIntervalSinceNow)
        guard seconds > 0 else { return "انتهت" }
        let hours = seconds / 3600
        if hours >= 1 { return count(hours, one: "ساعة", two: "ساعتان", few: "ساعات") }
        return count(max(1, seconds / 60), one: "دقيقة", two: "دقيقتان", few: "دقائق")
    }

    /// Arabic counted noun: 1 ساعة · 2 ساعتان · 3–10 ساعات · 11+ ساعة
    private static func count(_ n: Int, one: String, two: String, few: String) -> String {
        switch n {
        case 1:       return one
        case 2:       return two
        case 3...10:  return "\(n) \(few)"
        default:      return "\(n) \(one)"
        }
    }
}

// ── Device icon ───────────────────────────────────────────────────────────────

struct DeviceIcon: View {
    let category: String          // categoryDisplay from the API, e.g. "هاتف ذكي"
    var sold = false
    var size: CGFloat = 52

    private var symbol: String {
        switch category {
        case let c where c.contains("لوحي"):   return "ipad"
        case let c where c.contains("حاسوب"):  return "laptopcomputer"
        case let c where c.contains("ساعة"):   return "applewatch"
        case let c where c.contains("ألعاب"):  return "gamecontroller"
        case let c where c.contains("كاميرا"): return "camera"
        default:                               return "iphone"
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .regular))
            .foregroundColor(sold ? .tSold : .tGreenDeep)
            .frame(width: size, height: size)
            .background(sold ? Color.tSoldBg : Color.tMint)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.31, style: .continuous))
    }
}

// ── Price ─────────────────────────────────────────────────────────────────────

struct PriceText: View {
    let value: Double
    var font: Font = .tAmount

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(TFormat.price(value)).font(font).foregroundColor(.tText)
            Text("ر.س").font(.tSmall).foregroundColor(.tSubtext)
        }
        .fixedSize()
    }
}

// ── Status flag ("يحتاج ردّك") ───────────────────────────────────────────────

struct StatusFlag: View {
    let text: String
    var color: Color = .tWarning
    var background: Color = .tWarningBg

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.tSmall)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(background)
        .clipShape(Capsule())
    }
}

// ── Progress bar (link expiry) ────────────────────────────────────────────────

struct TProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.tSurface)
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "#FFB547"), Color(hex: "#F08C00")],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 6)
    }
}

// ── Section title ─────────────────────────────────────────────────────────────

struct TSectionTitle: View {
    let title: String
    var count: Int? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title).font(.tSection).foregroundColor(.tText)
            if let count, count > 0 {
                Text(verbatim: "\(count)").font(.tCaption).foregroundColor(.tFaint)
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.tCaptionBold)
                    .foregroundColor(.tGreenDeep)
            }
        }
        .padding(.horizontal, 4)
    }
}

// ── Floating tab bar ──────────────────────────────────────────────────────────
// Replaces the system tab bar (hidden in MainTabView). Attached to each tab's
// root screen with .tTabRoot(_:), so it disappears on pushed detail screens.

private struct TTabBar: View {
    let selected: Int
    let onSelect: (Int) -> Void

    private let tabs: [(tag: Int, icon: String, title: String)] = [
        (TabRouter.home,         "house",                  "الرئيسية"),
        (TabRouter.transactions, "arrow.left.arrow.right", "معاملاتي"),
        (TabRouter.certificates, "doc.text",               "شهاداتي"),
        (TabRouter.profile,      "person",                 "حسابي"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tag) { tab in
                let isOn = tab.tag == selected
                Button { onSelect(tab.tag) } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(isOn ? .tGreenDeep : .tFaint)
                            .frame(width: 54, height: 30)
                            .background(isOn ? Color.tMint : .clear)
                            .clipShape(Capsule())
                        Text(tab.title)
                            .font(isOn ? .tSmall.weight(.semibold) : .tSmall)
                            .foregroundColor(isOn ? .tForest : .tFaint)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 68)
        .background(Color.white.opacity(0.88))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.tForest.opacity(0.16), radius: 15, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, -10)   // design: 24pt from the screen edge, slightly into the home-indicator area
    }
}

private struct TTabRoot: ViewModifier {
    let tab: Int
    @EnvironmentObject var router: TabRouter

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            TTabBar(selected: tab) { router.selectedTab = $0 }
        }
    }
}

extension View {
    /// Shows the floating tab bar under a tab's root screen.
    func tTabRoot(_ tab: Int) -> some View { modifier(TTabRoot(tab: tab)) }
}

// ── Status bar style ──────────────────────────────────────────────────────────
// SwiftUI has no per-screen status bar style, so Info.plist turns off
// view-controller-based appearance and screens with a dark header switch the
// app-wide style while they are on screen, restoring dark text when they leave.

private struct TStatusBarStyle: ViewModifier {
    let style: UIStatusBarStyle
    func body(content: Content) -> some View {
        content
            .onAppear { UIApplication.shared.statusBarStyle = style }
            .onDisappear { UIApplication.shared.statusBarStyle = .darkContent }
    }
}

extension View {
    /// Status bar text colour while this screen is visible.
    func tStatusBar(_ style: UIStatusBarStyle) -> some View { modifier(TStatusBarStyle(style: style)) }
}

// ── Verification badge (profile) ──────────────────────────────────────────────

struct VerificationBadge: View {
    let status: String

    private var isVerified: Bool { status == "verified" }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isVerified ? "checkmark.seal.fill" : "clock.fill")
            Text(isVerified ? "موثق" : status == "pending" ? "قيد المراجعة" : "غير موثق")
                .font(.tSmall)
        }
        .foregroundColor(isVerified ? .tGreenDeep : .tWarning)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(isVerified ? Color.tMint : Color.tWarningBg)
        .clipShape(Capsule())
    }
}
