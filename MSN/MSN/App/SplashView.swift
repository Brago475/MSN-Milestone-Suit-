import SwiftUI

/// Launch screen: logo, name and a progress bar that fills before the app appears.
struct SplashView: View {

    let subtitle: String
    @State private var progress: CGFloat = 0

    private let barWidth: CGFloat = 160

    var body: some View {
        VStack(spacing: 14) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 96)

            Text("Milestone Suit")
                .font(.system(size: 17, weight: .semibold))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: barWidth * progress)
            }
            .frame(width: barWidth, height: 4)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9)) {
                progress = 1
            }
        }
    }
}