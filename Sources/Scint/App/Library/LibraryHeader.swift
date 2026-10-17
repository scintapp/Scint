import SwiftUI
import ScintComponents
import ScintRuntime


struct LibraryHeader: View {
    var model: any Model

    var ref: Reference {
        guard let ref = model.session.selection.structure
        else { return model.session.library }
        return ref
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            IconButton(systemImage: "plus") {
                model.session
                    .open(ScintRuntime.Document.new(.init(name: "New Document", origin: ref)))
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
