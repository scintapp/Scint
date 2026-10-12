import SwiftUI
import ScintComponents
import ScintRuntime


struct LibraryHeader: View {
    var model: any Model

    var ref: Reference {
        if let folder = model.session.selection.structure { return folder }
        else { return model.session.library }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            IconButton(systemImage: "plus") {
                model.session
                    .open(Document.new(from: .init(name: "New Document", origin: ref, header: .document)))
            }
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

            Text(ref.descriptor.name)
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
