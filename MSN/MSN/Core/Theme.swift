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

    /// Gray pocket behind the window buttons. Also the tab bar background.
    static let pocket = dynamic(
        light: NSColor(srgbRed: 0xED / 255, green: 0xF0 / 255, blue: 0xF4 / 255, alpha: 1),
        dark: NSColor(srgbRed: 0x2B / 255, green: 0x2D / 255, blue: 0x32 / 255, alpha: 1)
    )

    /// Thin dividers between areas.
    static let hairline = dynamic(
        light: NSColor(srgbRed: 0xEC / 255, green: 0xEC / 255, blue: 0xF0 / 255, alpha: 1),
        dark: NSColor(srgbRed: 0x34 / 255, green: 0x36 / 255, blue: 0x3B / 255, alpha: 1)
    )

    /// Fill of tabs and tab bar buttons that are not selected.
    static let tabIdle = dynamic(
        light: NSColor(white: 1, alpha: 0.5),
        dark: NSColor(white: 1, alpha: 0.05)
    )

    /// Fill of an idle tab under the pointer.
    static let tabHover = dynamic(
        light: NSColor(white: 1, alpha: 0.85),
        dark: NSColor(white: 1, alpha: 0.09)
    )

    /// Outline of tabs and tab bar buttons.
    static let tabOutline = dynamic(
        light: NSColor(srgbRed: 0xD5 / 255, green: 0xD9 / 255, blue: 0xDF / 255, alpha: 1),
        dark: NSColor(srgbRed: 0x45 / 255, green: 0x47 / 255, blue: 0x4D / 255, alpha: 1)
    )

    /// Line under the tab bar.
    static let tabBarEdge = dynamic(
        light: NSColor(srgbRed: 0xC9 / 255, green: 0xCD / 255, blue: 0xD4 / 255, alpha: 1),
        dark: NSColor(srgbRed: 0x3A / 255, green: 0x3C / 255, blue: 0x42 / 255, alpha: 1)
    )

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}