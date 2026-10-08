import SwiftUI
import ScintComponents
import ScintRuntime


struct InboxHeader: View {
    var ref: Reference

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            IconButton(systemImage: "plus") { }
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            Text("Inbox")
                .font(Typography.pageTitle)
            Spacer()
            IconButton(systemImage: "ellipsis") { }
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: 40, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
