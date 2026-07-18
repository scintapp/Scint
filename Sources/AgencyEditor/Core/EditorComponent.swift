import AgencyRuntime
import SwiftUI


struct EditorComponent: View {
    @State private var state: EditorState
    let menuPlacement: EditorMenuPlacement

    init(_ sheet: Reference, menuPlacement: EditorMenuPlacement = .caret) {
        self.menuPlacement = menuPlacement
        _state = State(
            initialValue: EditorState(
                sheet: sheet,
                menuItems: MenuSurface.menu,
                makeBlocks: MenuSurface.build(for:)
            )
        )
    }

    var body: some View {
        TextEditor(menuPlacement: menuPlacement)
            .environment(state)
    }
}
