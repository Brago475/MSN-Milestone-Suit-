import AppKit

/// Paper sizes in points at 96 per inch.
enum PaperSize: String, CaseIterable, Identifiable {
    case letter, a4, legal, a5

    var id: String { rawValue }

    var title: String {
        switch self {
        case .letter: "US Letter"
        case .a4: "A4"
        case .legal: "Legal"
        case .a5: "A5"
        }
    }

    var detail: String {
        switch self {
        case .letter: "8.5 × 11 in"
        case .a4: "210 × 297 mm"
        case .legal: "8.5 × 14 in"
        case .a5: "148 × 210 mm"
        }
    }

    var size: CGSize {
        switch self {
        case .letter: CGSize(width: 816, height: 1056)
        case .a4: CGSize(width: 794, height: 1123)
        case .legal: CGSize(width: 816, height: 1344)
        case .a5: CGSize(width: 559, height: 794)
        }
    }
}

/// Margin presets, the same on all four sides.
enum MarginPreset: String, CaseIterable, Identifiable {
    case normal, narrow, moderate, wide

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normal (1 in)"
        case .narrow: "Narrow (0.5 in)"
        case .moderate: "Moderate (0.75 in)"
        case .wide: "Wide (1.5 in)"
        }
    }

    var points: CGFloat {
        switch self {
        case .normal: 96
        case .narrow: 48
        case .moderate: 72
        case .wide: 144
        }
    }
}

/// Size of one page and its text area.
struct PageLayout: Equatable {
    var paper: PaperSize = .letter
    var margins: MarginPreset = .normal

    /// Gray space between pages.
    static let gap: CGFloat = 24

    var width: CGFloat { paper.size.width }
    var height: CGFloat { paper.size.height }
    var margin: CGFloat { margins.points }
    var contentWidth: CGFloat { width - margin * 2 }
    var contentHeight: CGFloat { height - margin * 2 }

    /// Distance from the top of one page to the top of the next.
    var stride: CGFloat { height + Self.gap }
}