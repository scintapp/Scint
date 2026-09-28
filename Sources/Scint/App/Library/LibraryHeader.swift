import SwiftUI
import ScintComponents
import ScintRuntime


struct LibraryHeader: Surface {
    var panel: any Panel
    var model: any Model

    var space: Reference? { model.session.selection.structure }
    var title: String { if let space { return space.descriptor.name } else { return "All Documents" } }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            IconButton(systemImage: "plus") { model.session.open(Document.new(model.session.library, name: "New Document")) }
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            Text(title).font(Typography.pageTitle)
            Spacer()
            IconButton(systemImage: "ellipsis") { }
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: 40, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
