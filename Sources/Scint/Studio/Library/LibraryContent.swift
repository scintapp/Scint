import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct LibraryContent: Surface {
    var panel: any Panel
    var model: any Model

    var folder: Reference {
        let selected = model.session.selection.structure
        guard let selected, selected != model.session.library
        else { return model.session.library }
        return selected
    }

    var documents: [Reference] {
        guard let documents = Space.with(folder, { $0 })?.documents
        else { return [] }
        return documents
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: Style.Spacing.entry)], spacing: Style.Spacing.entry) {
                if !documents.isEmpty {
                    ForEach(documents) { ref in
                        LibraryCard(
                            ref: ref,
                            selected: model.session.selection.selected(ref),
                            isHovered: false
                        )
                        .onTapGesture { model.select(ref) }
                        .onTapGesture(count: 2) { model.open(ref) }
                        .contextMenu { ContextActionMenu(ref: ref, model: model) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .scrollIndicators(.hidden)
            .contentShape(Rectangle())
            .padding(.horizontal, Style.Spacing.entry)
            .padding(.top, Style.Spacing.section)
        }
        .onTapGesture { if let ref = model.session.selection.content { model.session.close(ref) } }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Style.Background.canvas)
        .safeAreaBar(edge: .top) { LibraryHeader(panel: panel, model: model) }
    }
}
