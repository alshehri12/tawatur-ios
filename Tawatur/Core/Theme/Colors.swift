// Colors.swift — Brand color palette for تواتر (light mode)
// All UI components reference these tokens — never hardcode hex strings elsewhere.

import SwiftUI

extension Color {

    // ── Primary ───────────────────────────────────────────────────────────────
    static let tPrimary  = Color(hex: "#1A3A6B")   // Deep blue — buttons, headers, accents
    static let tAccent   = Color(hex: "#2A5298")   // Lighter blue — secondary interactive

    // ── Backgrounds ───────────────────────────────────────────────────────────
    static let tBackground = Color(hex: "#FFFFFF")  // Page background
    static let tSurface    = Color(hex: "#F5F7FA")  // Cards, panels, inputs

    // ── Text ──────────────────────────────────────────────────────────────────
    static let tText    = Color(hex: "#1A1A2E")     // Primary text
    static let tSubtext = Color(hex: "#6B7280")     // Labels, captions, placeholders

    // ── Semantic ──────────────────────────────────────────────────────────────
    static let tSuccess = Color(hex: "#10B981")     // Verified badges, approvals
    static let tDanger  = Color(hex: "#EF4444")     // Errors, rejections, fraud alerts
    static let tWarning = Color(hex: "#F59E0B")     // Pending states, warnings

    // ── Borders ───────────────────────────────────────────────────────────────
    static let tBorder  = Color(hex: "#E5E7EB")     // Dividers, input borders

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
