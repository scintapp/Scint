import AppKit
import SwiftUI

struct TextBlockView: NSViewRepresentable {
    let editor: ScintEditor
    let id: AnyHashable
    weak var host: EditorDocumentView?
    func makeNSView(context: Self.Context) -> ScintEditorView {
        let view = ScintEditorView(editor: editor, id: id, host: host)
        editor.attach(view, to: id)
        return view
    }
    func updateNSView(_ view: ScintEditorView, context: Self.Context) { view.synchronize(); view.followFocus() }
    static func dismantleNSView(_ view: ScintEditorView, coordinator: ()) { view.editor.detach(from: view.id) }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ScintEditorView, context: Self.Context) -> CGSize? {
        nsView.setFrameSize(CGSize(width: proposal.width ?? nsView.bounds.width, height: nsView.bounds.height))
        return CGSize(width: proposal.width ?? nsView.bounds.width, height: nsView.contentHeight)
    }
}

final class ScintEditorView: NSTextView, NSTextViewDelegate, TextRendering {
    let editor: ScintEditor
    let id: AnyHashable
    weak var host: EditorDocumentView?
    let content = NSTextContentStorage()
    let textLayout = NSTextLayoutManager()
    let container = NSTextContainer(size: CGSize(width: 500, height: CGFloat.greatestFiniteMagnitude))
    let styler = Styler()
    var document: Markdown.Document = .empty
    var tables: [NSRange] = []
    var listContexts: [Markdown.ListContext?] = []
    var overlays: [OverlayKey: EditorOverlayView] = [:]
    var storage: NSTextStorage { textStorage! }
    var selectedMarkdownLink: Markdown.Link? {
        guard case .text(id, let anchor, let head) = editor.position, anchor != head else { return nil }
        let range = NSRange(location: min(anchor, head), length: abs(head - anchor))
        return document.links.first { $0.range == range }
    }
    init(editor: ScintEditor, id: AnyHashable, host: EditorDocumentView?) {
        self.editor = editor; self.id = id; self.host = host
        content.addTextLayoutManager(textLayout); textLayout.textContainer = container
        super.init(frame: .zero, textContainer: container)
        container.widthTracksTextView = true; container.lineFragmentPadding = 0
        isEditable = true; isRichText = false; allowsUndo = false
        isVerticallyResizable = true; isHorizontallyResizable = false
        drawsBackground = false; textContainerInset = .zero
        delegate = self; font = styler.theme.baseFont
        insertionPointColor = styler.theme.caretColor
        storage.setAttributedString(NSAttributedString(string: editor.string(id) ?? "", attributes: styler.baseAttributes))
        scanStorage(); restyle(scope: [NSRange(location: 0, length: storage.length)])
    }
    required init?(coder: NSCoder) { fatalError("Use init(editor:id:host:)") }
    override var undoManager: UndoManager? { editor.undoManager }
    @objc func undo(_ sender: Any?) { editor.undo() }
    @objc func redo(_ sender: Any?) { editor.redo() }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let host, Keymap.performKeyEquivalent(event, host: host) { return true }
        return super.performKeyEquivalent(with: event)
    }
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if let host, let enabled = Keymap.validate(menuItem, host: host) { return enabled }
        return super.validateMenuItem(menuItem)
    }
    override func performFindPanelAction(_ sender: Any?) { host?.performFind(sender) }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] { [.string] }
    override func doCommand(by selector: Selector) {
        var context = host?.keyContext ?? Keymap.Context(editor: editor)
        context.navigate = { [weak self] in self?.navigate($0, destination: $1, extending: $2) }
        if !Keymap.handle(selector, context: context) { super.doCommand(by: selector) }
    }
    override func performTextFinderAction(_ sender: Any?) { host?.performFind(sender) }
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        if hasMarkedText() { return true }
        guard let replacementString, affectedCharRange.location != NSNotFound else { return false }
        let range = affectedCharRange.location..<NSMaxRange(affectedCharRange)
        if case .text(id, let anchor, let head) = editor.position, range == min(anchor, head)..<max(anchor, head) { editor.type(replacementString) }
        else { editor.replace(in: id, range: range, with: replacementString) }
        host?.synchronizeMenu()
        return false
    }
    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        // Cocoa owns transient IME storage; it must not publish a document edit.
        let delegate = self.delegate; self.delegate = nil
        editor.undoManager.disableUndoRegistration()
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        editor.undoManager.enableUndoRegistration()
        self.delegate = delegate
    }
    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        guard hasMarkedText() else { super.insertText(insertString, replacementRange: replacementRange); return }
        let committed = (insertString as? NSAttributedString)?.string ?? (insertString as? String) ?? ""
        // Discard the transient composition. Editor.position still describes the
        // original replacement selection, so the commit is exactly one command.
        let original = editor.string(id) ?? ""
        let delegate = self.delegate; self.delegate = nil
        editor.undoManager.disableUndoRegistration()
        unmarkText()
        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: original)
        editor.undoManager.enableUndoRegistration()
        self.delegate = delegate
        scanStorage()
        editor.type(committed)
        restyle(scope: [NSRange(location: 0, length: storage.length)])
        host?.synchronizeMenu()
    }
    func textViewDidChangeSelection(_ notification: Notification) {
        guard !hasMarkedText(), window?.firstResponder === self else { return }
        // Programmatic renderer output already equals the editor selection.
        if case .text(id, let anchor, let head) = editor.position,
           selectedRange() == NSRange(location: min(anchor, head), length: abs(head - anchor)) { return }
        let range = selectedRange()
        let head = selectionAffinity == .upstream ? range.location : NSMaxRange(range)
        editor.place(.text(id: id, anchor: head == range.location ? NSMaxRange(range) : range.location, head: head))
        host?.synchronizeMenu()
    }
    func replace(_ range: Range<Int>, with text: String) {
        let delegate = self.delegate; self.delegate = nil
        defer { self.delegate = delegate }
        let previous = document, previousTables = tables
        storage.replaceCharacters(in: NSRange(range), with: text)
        let edited = NSRange(location: range.lowerBound, length: text.utf16.count)
        if edited.length > 0 { storage.setAttributes(styler.baseAttributes, range: edited) }
        scanStorage()
        let delta = text.utf16.count - range.count
        func moved(_ offset: Int) -> Int { offset <= range.lowerBound ? offset : max(range.lowerBound, offset + delta) }
        let affectedTables = previousTables.map { table in
            NSRange(location: moved(table.location), length: max(0, moved(NSMaxRange(table)) - moved(table.location)))
        }
        let scope = document.blocks.filter { block in
            if NSIntersectionRange(block.range, edited).length > 0 || NSLocationInRange(edited.location, block.range) || NSMaxRange(block.range) == edited.location { return true }
            if affectedTables.contains(where: { NSIntersectionRange($0, block.range).length > 0 }) { return true }
            let oldOffset = block.range.location <= range.lowerBound ? block.range.location : block.range.location - delta
            return previous.blocks.first(where: { $0.range.location == oldOffset })?.kind != block.kind
        }.map(\.range)
        restyle(scope: scope); invalidateIntrinsicContentSize()
    }
    func select(anchor: Int, head: Int) {
        guard !hasMarkedText() else { return }
        setSelectedRange(NSRange(location: min(anchor, head), length: abs(head - anchor)), affinity: head < anchor ? .upstream : .downstream, stillSelecting: false)
        styleOverlays()
        scrollRangeToVisible(NSRange(location: head, length: 0))
        needsDisplay = true
    }
    func clearSelection() {
        // Collapse to the same head without publishing a new logical position.
        let delegate = self.delegate; self.delegate = nil
        setSelectedRange(NSRange(location: selectedRange().location, length: 0))
        self.delegate = delegate
        styleOverlays(); needsDisplay = true
    }
    func synchronize() {
        guard !hasMarkedText(), let next = editor.string(id), storage.string != next else { return }
        let old = Array(storage.string.utf16), new = Array(next.utf16)
        var prefix = 0, suffix = 0
        while prefix < min(old.count, new.count), old[prefix] == new[prefix] { prefix += 1 }
        while suffix < min(old.count, new.count) - prefix, old[old.count - 1 - suffix] == new[new.count - 1 - suffix] { suffix += 1 }
        let removed = old.count - prefix - suffix, inserted = new.count - prefix - suffix
        let replacement = (next as NSString).substring(with: NSRange(location: prefix, length: inserted))
        let delegate = self.delegate; self.delegate = nil
        replace(prefix..<(prefix + removed), with: replacement)
        self.delegate = delegate
        editor.reconcileText(id: id, prefix: prefix, removed: removed, inserted: inserted)
    }
    func scanStorage() {
        document = Markdown.scan(storage.string)
        tables = Markdown.tableRanges(storage.string, document: document)
        let source = storage.string as NSString
        listContexts = Markdown.listContexts(for: document.blocks.map { source.substring(with: $0.range) })
    }
    func restyle(scope: [NSRange]) {
        let delegate = self.delegate; self.delegate = nil
        styler.apply(to: storage, document: document, scope: scope)
        styleOverlays()
        typingAttributes = styler.baseAttributes
        self.delegate = delegate
        needsDisplay = true; needsLayout = true
    }
    func followFocus() {
        guard editor.position.id == id, host?.ownsFocus == true, editor.isTextPosition,
              window?.firstResponder !== self else { return }
        window?.makeFirstResponder(self)
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        followFocus()
    }
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder(); if result { host?.onFocus() }; return result
    }
    override func mouseDown(with event: NSEvent) {
        let offset = characterIndexForInsertion(at: convert(event.locationInWindow, from: nil))
        if let link = editor.linkRange(in: id, containing: offset) {
            if event.modifierFlags.contains(.command) { editor.open(link.link); return }
            editor.place(.text(id: id, anchor: link.range.lowerBound, head: link.range.upperBound))
            window?.makeFirstResponder(self); return
        }
        super.mouseDown(with: event)
    }
    override var selectedTextAttributes: [NSAttributedString.Key: Any] {
        get { selectedMarkdownLink != nil ? [.backgroundColor: NSColor.clear] : super.selectedTextAttributes }
        set { super.selectedTextAttributes = newValue }
    }
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard flag, editor.isTextPosition, editor.position.id == id, selectedMarkdownLink == nil else { return }
        styler.theme.caretColor.setFill()
        NSBezierPath(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: styler.theme.caretWidth, height: rect.height), xRadius: 1, yRadius: 1).fill()
    }
    override func setFrameSize(_ newSize: NSSize) {
        guard frame.size != newSize else { return }
        super.setFrameSize(newSize)
        if container.size.width != newSize.width {
            container.containerSize = CGSize(width: newSize.width, height: CGFloat.greatestFiniteMagnitude)
        }
    }
    var contentHeight: CGFloat {
        textLayout.ensureLayout(for: textLayout.documentRange)
        return max(Typography.Prose.appKitText.ascender - Typography.Prose.appKitText.descender + Typography.Prose.paragraphStyle.paragraphSpacing, textLayout.usageBoundsForTextContainer.maxY)
    }
    override var intrinsicContentSize: NSSize { CGSize(width: NSView.noIntrinsicMetric, height: contentHeight) }
    override func layout() { super.layout(); layoutOverlays() }
}
