import AppKit
import SwiftUI


struct DocumentFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

public struct EditorCanvas: View {
    @Environment(EditorModel.self) private var editor

    public enum Mode: Equatable {
        case document
        case Search
    }

    let mode: Mode
    let onSubmit: (() -> Void)?

    public init(mode: Mode = .document, onSubmit: (() -> Void)? = nil) {
        self.mode = mode
        self.onSubmit = onSubmit
    }

    public var body: some View {
        switch mode {
        case .document: documentBody
        case .Search: SearchBody
        }
    }

    private var documentBody: some View {
        GeometryReader { geometry in
            ScrollView {
                editorContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: DocumentFrameKey.self,
                                value: proxy.frame(in: .named(EditorContentView.canvasSpace))
                            )
                        }
                    )
            }
            .coordinateSpace(name: EditorContentView.canvasSpace)
            .onPreferenceChange(DocumentFrameKey.self) { editor.documentFrame = $0 }
            .overlay(alignment: .topLeading) { menuOverlay(in: geometry.size) }
        }
    }

    private var SearchBody: some View {
        editorContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .coordinateSpace(name: EditorContentView.canvasSpace)
            .onPreferenceChange(DocumentFrameKey.self) { editor.documentFrame = $0 }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: DocumentFrameKey.self,
                        value: proxy.frame(in: .named(EditorContentView.canvasSpace))
                    )
                }
            )
            .overlay(alignment: .topLeading) {
                GeometryReader { geometry in
                    menuOverlay(in: geometry.size)
                }
            }
    }

    private var editorContent: some View {
        EditorContentView(
            onCommand: { selector in handleCommand(selector) },
            onTextChange: {
                if mode == .Search, editor.sheet.dirty {
                    editor.sheet.sync()
                }
            }
        )
    }

    private func handleCommand(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            if NSEvent.modifierFlags.contains(.shift) { return false }

            guard editor.menu.isOpen else {
                guard let onSubmit else { return false }
                if editor.sheet.dirty { editor.sheet.sync() }
                DispatchQueue.main.async { onSubmit() }
                return true
            }

            DispatchQueue.main.async { editor.commitMenu() }
            return true

        case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.moveDown(_:)):
            guard editor.menu.isOpen else { return false }
            DispatchQueue.main.async { editor.moveMenuSelection(1) }
            return true

        case #selector(NSResponder.moveUp(_:)):
            guard editor.menu.isOpen else { return false }
            DispatchQueue.main.async { editor.moveMenuSelection(-1) }
            return true

        case #selector(NSResponder.moveRight(_:)):
            guard editor.menu.isOpen, editor.menu.kind == .command else { return false }
            DispatchQueue.main.async { editor.menu.openSubmenuForSelection() }
            return true

        case #selector(NSResponder.moveLeft(_:)):
            guard editor.menu.isOpen, editor.menu.kind == .command, editor.menu.presentedSubmenu != nil else { return false }
            DispatchQueue.main.async { editor.menu.closeSubmenu() }
            return true

        case #selector(NSResponder.cancelOperation(_:)):
            guard editor.menu.isOpen else { return false }
            DispatchQueue.main.async {
                if editor.menu.presentedSubmenu != nil {
                    editor.menu.closeSubmenu()
                } else {
                    editor.menu.close()
                }
            }
            return true

        default:
            return false
        }
    }

    @ViewBuilder
    private func menuOverlay(in size: CGSize) -> some View {
        if editor.menu.isOpen {
            let menuWidth = editor.menu.size.width
            let menuHeight = editor.menu.size.height
            let padding: CGFloat = 16
            let anchorRect = editor.menu.anchorRect

            let anchor = CGPoint(
                x: editor.documentFrame.minX + anchorRect.minX,
                y: editor.documentFrame.minY + anchorRect.maxY
            )
            let anchorTopY = editor.documentFrame.minY + anchorRect.minY

            let x = min(
                max(anchor.x, padding),
                max(padding, size.width - menuWidth - padding)
            )

            let viewportHeight = NSApp.mainWindow?.contentView?.bounds.height ?? size.height
            let placeAbove: Bool = {
                if mode == .Search { return true }
                let roomBelow = size.height - anchor.y
                return roomBelow < menuHeight + padding && anchorTopY > menuHeight + padding
            }()

            let rawY = placeAbove
                ? anchorTopY - menuHeight - 6
                : anchor.y + 6

            let upperBound = max(padding, size.height - menuHeight - padding)
            let lowerBound: CGFloat = mode == .Search
                ? -(viewportHeight - size.height - padding)
                : padding

            let y = min(max(rawY, lowerBound), upperBound)

            EditorMenu(position: CGPoint(x: x, y: y))
        }
    }
}
