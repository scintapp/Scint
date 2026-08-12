import SwiftUI


struct Editor: View {
    @Environment(ScintModel.self) var scint
    var body: some View { scint.editor.content.surface(scint.editor) }
}

@Observable final class EditorPanel: Panel {
    var state: PanelState = .init()

    func surface(_ model: any Model) -> some View {
        EditSurface(panel: self, model: model)
            .safeAreaBar(edge: .bottom) { EditorBar(model: model) }
            .toolbar {
                ToolbarItem(placement: .navigation) { NavigationControls(model: model) }
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { PathControls(model: model) }
            }
    }
}
