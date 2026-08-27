import SwiftUI


enum EditorMenuPlacement: Equatable { case caret, centerTop }

struct TextEditor: View {
    @Environment(EditorState.self) private var editor
    @Environment(\.editorFocus) private var focus
    @FocusState private var menuFocus: MenuFocus?
    @State private var contentHeight: CGFloat = 0

    private var material: MaterialModel { editor.material }
    let autofocus: Bool
    let minimumHeight: CGFloat
    let maximumHeight: CGFloat?
    let menuPlacement: EditorMenuPlacement
    let onFocus: (AnyHashable) -> Void

    init(
        autofocus: Bool = true,
        minimumHeight: CGFloat = 0,
        maximumHeight: CGFloat? = nil,
        menuPlacement: EditorMenuPlacement = .caret,
        onFocus: @escaping (AnyHashable) -> Void
    ) {
        self.autofocus = autofocus
        self.minimumHeight = minimumHeight
        self.maximumHeight = maximumHeight
        self.menuPlacement = menuPlacement
        self.onFocus = onFocus
    }

    private func menu(in size: CGSize) -> some View {
        let model = editor.menu
        return Menu(
            query: Binding(get: { model.query }, set: { model.query = $0 }),
            formPrimary: Binding(get: { model.formPrimary }, set: { model.formPrimary = $0 }),
            kind: model.kind,
            items: model.items,
            selectedID: model.selectedID,
            size: model.size,
            position: menuPosition(in: size),
            focus: $menuFocus,
            onMoveSelection: model.moveSelection,
            onSelect: { item in
                model.select(item)
                editor.commitMenuSelection()
            },
            onCancel: model.close,
            onCommit: editor.commitMenuSelection
        )
    }

    private func menuPosition(in size: CGSize) -> CGPoint {
        let menuWidth = editor.menu.size.width
        let menuHeight = editor.menu.size.height
        let padding = Style.Spacing.xl
        let gap = Style.Spacing.md

        if menuPlacement == .centerTop {
            let x = max(padding, (size.width - menuWidth) / 2)
            return CGPoint(x: x, y: -menuHeight - gap)
        }

        let anchorRect = editor.menu.anchorRect
        let anchor = CGPoint(x: anchorRect.minX, y: anchorRect.maxY)
        let x = min(max(anchor.x, padding), max(padding, size.width - menuWidth - padding))
        let placeAbove = size.height - anchor.y < menuHeight + padding
        let y: CGFloat

        if placeAbove {
            let preferred = anchorRect.minY - menuHeight - gap
            y = anchorRect.minY > menuHeight + padding ? max(preferred, padding) : preferred
        } else {
            let proposed = anchor.y + gap
            let maximum = max(padding, size.height - menuHeight - padding)
            y = min(max(proposed, padding), maximum)
        }

        return CGPoint(x: x, y: y)
    }

    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .named("canvas")) { point in
                    editor.beginEditingFromMaterialClick(at: point)
                }

            MaterialView(
                editing: editor.editing,
                selection: editor.caretSelection(for:),
                onTextChange: editor.write,
                onSelectionChange: editor.setCaret,
                onCaretRectChange: editor.updateCaretRect,
                onViewportRectChange: editor.updateViewportRect,
                onFocusGained: { id in
                    editor.focusGained(id: id)
                    onFocus(id)
                },
                onEdit: editor.editBlock,
                onCommand: editor.handleInput,
                onPanelChange: editor.updateEntryPanel
            )
            .environment(material)
        }
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
    }

    @ViewBuilder private var viewport: some View {
        if let maximumHeight {
            ScrollView(.vertical) {
                canvas
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            
            .frame(height: min(max(contentHeight, minimumHeight), maximumHeight), alignment: .bottom)
            .scrollBounceBehavior(.basedOnSize)
        } else {
            canvas
        }
    }

    var body: some View {
        viewport
            .coordinateSpace(name: "canvas")
            .onChange(of: editor.editing) { _, _ in focus.focus(editor.editing ?? material.selection.first) }
            .onChange(of: material.selection) { _, _ in if editor.editing == nil { focus.focus(material.selection.first) } }
            .onChange(of: editor.menu.isOpen) { _, isOpen in
                guard !isOpen else { focus.focus(nil); return }
                Task { @MainActor in
                    await Task.yield()
                    focus.focus(editor.editing ?? material.selection.first)
                }
            }
            .onAppear {
                editor.activateTrailingText()
                if autofocus { focus.focus(editor.editing ?? material.selection.first) }
            }
            .onDisappear { editor.deactivate() }
            .overlay(alignment: .topLeading) {
                if editor.menu.isOpen {
                    GeometryReader { geometry in
                        menu(in: geometry.size)
                    }
                }
            }
    }
}

struct EditorComponent: View {
    @State private var state: EditorState
    let minimumHeight: CGFloat
    let maximumHeight: CGFloat?
    let menuPlacement: EditorMenuPlacement
    let onFocus: (AnyHashable) -> Void

    init(
        _ material: Reference,
        minimumHeight: CGFloat = 0,
        maximumHeight: CGFloat? = nil,
        menuPlacement: EditorMenuPlacement = .caret,
        onFocus: @escaping (AnyHashable) -> Void = { _ in }
    ) {
        self.minimumHeight = minimumHeight
        self.maximumHeight = maximumHeight
        self.menuPlacement = menuPlacement
        self.onFocus = onFocus
        _state = State(
            initialValue: EditorState(
                material: material,
                menuItems: MenuSurface.menu,
                makeBlocks: MenuSurface.build(for:)
            )
        )
    }

    var body: some View {
        TextEditor(
            minimumHeight: minimumHeight,
            maximumHeight: maximumHeight,
            menuPlacement: menuPlacement,
            onFocus: onFocus
        )
            .environment(state)
    }
}
