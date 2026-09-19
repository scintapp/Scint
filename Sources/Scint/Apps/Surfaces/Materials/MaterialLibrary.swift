import ScintComponents
import SwiftUI
import Foundation


struct LibraryContent: Surface {
    var panel: any Panel
    var model: any Model

    var space: Reference? { model.session.selection.structure }
    var material: Reference? { model.session.opened.material }
    var materials: [Reference] {
        guard let space, let materials = Space.with(space, { $0 })?.materials
        else { return [] }
        return materials
    }

    var body: some View {
        ZStack {
            HSplitView {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: Style.Spacing.section)], spacing: Style.Spacing.section) {
                        if !materials.isEmpty {
                            ForEach(materials) { material in
                                MaterialCard(ref: material, selected: model.session.selection.selected(material))
                                    .contentShape(Rectangle())
                                    .onTapGesture { model.focus(material) }
                                    .onTapGesture(count: 2) {
                                        model.open(material)
                                    }
                            }
                            .padding(Style.Spacing.page)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture { if let ref = model.session.selection.content { model.session.close(ref) } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                .background(Style.Background.canvas)
                if let material { MaterialContent(ref: material, panel: panel, model: model) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


