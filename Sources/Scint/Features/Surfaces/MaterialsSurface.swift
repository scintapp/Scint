import SwiftUI


struct MaterialSurface: Surface {
    @State var zoomed: Bool = false
    var panel: any Panel
    var model: any Model
    var material: Reference

    var origin: Reference { model.session.origin }

    var body: some View {
        ScrollView {
            EditorComponent(material) { id in
                if let ref = id as? Reference { model.select(ref) }
                else if let id = id as? UUID { model.select(material, entry: id, url: nil) }
            }
            .id(material)
            .simultaneousGesture(TapGesture().onEnded { model.select(material) })
            .frame(maxWidth: Style.Spacing.contentMaxWidth, alignment: .topLeading)
            .frame(maxWidth: 660, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .overlay(Style.Shape.large.stroke(Style.Border.base, lineWidth: 1))
        .scrollEdgeEffectStyle(.soft, for: .top)
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
                    MaterialSurface(panel: panel, model: model, material: material)
                        .background(Style.Shape.medium.fill(Style.Background.frame))
                        .overlay(Style.Shape.medium.stroke(Style.Border.base, lineWidth: 1))
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
