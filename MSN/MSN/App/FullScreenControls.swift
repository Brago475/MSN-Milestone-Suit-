import AppKit
import SwiftUI

/// Window buttons drawn in the pocket while in full screen, where macOS hides its own.
/// Faint until hovered. Close closes, minimize is unavailable as in macOS, green leaves full screen.
struct FullScreenControls: View {

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            ControlDot(
                color: Color(red: 1, green: 0.373, blue: 0.341),
                symbol: "xmark",
                label: "Close",
                showsSymbol: isHovered
            ) {
                NSApp.keyWindow?.performClose(nil)
            }

            ControlDot(
                color: Color(nsColor: .tertiaryLabelColor),
                symbol: "minus",
                label: "Minimize is not available in full screen",
                showsSymbol: false,
                action: nil
            )

            ControlDot(
                color: Color(red: 0.157, green: 0.784, blue: 0.251),
                symbol: "arrow.down.right.and.arrow.up.left",
                label: "Exit Full Screen",
                showsSymbol: isHovered
            ) {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
        }
        .padding(8)
        .contentShape(Rectangle())
        .opacity(isHovered ? 1 : 0.35)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

private struct ControlDot: View {

    let color: Color
    let symbol: String
    let label: String
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
                            .font(.system(size: 6.5, weight: .heavy))
                            .foregroundStyle(.black.opacity(0.55))
                    }
                }
                .frame(width: 12, height: 12)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .help(label)
        .accessibilityLabel(label)
    }
}