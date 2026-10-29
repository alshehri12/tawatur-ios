// Typography.swift — Font scale for تواتر
// Headings use Readex Pro, body text uses IBM Plex Sans Arabic (both bundled in
// Resources/Fonts and registered under UIAppFonts). Sizes scale with Dynamic Type.
// All components use these tokens — never call .font(.system(size: N)) directly.

import SwiftUI

private enum TFace {
    static let display  = "ReadexPro-SemiBold"
    static let displayB = "ReadexPro-Bold"
    static let regular  = "IBMPlexSansArabic-Regular"
    static let medium   = "IBMPlexSansArabic-Medium"
    static let semibold = "IBMPlexSansArabic-SemiBold"
}

extension Font {
    static let tLargeTitle = Font.custom(TFace.displayB, size: 30, relativeTo: .largeTitle)
    static let tTitle      = Font.custom(TFace.display,  size: 24, relativeTo: .title)
    static let tTitle2     = Font.custom(TFace.display,  size: 20, relativeTo: .title2)
    static let tHeadline   = Font.custom(TFace.semibold, size: 17, relativeTo: .headline)
    static let tBody       = Font.custom(TFace.regular,  size: 15, relativeTo: .body)
    static let tBodyBold   = Font.custom(TFace.semibold, size: 15, relativeTo: .body)
    static let tCaption    = Font.custom(TFace.regular,  size: 13, relativeTo: .caption)
    static let tCaptionBold = Font.custom(TFace.semibold, size: 13, relativeTo: .caption)
    static let tSmall      = Font.custom(TFace.medium,   size: 11, relativeTo: .caption2)

    /// Section titles ("بانتظار البائع", "آخر المعاملات").
    static let tSection    = Font.custom(TFace.display,  size: 17, relativeTo: .headline)
    /// Big numbers and amounts (stats on the home band, prices).
    static let tNumber     = Font.custom(TFace.display,  size: 28, relativeTo: .title)
    static let tAmount     = Font.custom(TFace.display,  size: 16, relativeTo: .body)
    /// Big page titles inside screens ("أدخل رقم جوالك").
    static let tStepTitle  = Font.custom(TFace.display,  size: 24, relativeTo: .title)
    /// Text on buttons.
    static let tButton     = Font.custom(TFace.semibold, size: 16, relativeTo: .body)
    /// Text typed into inputs.
    static let tInput      = Font.custom(TFace.regular,  size: 16, relativeTo: .body)
}

// ── Reusable view modifiers ────────────────────────────────────────────────────

extension View {
    /// Style a card container — white background, generous rounded corners.
    func tCard() -> some View {
        self
            .background(Color.tBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// Primary filled button style — greys out when the button is disabled.
    func tPrimaryButton() -> some View { modifier(TPrimaryButtonLook()) }

    /// Input box: 52pt tall, soft fill; green border and mint ring while focused.
    func tInputBox(focused: Bool, height: CGFloat = 52) -> some View {
        self
            .padding(.horizontal, 14)
            .frame(height: height)
            .background(focused ? Color.tBackground : Color.tSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(focused ? Color.tGreen : Color.tBorder, lineWidth: 1.5))
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(focused ? Color.tMint : .clear).padding(-4))
            .animation(.easeOut(duration: 0.15), value: focused)
    }

    /// Secondary soft button style.
    func tSecondaryButton() -> some View {
        self
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(Color.tSurface)
            .foregroundColor(.tPrimary)
            .font(.tBodyBold)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct TPrimaryButtonLook: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(isEnabled ? Color.tPrimary : Color.tBorder)
            .foregroundColor(isEnabled ? .white : .tFaint)
            .font(.tButton)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
