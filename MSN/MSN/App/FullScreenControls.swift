import AppKit
import SwiftUI

/// Window buttons drawn in the pocket while in full screen, where macOS hides its own.
/// Always visible. Hovering shows their symbols. Minimize is unavailable, as in macOS.
struct FullScreenControls: View {

    private static let dotSize: CGFloat = 14

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 9) {
            ControlDot(
                color: Color(red: 1, green: 0.373, blue: 0.341),
                symbol: "xmark",
                label: "Close",
                size: Self.dotSize,
                showsSymbol: isHovered
            ) {
                NSApp.keyWindow?.performClose(nil)
            }

            ControlDot(
                color: Color(nsColor: .tertiaryLabelColor),
                symbol: "minus",
                label: "Minimize is not available in full screen",
                size: Self.dotSize,
                showsSymbol: false,
                action: nil
            )

            ControlDot(
                color: Color(red: 0.157, green: 0.784, blue: 0.251),
                symbol: "arrow.down.right.and.arrow.up.left",
                label: "Exit Full Screen",
                size: Self.dotSize,
                showsSymbol: isHovered
            ) {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
        }
        .padding(8)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

private struct ControlDot: View {

    let color: Color
    let symbol: String
    let label: String
    let size: CGFloat
    let showsSymbol: Bool
    let action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            Circle()
                .fill(color)
                .overlay {
                    if showsSymbol {
                        Image(systemName: symbol)
                            .font(.system(size: size * 0.55, weight: .heavy))
                            .foregroundStyle(.black.opacity(0.55))
                    }
                }
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .help(label)
        .accessibilityLabel(label)
    }
}