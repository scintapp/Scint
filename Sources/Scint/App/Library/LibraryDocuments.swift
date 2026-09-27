import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct LibraryDocuments: Surface {
    var panel: any Panel
    var model: any Model

    var library: Reference { model.session.library }
    var documents: [Reference] { model.session.documents }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: Style.Spacing.entry)], spacing: Style.Spacing.entry) {
                if !documents.isEmpty {
                    ForEach(documents) { document in
                        LibraryCard(
                            ref: document,
                            selected: model.session.selection.selected(document),
                            isHovered: false
                        )
                        .onTapGesture { model.select(document) }
                        .onTapGesture(count: 2) { model.open(document) }
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
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .safeAreaBar(edge: .top) { LibraryHeader(panel: panel, model: model) }
    }
}
