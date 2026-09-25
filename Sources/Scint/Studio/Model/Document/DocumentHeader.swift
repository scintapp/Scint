import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct DocumentHeader: View {
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
