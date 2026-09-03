import SwiftUI


struct TextEditor: View {
    @Environment(EditorState.self) private var editor
    @Environment(\.editorFocus) private var focus
    @State private var contentHeight: CGFloat = 0

    private var material: DocumentModel { editor.material }
    let autofocus: Bool
    let active: Bool
    let minHeight: CGFloat
    let maxHeight: CGFloat?
    let onFocus: (AnyHashable) -> Void

    init(autofocus: Bool = true, active: Bool = true, minHeight: CGFloat = 0,
         maxHeight: CGFloat? = nil, onFocus: @escaping (AnyHashable) -> Void) {

        self.autofocus = autofocus
        self.active = active
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.onFocus = onFocus
    }

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
                onRunChange: editor.writeRun,
                onRunSelectionChange: editor.setRunCaret,
                onRunCommand: editor.handleRunInput,
                onRunFocusGained: { ids in
                    editor.focusGained(run: ids)
                    if let first = ids.first { onFocus(first) }
                },
                onCaretRectChange: editor.updateCaretRect,
                onFocusGained: { id in
                    editor.focusGained(id: id)
                    onFocus(id)
                },
                onEdit: editor.editBlock,
                onCommand: editor.handleInput,
                onFrames: editor.setBlockFrames
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
            .scrollEdgeEffectStyle(.hard, for: .vertical)
        } else {
            canvas
        }
    }

    var body: some View {
        viewport
            .coordinateSpace(name: "canvas")
            .onChange(of: editor.selection) { _, selection in
                switch selection {
                    case .none: focus.focus(nil)
                    case .blocks: break
                    case .block(let id), .caret(let id, _): focus.focus(id)
                }
            }
            .onChange(of: editor.menu.isOpen) { _, isOpen in
                guard !isOpen else { focus.focus(nil); return }
                Task { @MainActor in
                    await Task.yield()
                    focus.focus(editor.selection.id)
                }
            }
            .onAppear {
                guard autofocus else {
                    material.inlineReferenceBlocks()
                    editor.ensureTrailingText()
                    return
                }
                editor.prepare()
                focus.focus(editor.selection.id)
            }
            .onChange(of: active) { _, active in if !active { editor.deactivate(pruning: false) } }
            .onDisappear { editor.deactivate() }
            .background { menuPanel }
    }
}

struct EditorComponent: View {
    @State private var state: EditorState
    /// One coordinator per editor.
    ///
    /// `editorFocus` has no injected value anywhere, so every editor on screen was sharing the
    /// environment key's default instance — one `targetID` and one view registry between all of
    /// them. A deactivating editor blanking the first responder would then resign the view the
    /// editor being activated had just claimed, which is a race, not a rule.
    @State private var focus: EditorFocusCoordinator
    let autofocus: Bool
    let active: Bool
    let minHeight: CGFloat
    let maxHeight: CGFloat?
    let onFocus: (AnyHashable) -> Void

    init(_ material: Reference, autofocus: Bool = true, active: Bool = true, minHeight: CGFloat = 0, maxHeight: CGFloat? = nil, onFocus: @escaping (AnyHashable) -> Void = { _ in }) {
        self.autofocus = autofocus
        self.active = active
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
        _focus = State(initialValue: EditorFocusCoordinator())
    }

    var body: some View {
        TextEditor(
            autofocus: autofocus,
            active: active,
            minHeight: minHeight,
            maxHeight: maxHeight,
            onFocus: onFocus
        )
            .environment(state)
            .environment(\.editorFocus, focus)
    }
}
