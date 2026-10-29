// Colors.swift — Brand color palette for تواتر (light mode)
// All UI components reference these tokens — never hardcode hex strings elsewhere.
// Matches the approved designs in UIDesign/ (forest green, mint, warm amber).

import SwiftUI

extension Color {

    // ── Brand ─────────────────────────────────────────────────────────────────
    static let tForest    = Color(hex: "#0B3B2C")   // Header bands, primary buttons
    static let tForest2   = Color(hex: "#0F4D3A")   // Lighter end of the band gradient
    static let tGreen     = Color(hex: "#12B886")   // Bright accent — ticks, progress, plus badge
    static let tGreenDeep = Color(hex: "#0A8F68")   // Green text/icons on light backgrounds
    static let tMint      = Color(hex: "#E6F7F0")   // Tinted fills behind green icons
    static let tBandText  = Color(hex: "#A8CFC0")   // Secondary text on the forest band
    static let tGold      = Color(hex: "#B8873E")   // Logo gold — certificate seal
    static let tSand      = Color(hex: "#FDE7C8")   // Avatar circle
    static let tSandInk   = Color(hex: "#7A4A00")   // Avatar initial

    // ── Primary (kept for existing screens) ───────────────────────────────────
    static let tPrimary  = tForest
    static let tAccent   = tGreenDeep

    // ── Backgrounds ───────────────────────────────────────────────────────────
    static let tBackground = Color(hex: "#FFFFFF")  // Cards, sheets
    static let tSurface    = Color(hex: "#F3F6F4")  // Page background, inputs

    // ── Text ──────────────────────────────────────────────────────────────────
    static let tText    = Color(hex: "#102019")     // Primary text
    static let tSubtext = Color(hex: "#6C7D75")     // Labels, captions
    static let tFaint   = Color(hex: "#A3B2AB")     // Tertiary text, inactive

    // ── Semantic ──────────────────────────────────────────────────────────────
    static let tSuccess   = tGreenDeep              // Verified badges, approvals
    static let tDanger    = Color(hex: "#C93B3B")   // Errors, rejections
    static let tDangerBg  = Color(hex: "#FDECEC")
    static let tWarning   = Color(hex: "#B86200")   // Pending states — readable on white
    static let tWarningBg = Color(hex: "#FFF3E0")
    static let tSold      = Color(hex: "#3F5BA9")   // Devices you sold
    static let tSoldBg    = Color(hex: "#E8EDF9")

    // ── Borders ───────────────────────────────────────────────────────────────
    static let tBorder  = Color(hex: "#E3EAE6")     // Dividers, input borders

    // ── Hex initialiser ───────────────────────────────────────────────────────
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a, r, g, b) = (255, (int>>8)*17, (int>>4 & 0xF)*17, (int & 0xF)*17)
        case 6:  (a, r, g, b) = (255, int>>16, int>>8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int>>24, int>>16 & 0xFF, int>>8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

extension LinearGradient {
    /// The forest band behind headers (home, transaction detail, success screens).
    static let tBand = LinearGradient(colors: [.tForest2, .tForest],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
}
