import SwiftUI


public struct EditorCanvas: View {
    @Environment(EditorModel.self) private var editor
    @Environment(\.editorFocus) private var focus
    let autofocus: Bool

    init(autofocus: Bool = true) {
        self.autofocus = autofocus
    }

    public var body: some View {
        EditorContent { selector, atTopLine, atBottomLine in
            editor.handleCommand(selector, atTopLine: atTopLine, atBottomLine: atBottomLine)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .coordinateSpace(name: EditorContent.canvasSpace)
        .onChange(of: editor.editing) { _, _ in focus.focus(editor.editing ?? editor.selection.first) }
        .onChange(of: editor.selection) { _, _ in if editor.editing == nil { focus.focus(editor.selection.first) } }
        .onAppear {
            if autofocus { focus.focus(editor.editing ?? editor.selection.first) }
        }
        .overlay(alignment: .topLeading) {
            if editor.menu.isOpen {
                GeometryReader { geometry in
                    menu(in: geometry.size)
                }
            }
        }
    }
    
    private func menu(in size: CGSize) -> some View {
        EditorMenu(position: menuPosition(in: size))
    }

    private func menuPosition(in size: CGSize) -> CGPoint {
        let menuWidth = editor.menu.size.width
        let menuHeight = editor.menu.size.height
        let padding: CGFloat = 16
        let anchorRect = editor.menu.anchorRect
        let anchor = CGPoint(x: anchorRect.minX, y: anchorRect.maxY)
        let anchorTopY = anchorRect.minY
        let x = min(max(anchor.x, padding), max(padding, size.width - menuWidth - padding))
        let placeAbove = size.height - anchor.y < menuHeight + padding
        let y: CGFloat

        if placeAbove {
            let preferred = anchorTopY - menuHeight - 6
            y = anchorTopY > menuHeight + padding ? max(preferred, padding) : preferred
        } else {
            let rawY = anchor.y + 6
            let upperBound = max(padding, size.height - menuHeight - padding)
            y = min(max(rawY, padding), upperBound)
        }

        return CGPoint(x: x, y: y)
    }
}
