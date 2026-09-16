import AppKit
import SwiftUI


struct DocumentView: View {
    let editor: ScintEditor
    weak var host: EditorDocumentView?
    var body: some View {
        if let host { content(host) }
    }
    private func content(_ host: EditorDocumentView) -> some View {
        VStack(alignment: .leading, spacing: Typography.Prose.paragraphStyle.paragraphSpacing) {
            ForEach(editor.blocks, id: \.id) { block in
                switch block {
                case .text: TextBlockView(editor: editor, id: block.id, host: host)
                default: CardView(editor: editor, block: block, host: host)
                }
            }
            Color.clear.frame(minHeight: 20).contentShape(Rectangle()).onTapGesture { [weak host] in
                guard let host else { return }
                guard let last = editor.blocks.last else { host.window?.makeFirstResponder(host); return }
                if case .text = last { editor.land(on: last, atEnd: true) }
                else { editor.place(.blocks(anchor: last.id, head: last.id)); editor.newline() }
                host.focusPosition()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onChange(of: editor.blocks.map(\.id)) { _, _ in editor.reconcileBlocks() }
        .background {
            MenuPanelHost(controller: host.menuController, isOpen: host.menuController.isOpen, anchor: host.menuController.anchorRect, size: host.menuController.size,
                          onSelect: { [weak host] item in host?.menuController.select(item); host?.commitMenu() },
                          onCancel: { [weak host] in host?.cancelMenu() }, onCommit: { [weak host] in host?.commitMenu() })
        }
    }
}

final class EditorDocumentView: NSView, NSMenuItemValidation, @preconcurrency NSTextFinderBarContainer {
    let editor: ScintEditor
    let sizing: EditorView.Sizing
    let autofocus: Bool
    let onFocus: () -> Void
    let onReturn: (() -> Bool)?
    let onEditCard: (AnyHashable, CGRect) -> Void
    let scroll = NSScrollView()
    let finder = NSTextFinder()
    let menuController = MenuController(items: ScintEditorMenu.menu, search: { query, kind in MainActor.assumeIsolated { ScintEditorMenu.search(query, kind: kind) } })
    var hosting: NSHostingView<DocumentView>!
    var findClient: FindClient!
    var findBarView: NSView? { didSet { oldValue?.removeFromSuperview(); if let findBarView { addSubview(findBarView) }; needsLayout = true } }
    var isFindBarVisible = false { didSet { findBarView?.isHidden = !isFindBarVisible; needsLayout = true; invalidateIntrinsicContentSize() } }
    func findBarViewDidChangeHeight() { needsLayout = true; invalidateIntrinsicContentSize() }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var undoManager: UndoManager? { editor.undoManager }
    @objc func undo(_ sender: Any?) { editor.undo() }
    @objc func redo(_ sender: Any?) { editor.redo() }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if Keymap.performKeyEquivalent(event, host: self) { return true }
        return super.performKeyEquivalent(with: event)
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        Keymap.validate(menuItem, host: self) ?? true
    }

    override func keyDown(with event: NSEvent) { interpretKeyEvents([event]) }
    override func insertText(_ insertString: Any) { editor.type((insertString as? String) ?? "") }
    override func doCommand(by selector: Selector) {
        if !Keymap.handle(selector, context: keyContext) { super.doCommand(by: selector) }
    }
    override func performTextFinderAction(_ sender: Any?) {
        performFind(sender)
    }
    init(editor: ScintEditor, sizing: EditorView.Sizing, autofocus: Bool, onFocus: @escaping () -> Void,
         onReturn: (() -> Bool)?, onEditCard: @escaping (AnyHashable, CGRect) -> Void) {
        self.editor = editor; self.sizing = sizing; self.autofocus = autofocus; self.onFocus = onFocus
        self.onReturn = onReturn; self.onEditCard = onEditCard
        super.init(frame: .zero)
        hosting = NSHostingView(rootView: DocumentView(editor: editor, host: self))
        hosting.sizingOptions = [.intrinsicContentSize]
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true
        if case .fitsContent = sizing { addSubview(hosting) }
        else { scroll.documentView = hosting; addSubview(scroll) }
        findClient = FindClient(editor: editor, host: self)
        finder.client = findClient
        if case .fitsContent = sizing { finder.findBarContainer = self } else { finder.findBarContainer = scroll }
    }
    required init?(coder: NSCoder) { fatalError("Use init(editor:sizing:autofocus:onFocus:onReturn:onEditCard:)") }
    var documentHeight: CGFloat { hosting.fittingSize.height + (isFindBarVisible ? findBarView?.frame.height ?? 0 : 0) }
    override func layout() {
        super.layout()
        if case .fitsContent = sizing {
            let barHeight = isFindBarVisible ? findBarView?.frame.height ?? 0 : 0
            findBarView?.isHidden = !isFindBarVisible
            findBarView?.frame.origin = .zero
            findBarView?.frame.size.width = bounds.width
            hosting.frame = CGRect(x: 0, y: barHeight, width: bounds.width, height: max(0, bounds.height - barHeight))
        } else {
            scroll.frame = bounds
            hosting.frame = CGRect(x: 0, y: 0, width: scroll.contentSize.width, height: max(documentHeight, scroll.contentSize.height))
        }
    }
    var ownsFocus: Bool {
        guard let responder = window?.firstResponder else { return false }
        return responder === self || (responder as? ScintEditorView)?.host === self || (responder as? EditorCardView)?.host === self
    }
    var keyContext: Keymap.Context {
        Keymap.Context(editor: editor, menu: menuController, commitMenu: commitMenu, cancelMenu: cancelMenu, onReturn: onReturn)
    }
    func descendants<T: NSView>(_ type: T.Type) -> [T] {
        func visit(_ view: NSView) -> [T] { (view as? T).map { [$0] } ?? view.subviews.flatMap(visit) }
        return subviews.flatMap(visit)
    }
    func textView(_ id: AnyHashable) -> ScintEditorView? { descendants(ScintEditorView.self).first { $0.id == id } }
    func performFind(_ sender: Any?) {
        let action = NSTextFinder.Action(rawValue: (sender as? NSMenuItem)?.tag ?? 1) ?? .showFindInterface
        performFindAction(action)
    }
    func performFindAction(_ action: NSTextFinder.Action) {
        finder.performAction(action)
    }
    func refresh() {
        let focused = ownsFocus
        hosting.rootView = DocumentView(editor: editor, host: self)
        for view in descendants(ScintEditorView.self) { view.synchronize() }
        if focused { focusPosition() }
        synchronizeMenu(); invalidateIntrinsicContentSize(); needsLayout = true
    }
    func focusPosition() {
        if case .empty = editor.position { window?.makeFirstResponder(self); return }
        if editor.isTextPosition, let id = editor.position.id, let view = textView(id) { window?.makeFirstResponder(view) }
        else if let view = descendants(EditorCardView.self).first(where: { $0.block.id == editor.position.id }) { window?.makeFirstResponder(view) }
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if autofocus { window?.makeFirstResponder(self); focusPosition() }
    }
    func synchronizeMenu() {
        guard let trigger = editor.trigger else { if menuController.isInserting { menuController.close() }; return }
        guard let text = textView(trigger.id), case .text(_, _, let head) = editor.position else { return }
        if menuController.isOpen, case .create = menuController.kind { return }
        menuController.open(kind: trigger.character == "/" ? .fixed : .dynamic, query: editor.query ?? "", target: trigger.id,
                  replacementRange: NSRange(location: trigger.offset, length: head - trigger.offset), anchorRect: text.caretScreenRect)
    }
    func cancelMenu() { editor.setTrigger(nil); menuController.close() }
    func editCard(_ block: Material.Block, frame: CGRect) {
        onEditCard(block.id, frame)
        guard let (form, values) = ScintEditorMenu.form(for: block) else { return }
        menuController.edit(form: form, values: values, target: block.id, anchorRect: frame)
    }
    func commitMenu() {
        guard let outcome = menuController.commit() else { return }
        ScintEditorMenu.commit(outcome, editor: editor)
        menuController.close(); focusPosition()
    }
}
