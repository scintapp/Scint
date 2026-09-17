import SwiftUI


#if DEBUG
@MainActor private func editorMenuController(
    kind: MenuKind,
    query: String = "",
    formPrimary: String = ""
) -> MenuController {
    let controller = MenuController(
        items: ScintEditorMenu.menu,
        search: { query, kind in ScintEditorMenu.search(query, kind: kind) }
    )
    controller.open(
        kind: kind,
        query: query,
        target: "editor-menu-preview",
        replacementRange: NSRange(location: 0, length: 0),
        anchorRect: .zero
    )
    controller.formPrimary = formPrimary
    return controller
}

private struct EditorMenuPreview: View {
    let controller: MenuController

    var body: some View {
        MenuPanelContent(
            controller: controller,
            onSelect: controller.select,
            onCancel: {},
            onCommit: { _ = controller.commit() }
        )
        .padding(Style.Spacing.xxl)
        .background(Style.Background.base)
    }
}

#Preview("Editor Menu — Slash Commands") {
    EditorMenuPreview(controller: editorMenuController(kind: .fixed))
        .preferredColorScheme(.dark)
}

#Preview("Editor Menu — References") {
    _ = PreviewFixture.shared

    return EditorMenuPreview(
        controller: editorMenuController(kind: .dynamic, query: "swift")
    )
    .preferredColorScheme(.dark)
}

#Preview("Editor Menu — New Task") {
    EditorMenuPreview(
        controller: editorMenuController(
            kind: .create(.task),
            formPrimary: "Review the research brief"
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("Editor Menu — Edit Link") {
    EditorMenuPreview(
        controller: editorMenuController(
            kind: .update(.link),
            formPrimary: "https://developer.apple.com/documentation/swiftui"
        )
    )
    .preferredColorScheme(.dark)
}
#endif
