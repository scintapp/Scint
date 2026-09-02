import SwiftUI


@Observable final class EditorPanel: Panel {
    var mode: Modality = .floating
    var state: PanelState = .init()
    var surface: PanelSurface = .edit

    enum PanelSurface: String, CaseIterable, Identifiable {
        case edit
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String { "square.and.pencil" }
    }

    func surface(_ model: any Model) -> some View {
        VStack {
            if let material = model.session.opened.material {
                EditorComponent(material) { id in
                    if let ref = id as? Reference { model.select(ref) }
                    else if let id = id as? UUID { model.select(material, entry: id, url: nil) }
                }
                .id(material)
                .simultaneousGesture(TapGesture().onEnded { model.select(material) })
                .frame(maxWidth: Style.Spacing.contentMaxWidth, alignment: .topLeading)
                .frame(maxWidth: 680, alignment: .center)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
    }
}
