import SwiftUI


struct EditSurface: Surface {
    var panel: any Panel
    var model: any Model

    var origin: Reference { model.session.origin }
    var material: Reference? { model.session.opened.material }

    var body: some View {
        ScrollView {
            Color.clear.frame(height: Style.Spacing.xxl)

            VStack {
                if let material {
                    EditorComponent(material) { id in
                        if let ref = id as? Reference { model.select(ref) }
                        else if let id = id as? UUID { model.select(material, entry: id, url: nil) }
                    }
                    .id(material)
                    .simultaneousGesture(TapGesture().onEnded { model.select(material) })
                    .frame(maxWidth: Style.Spacing.contentMaxWidth, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Style.Spacing.xxl)

            Color.clear.frame(height: Style.Spacing.xxxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
}
