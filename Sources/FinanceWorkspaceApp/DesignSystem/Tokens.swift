import SwiftUI
import AppKit

// T002 — DesignSystem tokens, mirrored 1:1 from the DESIGN.md front matter (the one allowed
// token-to-code translation point). Views must resolve these semantic tokens and never hardcode
// a hex/px value. Every color carries its light AND dark value so both modes come for free.

/// Semantic design tokens (DESIGN.md front matter → SwiftUI).
enum DS {

    // MARK: - Colors (light, dark) — DESIGN.md `colors:`

    enum Colors {
        static let windowBg = dynamic(light: "#eef2f7", dark: "#1c1d20")
        static let surface = dynamic(light: "#ffffff", dark: "#2a2b2e")
        static let surfaceRaised = dynamic(light: "#f8f9fb", dark: "#303134")
        static let surfaceTint = dynamic(light: "#fbfcfe", dark: "#333438")
        static let surfaceSunken = dynamic(light: "#f3f5f9", dark: "#252629")
        static let border = dynamic(light: "#d7dde7", dark: "#3a3b3f")
        static let borderSoft = dynamic(light: "#e3e8ef", dark: "#313236")
        static let borderStrong = dynamic(light: "#c4cdda", dark: "#47484c")
        static let ink1 = dynamic(light: "#0f172a", dark: "#f5f6f8")
        static let ink2 = dynamic(light: "#1f2937", dark: "#e4e5e8")
        static let ink3 = dynamic(light: "#374151", dark: "#c7c9ce")
        static let ink4 = dynamic(light: "#4b5563", dark: "#abaeb5")
        static let muted = dynamic(light: "#6b7280", dark: "#9aa0a8")
        static let muted2 = dynamic(light: "#94a3b8", dark: "#71777f")
        /// Brand accent — brand-locked (never `NSColor.controlAccentColor`).
        static let accent = dynamic(light: "#3651d3", dark: "#7088f2")
        static let accentSoft = dynamic(light: "#e8eefc", dark: "#293052")
        static let accentBorder = dynamic(light: "#b9c8f2", dark: "#3c477a")
        static let accentInk = dynamic(light: "#1e3aab", dark: "#b4c2f8")
        static let ok = dynamic(light: "#15803d", dark: "#30d158")
        static let okSoft = dynamic(light: "#dcfce7", dark: "#10331f")
        static let warn = dynamic(light: "#b45309", dark: "#ff9f0a")
        static let warnSoft = dynamic(light: "#fef3c7", dark: "#3a2a09")
        static let err = dynamic(light: "#b91c1c", dark: "#ff453a")
        static let errSoft = dynamic(light: "#fee2e2", dark: "#3a1715")
        static let info = dynamic(light: "#1e40af", dark: "#0a84ff")
        static let infoSoft = dynamic(light: "#dbeafe", dark: "#0e2747")
        /// Money in / gain.
        static let pos = dynamic(light: "#15803d", dark: "#30d158")
        /// Money out / loss.
        static let neg = dynamic(light: "#b91c1c", dark: "#ff453a")
    }

    // MARK: - Radius — DESIGN.md `rounded:`

    enum Radius {
        static let sm: CGFloat = 6
        static let normal: CGFloat = 10
        static let lg: CGFloat = 14
    }

    // MARK: - Spacing & metrics — DESIGN.md `spacing:`

    enum Metrics {
        /// 4px base unit; scale [2, 4, 6, 8, 12, 14, 16, 18, 24, 32].
        static let unit: CGFloat = 4
        static let rowHeight: CGFloat = 30
        static let contentPaddingV: CGFloat = 18
        static let contentPaddingH: CGFloat = 24
        static let sidebarWidth: CGFloat = 248
        static let detailPaneMin: CGFloat = 360
        static let detailPaneMax: CGFloat = 420
        static let minWindowWidth: CGFloat = 900
        static let minWindowHeight: CGFloat = 600
        static let kpiGridGap: CGFloat = 12
        static let panelGap: CGFloat = 16
        static let chartTall: CGFloat = 230
        static let chartShort: CGFloat = 140
    }

    // MARK: - Helpers

    /// A light/dark dynamic color from the two front-matter hex values.
    private static func dynamic(light: String, dark: String) -> Color {
        let lightColor = nsColor(hex: light)
        let darkColor = nsColor(hex: dark)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        })
    }

    private static func nsColor(hex: String) -> NSColor {
        var value: UInt64 = 0
        Scanner(string: String(hex.dropFirst())).scanHexInt64(&value)
        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1)
    }
}
