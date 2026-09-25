import SwiftUI
import ScintComponents
import ScintRuntime


struct LibraryHeader: Surface {
    var panel: any Panel
    var model: any Model

    var library: Reference { model.session.library }

    var title: String {
        if let _ = model.session.selection.structure { return "Documents" }
        else { return library.descriptor.name }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            NewTaskButton(model: model)
            PageHeader(title) { }
        }
        .frame(maxWidth: .infinity, maxHeight: 40, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}
