import AppKit
import SwiftUI

enum Theme {
    static let accent = Color(red: 10 / 255, green: 95 / 255, blue: 232 / 255)

    static let railWidth: CGFloat = 72
    static let railButtonSize: CGFloat = 42
    static let railCornerRadius: CGFloat = 11
    static let titleBarInset: CGFloat = 40

    /// Radius of the curves where the window button pocket meets the window edges.
    static let pocketBend: CGFloat = 12

    /// Main window surface: white in light mode, near black in dark mode.
    static let surface = dynamic(
        light: .white,
        dark: NSColor(srgbRed: 0x1E / 255, green: 0x1F / 255, blue: 0x22 / 255, alpha: 1)
    )

    /// Gray pocket behind the window buttons.
    static let pocket = dynamic(
        light: NSColor(srgbRed: 0xED / 255, green: 0xF0 / 255, blue: 0xF4 / 255, alpha: 1),
        dark: NSColor(srgbRed: 0x2B / 255, green: 0x2D / 255, blue: 0x32 / 255, alpha: 1)
    )

    /// Thin dividers between areas.
    static let hairline = dynamic(
        light: NSColor(srgbRed: 0xEC / 255, green: 0xEC / 255, blue: 0xF0 / 255, alpha: 1),
        dark: NSColor(srgbRed: 0x34 / 255, green: 0x36 / 255, blue: 0x3B / 255, alpha: 1)
    )

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}