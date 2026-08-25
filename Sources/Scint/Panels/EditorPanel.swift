import SwiftUI


@Observable final class EditorPanel: Panel {
    var state: PanelState = .init()
    var surface: EditorSurface = .edit

    enum EditorSurface: String, CaseIterable, Identifiable {
        case edit

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
                case .edit: "square.and.pencil"
            }
        }
    }

    func surface(_ model: any Model) -> some View {
        switch surface {
            case .edit:
                EditSurface(panel: self, model: model)
                    .safeAreaBar(edge: .bottom) { EditorBar(model: model) }
                    .toolbar {
                        ToolbarItem(placement: .navigation) { NavigationButtons(model: model) }
                        ToolbarItem(placement: .principal) { ActivityBar() }
                        ToolbarSpacer(.flexible, placement: .primaryAction)
                        ToolbarItem(placement: .primaryAction) { SplitPicker() }
                    }
        }
    }
}
