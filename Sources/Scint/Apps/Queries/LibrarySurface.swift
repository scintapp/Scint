import ScintComponents
import SwiftUI
import Foundation


struct LibrarySurface: Surface {
    var panel: any Panel
    var model: any Model

    var library: [Reference] {
        (Space.with(model.session.library, { $0 })?.materials ?? [])
            .sorted { $0.descriptor.updated > $1.descriptor.updated }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: Style.Spacing.section)], spacing: Style.Spacing.section) {
                ForEach(library) { ref in
                    NoteCard(ref: ref, selected: model.session.selection.selected(ref))
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            model.open(ref)
                            panel.state.presented = true
                        }
                        .onTapGesture { model.select(ref) }
                }
            }
            .padding(Style.Spacing.page)
        }
        .scrollIndicators(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
            if let ref = model.session.selection.content { model.session.close(ref) }
        }
        .background(Style.Background.canvas)
    }
}



