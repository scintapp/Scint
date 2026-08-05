import SwiftUI


enum EditorMenuPlacement: Equatable {
    case caret
    case centerTop
}

public struct TextEditor: View {
    @Environment(EditorState.self) private var editor
    @Environment(\.editorFocus) private var focus
    @State private var contentHeight: CGFloat = 0
    private var sheet: SheetModel { editor.sheet }
    let autofocus: Bool
    let minimumHeight: CGFloat
    let maximumHeight: CGFloat?
    let menuPlacement: EditorMenuPlacement

    init(autofocus: Bool = true, minimumHeight: CGFloat = 0, maximumHeight: CGFloat? = nil, menuPlacement: EditorMenuPlacement = .caret) {
        self.autofocus = autofocus
        self.minimumHeight = minimumHeight
        self.maximumHeight = maximumHeight
        self.menuPlacement = menuPlacement
    }

    private func menu(in size: CGSize) -> some View { Menu(position: menuPosition(in: size)) }

    private func menuPosition(in size: CGSize) -> CGPoint {
        let menuWidth = editor.menu.size.width
        let menuHeight = editor.menu.size.height
        let padding: CGFloat = 16
        let gap: CGFloat = 6

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

    public var body: some View {
        viewport
            .coordinateSpace(name: "canvas")
            .onChange(of: editor.editing) { _, _ in focus.focus(editor.editing ?? sheet.selection.first) }
            .onChange(of: sheet.selection) { _, _ in if editor.editing == nil { focus.focus(sheet.selection.first) } }
            .onChange(of: editor.menu.isOpen) { _, isOpen in
                guard !isOpen else { focus.focus(nil); return }
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
