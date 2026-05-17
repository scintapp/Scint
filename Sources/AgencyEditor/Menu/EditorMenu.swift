import SwiftUI


struct EditorMenu: View {
    @Environment(EditorModel.self) private var editor
    @FocusState private var focus: EditorMenuFocus?

    let position: CGPoint
    private var menu: MenuModel { editor.menu }

    var body: some View {
        content
            .frame(width: menu.size.width, height: menu.size.height, alignment: .topLeading)
            .offset(x: position.x, y: position.y)
            .animation(.easeOut(duration: 0.16), value: menu.presentedSubmenu)
            .onChange(of: menu.kind) { _, kind in focusInitialField(for: kind) }
            .onAppear { focusInitialField(for: menu.kind) }
    }

    @ViewBuilder
    private var content: some View {
        switch menu.kind {
        case .command:
            EditorCommandMenu()
        case .library:
            EditorLibraryMenu(focus: $focus)
        case .form(let kind):
            EditorComponentFormMenu(kind: kind, focus: $focus)
        }
    }

    private func focusInitialField(for kind: EditorMenuKind) {
        switch kind {
        case .command:
            focus = nil
        case .library:
            focus = .library
        case .form:
            focus = .formPrimary
        }
    }
}
