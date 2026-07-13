import SwiftUI


public struct EditorCanvas: View {
    @Environment(EditorState.self) private var editor
    @Environment(\.editorFocus) private var focus
    private var sheet: SheetModel { editor.sheet }
    let autofocus: Bool
    let minimumHeight: CGFloat

    init(autofocus: Bool = true, minimumHeight: CGFloat = 100) {
        self.autofocus = autofocus
        self.minimumHeight = minimumHeight
    }

    private func menu(in size: CGSize) -> some View { EditorMenu(position: menuPosition(in: size)) }

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

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .named("canvas")) { point in
                    editor.beginEditingFromCanvasClick(at: point)
                }

            SheetView(
                onTextChange: editor.write,
                onSelectionChange: editor.setCaret,
                onFocusGained: editor.focusGained,
                onCommand: editor.handleCommand
            )
            .environment(sheet)
        }
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
        .coordinateSpace(name: "canvas")
        .onChange(of: sheet.editing) { _, _ in focus.focus(sheet.editing ?? sheet.selection.first) }
        .onChange(of: sheet.selection) { _, _ in if sheet.editing == nil { focus.focus(sheet.selection.first) } }
        .onAppear {
            if autofocus { focus.focus(sheet.editing ?? sheet.selection.first) }
        }
        .overlay(alignment: .topLeading) {
            if editor.menu.isOpen {
                GeometryReader { geometry in
                    menu(in: geometry.size)
                }
            }
        }
    }
}
