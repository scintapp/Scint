import SwiftUI
import ScintComponents


struct InboxHeader: Surface {
    var panel: any Panel
    var model: any Model

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            IconButton(systemImage: "plus") { }
            PageHeader("Inbox") { }
            Spacer()
            IconButton(systemImage: "ellipsis") { }
        }
        .frame(maxWidth: .infinity, maxHeight: 40, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
