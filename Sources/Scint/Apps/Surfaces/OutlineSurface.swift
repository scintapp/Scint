import SwiftUI
import Foundation


struct OutlineSurface: Surface {
    var panel: any Panel
    var model: any Model

    var drafts: [Reference] {
        (Space.with(model.session.drafts, { $0 })?.materials ?? [])
            .sorted { $0.descriptor.updated > $1.descriptor.updated }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: Style.Spacing.xxl)], spacing: Style.Spacing.xxl) {
                ForEach(drafts) { ref in
                    DraftCard(ref: ref, selected: model.session.selection.selected(ref))
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            model.open(ref)
                            panel.state.presented = true
                        }
                        .onTapGesture { model.select(ref) }
                }
            }
            .padding(Style.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
            if let ref = model.session.selection.content { model.session.close(ref) }
        }
        .background(Style.Background.base)
    }
}



