import SwiftUI


enum EditorMenuPlacement: Equatable {
    case caret
    case centerTop
}

public struct TextEditor: View {
    @Environment(EditorState.self) private var editor
    @Environment(\.editorFocus) private var focus
    private var sheet: SheetModel { editor.sheet }
    let autofocus: Bool
    let minimumHeight: CGFloat
    let menuPlacement: EditorMenuPlacement

    init(autofocus: Bool = true, minimumHeight: CGFloat = 0, menuPlacement: EditorMenuPlacement = .caret) {
        self.autofocus = autofocus
        self.minimumHeight = minimumHeight
        self.menuPlacement = menuPlacement
    }

    private func menu(in size: CGSize) -> some View { Menu(position: menuPosition(in: size)) }

    private func menuPosition(in size: CGSize) -> CGPoint {
        let padding: CGFloat = 8
        let gap: CGFloat = 6
        let menuWidth = editor.menu.size.width
        let menuHeight = editor.menu.size.height
        let viewport = editor.menuViewportRect ?? CGRect(origin: .zero, size: size)
        let minimumX = viewport.minX + padding
        let maximumX = max(minimumX, viewport.maxX - menuWidth - padding)
        let minimumY = viewport.minY + padding
        let maximumY = max(minimumY, viewport.maxY - menuHeight - padding)

        if menuPlacement == .centerTop {
            let x = min(max(viewport.midX - menuWidth / 2, minimumX), maximumX)
            let y = min(viewport.minY + 24, maximumY)
            return CGPoint(x: x, y: y)
        }

        let anchorRect = editor.menu.anchorRect
        let x = min(max(anchorRect.minX - 16, minimumX), maximumX)
        let availableAbove = max(0, anchorRect.minY - gap - minimumY)
        let availableBelow = max(0, viewport.maxY - padding - anchorRect.maxY - gap)
        let placeBelow = availableBelow >= menuHeight || availableBelow >= availableAbove
        let proposedY = placeBelow
            ? anchorRect.maxY + gap
            : anchorRect.minY - menuHeight - gap
        let y = min(max(proposedY, minimumY), maximumY)

        return CGPoint(x: x, y: y)
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .named("canvas")) { point in
                    editor.beginEditingFromCanvasClick(at: point)
                }

            SheetView(
                editing: editor.editing,
                selection: editor.caretSelection(for:),
                onTextChange: editor.write,
                onSelectionChange: editor.setCaret,
                onCaretRectChange: editor.updateCaretRect,
                onViewportRectChange: editor.updateViewportRect,
                onFocusGained: editor.focusGained,
                onEdit: editor.editBlock,
                onCommand: editor.handleInput,
                onFrameChange: editor.updateEntryFrame
            )
            .environment(sheet)
        }
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
        .coordinateSpace(name: "canvas")
        .onChange(of: editor.editing) { _, _ in focus.focus(editor.editing ?? sheet.selection.first) }
        .onChange(of: sheet.selection) { _, _ in if editor.editing == nil { focus.focus(sheet.selection.first) } }
        .onChange(of: editor.menu.isOpen) { _, isOpen in
            guard !isOpen else { return }
            Task { @MainActor in
                await Task.yield()
                focus.focus(editor.editing ?? sheet.selection.first)
            }
        }
        .onAppear {
            editor.activateTrailingText()
            if autofocus { focus.focus(editor.editing ?? sheet.selection.first) }
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
