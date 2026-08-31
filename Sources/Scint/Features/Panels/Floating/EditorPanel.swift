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
            if let material = model.session.material {
                MaterialEditor(model: model, material: material)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
