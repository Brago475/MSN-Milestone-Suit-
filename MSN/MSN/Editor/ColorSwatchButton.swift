import SwiftUI

/// Toolbar button that opens a small grid of colors.
struct ColorSwatchButton: View {

    let symbol: String
    let help: String
    let colors: [(name: String, hex: String)]
    var onPick: (String?) -> Void

    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing.toggle()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .popover(isPresented: $isShowing, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(22), spacing: 8), count: 5), spacing: 8) {
                    ForEach(colors, id: \.hex) { color in
                        Button {
                            onPick(color.hex)
                            isShowing = false
                        } label: {
                            Circle()
                                .fill(Color(nsColor: Hex.color(color.hex) ?? .black))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(Color.secondary.opacity(0.3)))
                        }
                        .buttonStyle(.plain)
                        .help(color.name)
                    }
                }
                Button("None") {
                    onPick(nil)
                    isShowing = false
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            }
            .padding(12)
        }
    }
}