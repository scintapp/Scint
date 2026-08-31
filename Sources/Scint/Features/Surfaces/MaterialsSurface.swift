import SwiftUI


struct MaterialEditor: View {
    var model: any Model
    var material: Reference

    var body: some View {
        ScrollView {
            EditorComponent(material) { id in
                if let ref = id as? Reference { model.select(ref) }
                else if let id = id as? UUID { model.select(material, entry: id, url: nil) }
            }
            .id(material)
            .simultaneousGesture(TapGesture().onEnded { model.select(material) })
            .frame(maxWidth: Style.Spacing.contentMaxWidth, alignment: .topLeading)
        }
        .frame(maxWidth: 680, alignment: .center)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Style.Shape.large.fill(Style.Background.panel))
        .overlay(Style.Shape.large.stroke(Style.Border.raised, lineWidth: 1))
    }
}

struct MaterialsSurface: Surface {
    var panel: any Panel
    var model: any Model

    var origin: Reference { model.session.origin }
    var materials: [Reference] { Space.with(origin, { $0 })?.materials ?? [] }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(materials) { material in
                    MaterialEditor(model: model, material: material)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
