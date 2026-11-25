import SwiftUI

struct SectionPlaceholder: View {
    let section: AppSection

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(section.title)
            } icon: {
                SectionIcon(section: section, size: 44)
            }
        } description: {
            Text("This section is being built.")
        }
    }
}