// Typography.swift — Font scale for تواتر
// Uses the system Arabic font (San Francisco Arabic) via .font(.system(...))
// All components use these tokens — never call .font(.system(size: N)) directly.

import SwiftUI

extension Font {
    static let tLargeTitle = Font.system(size: 30, weight: .bold,  design: .default)
    static let tTitle      = Font.system(size: 24, weight: .bold,  design: .default)
    static let tTitle2     = Font.system(size: 20, weight: .semibold, design: .default)
    static let tHeadline   = Font.system(size: 17, weight: .semibold, design: .default)
    static let tBody       = Font.system(size: 15, weight: .regular, design: .default)
    static let tBodyBold   = Font.system(size: 15, weight: .semibold, design: .default)
    static let tCaption    = Font.system(size: 13, weight: .regular, design: .default)
    static let tSmall      = Font.system(size: 11, weight: .regular, design: .default)
}

// ── Reusable view modifiers ────────────────────────────────────────────────────

extension View {
    /// Style a card container — white background, rounded corners, subtle shadow.
    func tCard() -> some View {
        self
            .background(Color.tBackground)
            .cornerRadius(12)
            .shadow(color: Color.tText.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    /// Primary filled button style.
    func tPrimaryButton() -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.tPrimary)
            .foregroundColor(.white)
            .font(.tBodyBold)
            .cornerRadius(10)
    }

    /// Secondary outlined button style.
    func tSecondaryButton() -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.tBackground)
            .foregroundColor(.tPrimary)
            .font(.tBodyBold)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.tPrimary, lineWidth: 1.5))
    }
}
