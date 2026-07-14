import SwiftUI
import AgencyRuntime


struct AgencyEditor: View {
    @State private var state: EditorState

    init(_ sheet: Reference) {
        _state = State(
            initialValue: EditorState(
                sheet: sheet,
                menuItems: MenuSurface.menu,
                makeBlocks: MenuSurface.build(for:)
            )
        )
    }

    var body: some View {
        EditorCanvas()
            .environment(state)
    }
}
