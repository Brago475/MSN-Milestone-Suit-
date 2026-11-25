import SwiftUI

/// A gray placeholder block with a light sweep moving across it.
struct ShimmerBlock: View {

    var width: CGFloat?
    var height: CGFloat = 10

    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.15))
            .frame(width: width, height: height)
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.35), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: phase * geometry.size.width)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

/// Placeholder page shown while a document loads.
struct EditorSkeleton: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ShimmerBlock(width: 260, height: 22)
            ShimmerBlock(height: 10)
            ShimmerBlock(height: 10)
            ShimmerBlock(width: 420, height: 10)
            ShimmerBlock(width: 180, height: 16)
                .padding(.top, 10)
            ShimmerBlock(height: 10)
            ShimmerBlock(width: 380, height: 10)
            Spacer()
        }
        .padding(64)
        .frame(width: 600, height: 700)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.top, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: PageStyle.surround))
    }
}

/// Shows its content only after a short delay, so fast loads never flash a placeholder.
struct DelayedView<Content: View>: View {

    var delay: Duration = .milliseconds(300)
    @ViewBuilder var content: () -> Content

    @State private var isVisible = false

    var body: some View {
        Group {
            if isVisible {
                content()
            } else {
                Color.clear
            }
        }
        .task {
            try? await Task.sleep(for: delay)
            isVisible = true
        }
    }
}