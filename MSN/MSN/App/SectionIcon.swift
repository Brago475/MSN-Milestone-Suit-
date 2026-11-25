import SwiftUI

struct SectionIcon: View {
    let section: AppSection
    var size: CGFloat = 20

    var body: some View {
        Group {
            if let assetName = section.assetName {
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: section.symbol)
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.medium)
            }
        }
        .frame(width: size, height: size)
    }
}