import AppKit
import SwiftUI


struct CardView: NSViewRepresentable {
    let editor: ScintEditor
    let block: Material.Block
    weak var host: EditorDocumentView?
    func makeNSView(context: Self.Context) -> EditorCardView {
        return EditorCardView(editor: editor, block: block, host: host)
    }
    func updateNSView(_ view: EditorCardView, context: Self.Context) {
        view.block = block
        view.rootView = MaterialBlock(block: block, isSelected: editor.selectedBlockIDs.contains(block.id))
        if editor.position.id == block.id && !editor.isTextPosition && host?.ownsFocus == true { view.window?.makeFirstResponder(view) }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: EditorCardView, context: Self.Context) -> CGSize? {
        nsView.frame.size.width = proposal.width ?? 500
        return CGSize(width: proposal.width ?? 500, height: nsView.fittingSize.height)
    }
}

final class EditorCardView: NSHostingView<MaterialBlock>, NSMenuItemValidation {
    let editor: ScintEditor
    var block: Material.Block
    weak var host: EditorDocumentView?
    init(editor: ScintEditor, block: Material.Block, host: EditorDocumentView?) {
        self.editor = editor; self.block = block; self.host = host
        super.init(rootView: MaterialBlock(block: block, isSelected: editor.selectedBlockIDs.contains(block.id)))
    }
    required init(rootView: MaterialBlock) { fatalError("Use init(editor:block:host:)") }
    required init?(coder: NSCoder) { fatalError("Use init(editor:block:host:)") }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if editor.position.id == block.id, host?.ownsFocus == true { window?.makeFirstResponder(self) }
    }
    override var acceptsFirstResponder: Bool { true }
    override var undoManager: UndoManager? { editor.undoManager }
    @objc func undo(_ sender: Any?) { editor.undo() }
    @objc func redo(_ sender: Any?) { editor.redo() }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let host, Keymap.performKeyEquivalent(event, host: host) { return true }
        return super.performKeyEquivalent(with: event)
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let host else { return false }
        return Keymap.validate(menuItem, host: host) ?? true
    }

    override func becomeFirstResponder() -> Bool { let result = super.becomeFirstResponder(); if result { host?.onFocus() }; return result }
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            switch block {
            case .artifact(let ref), .command(let ref), .material(let ref): editor.open(.reference(ref))
            default: break
            }; return
        }
        let anchor: AnyHashable
        if event.modifierFlags.contains(.shift), case .blocks(let current, _) = editor.position { anchor = current }
        else { anchor = block.id }
        editor.place(.blocks(anchor: anchor, head: block.id)); window?.makeFirstResponder(self)
    }
    override func keyDown(with event: NSEvent) {
        if event.characters == " ", editor.selectedBlockIDs.count == 1 {
            host?.editCard(block, frame: window?.convertToScreen(convert(bounds, to: nil)) ?? .zero)
        } else { interpretKeyEvents([event]) }
    }
    override func doCommand(by selector: Selector) {
        if !Keymap.handle(selector, context: host?.keyContext ?? Keymap.Context(editor: editor)) { super.doCommand(by: selector) }
    }
    override func performTextFinderAction(_ sender: Any?) {
        host?.performFind(sender)
    }
}
