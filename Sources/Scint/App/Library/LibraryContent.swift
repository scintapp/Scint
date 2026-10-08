import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct LibraryContent: Surface {
    var host: any Host
    var model: any Model

    var documents: [Reference] {
        if model.session.selection.structure == model.session.library { return model.session.documents }
        else { return model.session.folder }
    }

    var body: some View {
        if model.session.opened.document != nil { DocumentContent(host: host, model: model) }
        else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230, maximum: 240), spacing: 20)], alignment: .leading, spacing: 20) {
                    ForEach(documents) { ref in
                        LibraryCard(ref: ref, model: model, hovered: false)
                            .onTapGesture { model.select(ref) }
                            .onTapGesture(count: 2) { model.open(ref) }
                            .contextMenu { ContextMenu(ref: ref, model: model) }
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
            .scrollEdgeEffectStyle(.hard, for: .vertical)
            .safeAreaBar(edge: .top) { LibraryHeader(model: model) }
        }
    }
}
