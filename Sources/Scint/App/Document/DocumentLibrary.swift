import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct DocumentLibrary: Surface {
    var panel: any Panel
    var model: any Model

    var space: Reference? { model.session.selection.structure }
    var document: Reference? { model.session.opened.document }
    var documents: [Reference] {
        guard let space, let documents = Space.with(space, { $0 })?.documents
        else { return [] }
        return documents
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: Style.Spacing.section)], spacing: Style.Spacing.section) {
                if !documents.isEmpty {
                    ForEach(documents) { document in
                        DocumentCard(ref: document, model: model, selected: model.session.selection.selected(document))
                            .onTapGesture { model.focus(document) }
                            .onTapGesture(count: 2) { model.open(document) }
                    }
                    .padding(Style.Spacing.page)
                }
            }
            .scrollIndicators(.hidden)
            .contentShape(Rectangle())
        }
        .onTapGesture { if let ref = model.session.selection.content { model.session.close(ref) } }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Style.Background.canvas)
    }
}


