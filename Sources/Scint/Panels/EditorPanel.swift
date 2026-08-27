import SwiftUI


@Observable final class EditorPanel: Panel {
    var state: PanelState = .init()
    var surface: PanelSurface = .edit

    enum PanelSurface: String, CaseIterable, Identifiable {
        case edit
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String { "square.and.pencil" }
    }

    func parameters(_ model: any Model) -> Params {
        .init(
            panel: .init(
                key: .tasks,
                sizing: .init(size: .init(width: 680, height: 840)),
                dismissal: [.escape, .outsideClick],
                resizable: true,
                pinnable: true
            )
        )
    }

    func surface(_ model: any Model) -> some View {
        EditSurface(panel: self, model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
