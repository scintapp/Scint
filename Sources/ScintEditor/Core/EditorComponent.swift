import SwiftUI


struct EditorComponent: View {
    @State private var state: EditorState
    let minimumHeight: CGFloat
    let maximumHeight: CGFloat?
    let menuPlacement: EditorMenuPlacement

    init(_ sheet: Reference, minimumHeight: CGFloat = 0, maximumHeight: CGFloat? = nil, menuPlacement: EditorMenuPlacement = .caret) {
        self.minimumHeight = minimumHeight
        self.maximumHeight = maximumHeight
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
        TextEditor(minimumHeight: minimumHeight, maximumHeight: maximumHeight, menuPlacement: menuPlacement)
            .environment(state)
    }
}
