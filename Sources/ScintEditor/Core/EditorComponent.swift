import SwiftUI


struct TextEditor: View {
    @Environment(EditorState.self) private var editor
    @Environment(\.editorFocus) private var focus
    @State private var contentHeight: CGFloat = 0

    private var material: DocumentModel { editor.material }
    let autofocus: Bool
    let minHeight: CGFloat
    let maxHeight: CGFloat?
    let onFocus: (AnyHashable) -> Void

    init(autofocus: Bool = true, minHeight: CGFloat = 0, maxHeight: CGFloat? = nil,
         onFocus: @escaping (AnyHashable) -> Void) {

        self.autofocus = autofocus
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.onFocus = onFocus
    }

    /// Binds the menu to a child window on the host window. Nothing about placement lives here
    /// any more: the panel positions itself against the screen from a caret rect already in screen
    /// coordinates.
    private var menuPanel: some View {
        MenuPanelHost(
            controller: editor.menu,
            isOpen: editor.menu.isOpen,
            anchor: editor.menu.anchorRect,
            size: editor.menu.size,
            onSelect: { item in
                editor.menu.select(item)
                editor.commitMenuSelection()
            },
            onCancel: editor.menu.close,
            onCommit: editor.commitMenuSelection
        )
    }

    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .named("canvas")) { point in
                    editor.beginEditingFromMaterialClick(at: point)
                }

            MaterialView(
                selection: editor.selection,
                onTextChange: editor.write,
                onSelectionChange: editor.setCaret,
                onCaretRectChange: editor.updateCaretRect,
                onFocusGained: { id in
                    editor.focusGained(id: id)
                    onFocus(id)
                },
                onEdit: editor.editBlock,
                onCommand: editor.handleInput,
                onPanelChange: editor.updateBlockFrame
            )
            .environment(material)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
    }

    @ViewBuilder private var viewport: some View {
        if let maxHeight {
            ScrollView(.vertical) {
                canvas
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            
            .frame(height: min(max(contentHeight, minHeight), maxHeight), alignment: .bottom)
        } else {
            canvas
        }
    }

    var body: some View {
        viewport
            .coordinateSpace(name: "canvas")
            // First responder derives from the selection, one way. This was two `onChange`
            // handlers reconciling `editor.editing` against `material.selection`, which is exactly
            // the disagreement the focus coordinator's retries were compensating for.
            .onChange(of: editor.selection) { _, selection in focus.focus(selection.id) }
            .onChange(of: editor.menu.isOpen) { _, isOpen in
                guard !isOpen else { focus.focus(nil); return }
                Task { @MainActor in
                    await Task.yield()
                    focus.focus(editor.selection.id)
                }
            }
            .onAppear {
                editor.prepare()
                if autofocus { focus.focus(editor.selection.id) }
            }
            .onDisappear { editor.deactivate() }
            .background { menuPanel }
    }
}

struct EditorComponent: View {
    @State private var state: EditorState
    let minHeight: CGFloat
    let maxHeight: CGFloat?
    let onFocus: (AnyHashable) -> Void

    init(
        _ material: Reference,
        minHeight: CGFloat = 0,
        maxHeight: CGFloat? = nil,
        onFocus: @escaping (AnyHashable) -> Void = { _ in }
    ) {
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.onFocus = onFocus

        _state = State(
            initialValue: EditorState(
                material: material,
                menuItems: MenuSurface.menu,
                search: MenuSurface.search(_:kind:)
            )
        )
    }

    var body: some View {
        TextEditor(
            minHeight: minHeight,
            maxHeight: maxHeight,
            onFocus: onFocus
        )
            .environment(state)
    }
}
