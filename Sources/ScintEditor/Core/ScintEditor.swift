import AppKit
import ScintRuntime
import ScintComponents


final class ScintEditor: NSTextView, NSTextViewDelegate, @preconcurrency NSTextStorageDelegate {
    let ref: Reference
    var onFocus: () -> Void = {}
    var onOpenLink: (EditorLink) -> Void = { _ in }
    let styler = Styler()
    let content = NSTextContentStorage()
    let textLayout = NSTextLayoutManager()
    let container = NSTextContainer(size: CGSize(width: 500, height: CGFloat.greatestFiniteMagnitude))
    let menuController = MenuController(items: ScintEditorMenu.menu, search: { query, kind in MainActor.assumeIsolated { ScintEditorMenu.search(query, kind: kind) } })
    let presenter = MenuPanelPresenter()
    let history = UndoManager()
    var document: Markdown.Document = .empty
    var tables: [NSRange] = []
    var overlays: [OverlayKey: EditorOverlayView] = [:]
    private let autofocus: Bool
    private var restyling: NSRange?
    private var trigger: Int?
    private var reference: Reference?

    init(_ document: Reference, autofocus: Bool) {
        self.ref = document; self.autofocus = autofocus
        content.addTextLayoutManager(textLayout); textLayout.textContainer = container
        super.init(frame: .zero, textContainer: container)
        container.widthTracksTextView = true; container.lineFragmentPadding = 0
        isRichText = false; allowsUndo = true; usesFindBar = true; isIncrementalSearchingEnabled = true
        isVerticallyResizable = true; isHorizontallyResizable = false; autoresizingMask = [.width]
        drawsBackground = false; textContainerInset = .zero
        font = styler.theme.baseFont; insertionPointColor = styler.theme.caretColor; typingAttributes = styler.baseAttributes
        selectedTextAttributes = [.backgroundColor: NSColor.clear]
        delegate = self; textStorage?.delegate = self
        load()
        setSelectedRange(NSRange(location: source.length, length: 0))
    }

    required init?(coder: NSCoder) { nil }

    /// The text as the storage holds it. Bridging `string` to Swift copies the whole document.
    var source: NSString { textStorage?.mutableString ?? NSString() }

    /// The document's blocks, read from the store.
    var blocks: [Document.Block] { Document.with(ref, { $0.blocks }) ?? [] }

    /// Shows the stored blocks, unless the text already holds them.
    func load() {
        let blocks = self.blocks
        guard !hasMarkedText(), let storage = textStorage, Self.blocks(in: storage, reusing: blocks) != blocks else { return }
        let caret = selectedRange().location
        storage.setAttributedString(Self.render(blocks))
        history.removeAllActions()
        setSelectedRange(NSRange(location: min(caret, storage.length), length: 0))
        restyle()
    }

    private func save() {
        guard let storage = textStorage else { return }
        let stored = self.blocks
        let blocks = Self.blocks(in: storage, reusing: stored)
        guard blocks != stored else { return }
        Document.update(ref) { document in
            let old = document.blocks
            let prefix = zip(old, blocks).prefix(while: { $0 == $1 }).count
            let suffix = zip(old[prefix...].reversed(), blocks[prefix...].reversed()).prefix(while: { $0 == $1 }).count
            for _ in prefix..<(old.count - suffix) { document.delete(at: prefix) }
            document.insert(Array(blocks[prefix..<(blocks.count - suffix)]), at: prefix)
        }
    }

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        let previous = document
        document = Markdown.scan(textStorage.string)
        tables = Markdown.tableRanges(textStorage.string, document: document)
        // A fence restyles every line after it, as does a second edit before styling catches up.
        let code = { (document: Markdown.Document) in document.blocks.filter { $0.kind == .codeFence || $0.kind == .codeBlock }.count }
        let scope = restyling == nil && code(previous) == code(document)
            ? textStorage.mutableString.paragraphRange(for: editedRange) : NSRange(location: 0, length: textStorage.length)
        schedule(scope)
        save()
    }

    // Styling is its own attribute edit, run before the next display. Changing attributes
    // inside a character edit makes TextKit move the selection.
    private func schedule(_ scope: NSRange) {
        if restyling == nil { RunLoop.main.perform(inModes: [.common]) { MainActor.assumeIsolated { self.restyle() } } }
        restyling = scope
    }

    /// Restyles overlays alone, unless a full restyle is already on its way.
    func restyleOverlays() {
        if restyling == nil { schedule(NSRange(location: 0, length: 0)) }
    }

    private func restyle() {
        guard let storage = textStorage, let scope = restyling else { return }
        restyling = nil
        storage.beginEditing()
        styler.apply(to: storage, document: document, scope: [scope])
        styleOverlays()
        storage.endEditing()
        needsDisplay = true; needsLayout = true
        enclosingScrollView?.invalidateIntrinsicContentSize()
    }

    func textDidChange(_ notification: Notification) { updateTrigger() }

    func height(for width: CGFloat) -> CGFloat {
        if abs(container.size.width - width) > 0.5 {
            container.size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            textLayout.invalidateLayout(for: textLayout.documentRange)
        }
        textLayout.ensureLayout(for: textLayout.documentRange)
        var bottom: CGFloat = 0
        textLayout.enumerateTextLayoutFragments(from: textLayout.documentRange.endLocation, options: [.reverse, .ensuresLayout, .ensuresExtraLineFragment]) {
            bottom = $0.layoutFragmentFrame.maxY; return false
        }
        let font = styler.theme.baseFont
        return max(font.ascender - font.descender + Typography.Prose.paragraphStyle.paragraphSpacing, textLayout.usageBoundsForTextContainer.maxY, bottom)
    }

    func replace(_ range: NSRange, with text: String) {
        replace(range, with: NSAttributedString(string: text, attributes: typingAttributes))
    }

    func replace(_ range: NSRange, with text: NSAttributedString) {
        guard let storage = textStorage, NSMaxRange(range) <= storage.length,
              shouldChangeText(in: range, replacementString: text.string) else { return }
        storage.replaceCharacters(in: range, with: text)
        setSelectedRange(NSRange(location: range.location + text.length, length: 0))
        didChangeText()
    }

    func insert(_ block: Document.Block, replacing range: NSRange) {
        let source = self.source
        guard NSMaxRange(range) <= source.length else { return }
        let card = NSMutableAttributedString(attributedString: NSAttributedString(attachment: CardAttachment(block)))
        if range.location > 0, source.character(at: range.location - 1) != 10 { card.insert(NSAttributedString(string: "\n"), at: 0) }
        if NSMaxRange(range) < source.length, source.character(at: NSMaxRange(range)) != 10 { card.append(NSAttributedString(string: "\n")) }
        replace(range, with: card)
    }

    func replaceCard(_ id: AnyHashable, with block: Document.Block) {
        guard let range = range(of: id) else { return }
        replace(range, with: NSAttributedString(attachment: CardAttachment(block)))
    }

    /// Cards in a range, or in the whole text, in order.
    func cards(in range: NSRange? = nil) -> [(range: NSRange, card: CardAttachment)] {
        var cards: [(range: NSRange, card: CardAttachment)] = []
        textStorage?.enumerateAttribute(.attachment, in: range ?? NSRange(location: 0, length: source.length)) { value, range, _ in
            if let card = value as? CardAttachment { cards.append((NSRange(location: range.location, length: 1), card)) }
        }
        return cards
    }

    func card(at location: Int) -> CardAttachment? {
        guard location >= 0, location < source.length else { return nil }
        return textStorage?.attribute(.attachment, at: location, effectiveRange: nil) as? CardAttachment
    }

    func card(_ id: AnyHashable) -> CardAttachment? { cards().first { $0.card.block.id == id }?.card }
    private func range(of id: AnyHashable) -> NSRange? { cards().first { $0.card.block.id == id }?.range }

    private var selectedCard: CardAttachment? {
        let range = selectedRange()
        return range.length == 1 ? card(at: range.location) : nil
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        let typed = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
        if typed == " ", let card = selectedCard { return editCard(card) }
        guard !hasMarkedText() else { return super.insertText(string, replacementRange: replacementRange) }
        // Text typed beside a card starts a new line, so the card keeps its own.
        let range = replacementRange.location == NSNotFound ? selectedRange() : replacementRange
        let before = card(at: range.location - 1) != nil && !typed.hasPrefix("\n"), after = card(at: NSMaxRange(range)) != nil && !typed.hasSuffix("\n")
        super.insertText((before ? "\n" : "") + typed + (after ? "\n" : ""), replacementRange: replacementRange)
        if after { setSelectedRange(NSRange(location: selectedRange().location - 1, length: 0)) }
        let source = self.source, offset = selectedRange().location - 1
        guard typed == "/" || typed == "@", offset >= 0 else { return }
        if offset == 0 || " \t\n".contains(source.substring(with: NSRange(location: offset - 1, length: 1))) { trigger = offset; updateTrigger() }
    }

    // Deleting a card also deletes one of its separators, so the lines around it rejoin.
    func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?) -> Bool {
        let source = self.source
        guard replacementString == "", range.length > 0, range.length < source.length, !history.isUndoing, !history.isRedoing,
              range.location == 0 || source.character(at: range.location - 1) == 10,
              NSMaxRange(range) == source.length || source.character(at: NSMaxRange(range)) == 10 else { return true }
        guard !cards(in: range).isEmpty else { return true }
        replace(NSMaxRange(range) < source.length ? NSRange(location: range.location, length: range.length + 1)
                                                  : NSRange(location: range.location - 1, length: range.length + 1), with: "")
        return false
    }

    private func indent(by levels: Int) -> Bool {
        let selection = selectedRange()
        guard let block = document.blocks.first(where: { NSLocationInRange(selection.location, $0.range) || NSMaxRange($0.range) == selection.location }),
              block.kind.isList else { return false }
        let depth = max(0, block.depth + levels)
        guard depth != block.depth else { return true }
        let indent = String(repeating: " ", count: depth * Markdown.indentWidth)
        replace(block.indent, with: indent)
        setSelectedRange(NSRange(location: max(block.range.location, selection.location + (indent as NSString).length - block.indent.length), length: selection.length))
        return true
    }

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if menuController.isOpen, menuController.isInserting {
            switch selector {
            case #selector(moveDown(_:)), #selector(insertTab(_:)): menuController.moveSelection(1); return true
            case #selector(moveUp(_:)), #selector(insertBacktab(_:)): menuController.moveSelection(-1); return true
            case #selector(insertNewline(_:)): commitMenu(); return true
            case #selector(cancelOperation(_:)): cancelMenu(); return true
            default: break
            }
        }
        switch selector {
        case #selector(insertTab(_:)): return indent(by: 1)
        case #selector(insertBacktab(_:)): _ = indent(by: -1); return true
        case #selector(insertNewline(_:)) where selectedCard != nil:
            setSelectedRange(NSRange(location: NSMaxRange(selectedRange()), length: 0)); return true
        case #selector(cancelOperation(_:)): window?.makeFirstResponder(nil); return true
        default: return false
        }
    }

    override var undoManager: UndoManager? { history }
    @objc func undo(_ sender: Any?) { history.undo() }
    @objc func redo(_ sender: Any?) { history.redo() }

    override func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(undo(_:)): history.canUndo
        case #selector(redo(_:)): history.canRedo
        default: super.validateMenuItem(item)
        }
    }

    // MARK: Menu

    private func updateTrigger() {
        guard let offset = trigger, !hasMarkedText() else { return }
        let source = self.source, caret = selectedRange()
        let typed = caret.length == 0 && caret.location > offset && caret.location <= source.length
            ? source.substring(with: NSRange(location: offset, length: caret.location - offset)) : ""
        guard let character = typed.first, "/@".contains(character), !typed.contains("\n") else { return cancelMenu() }
        if menuController.isOpen, case .create = menuController.kind { return }
        menuController.open(kind: character == "/" ? .fixed : .dynamic, query: String(typed.dropFirst()), target: ref,
                  replacementRange: NSRange(location: offset, length: caret.location - offset),
                  anchorRect: firstRect(forCharacterRange: caret, actualRange: nil))
        presentMenu()
    }

    func editCard(_ card: CardAttachment) {
        guard let (form, values) = ScintEditorMenu.form(for: card.block), let range = range(of: card.block.id) else { return }
        menuController.edit(form: form, values: values, target: card.block.id, anchorRect: firstRect(forCharacterRange: range, actualRange: nil))
        presentMenu()
    }

    private func presentMenu() {
        guard let window else { return }
        presenter.onEscape = { [weak self] in self?.cancelMenu() }
        presenter.onResignKey = presenter.onEscape
        let content = MenuPanelContent(controller: menuController, onSelect: { [weak self] item in self?.menuController.select(item); self?.commitMenu() },
                                       onCancel: { [weak self] in self?.cancelMenu() }, onCommit: { [weak self] in self?.commitMenu() })
        presenter.present(content, size: menuController.size, anchor: menuController.anchorRect, in: window)
    }

    private func cancelMenu() {
        trigger = nil; menuController.close(); presenter.dismiss()
    }

    private func commitMenu() {
        // No outcome means the menu moved on to a form.
        guard let outcome = menuController.commit() else { return presentMenu() }
        ScintEditorMenu.commit(outcome, editor: self)
        cancelMenu(); window?.makeFirstResponder(self)
    }

    // MARK: Selection and focus

    func textViewDidChangeSelection(_ notification: Notification) {
        updateTrigger()
        let selection = selectedRange()
        for (range, card) in cards() { card.isSelected = NSIntersectionRange(range, selection).length > 0 }
        for overlay in overlays.values { overlay.isSelected = NSIntersectionRange(overlay.sourceRange, selection).length > 0 }
        var selected = selectedCard?.reference
        if let link = selectedLink, case .reference(let ref)? = self.link(at: link.range.location)?.link { selected = ref }
        if selected != reference { reference = selected; ReferenceSelection.shared.selected = selected }
        needsDisplay = true
    }

    func target(of link: Markdown.Link) -> EditorLink? {
        let url = source.substring(with: link.url)
        if let reference = Reference.Link.reference(in: url) { return .reference(reference) }
        return URL(string: url).map(EditorLink.url)
    }

    func link(at offset: Int) -> (range: NSRange, link: EditorLink)? {
        guard let match = document.links.first(where: { NSLocationInRange(offset, $0.range) }), let target = target(of: match) else { return nil }
        return (match.range, target)
    }

    var selectedLink: Markdown.Link? { document.links.first { $0.range == selectedRange() } }

    override func mouseDown(with event: NSEvent) {
        let offset = characterIndexForInsertion(at: convert(event.locationInWindow, from: nil))
        guard let match = link(at: offset) else { return super.mouseDown(with: event) }
        activate(match.range, link: match.link, with: event)
    }

    /// A click on a link, card or overlay: command opens what it points to, anything else selects it.
    func activate(_ range: NSRange, link: EditorLink?, with event: NSEvent) {
        if event.modifierFlags.contains(.command) { if let link { onOpenLink(link) }; return }
        window?.makeFirstResponder(self)
        setSelectedRange(event.modifierFlags.contains(.shift) ? NSUnionRange(selectedRange(), range) : range)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder(); if result { needsDisplay = true; onFocus() }; return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder(); if result { needsDisplay = true }; return result
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if autofocus { window?.makeFirstResponder(self) }
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard flag, selectedLink == nil else { return }
        styler.theme.caretColor.setFill()
        NSBezierPath(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: styler.theme.caretWidth, height: rect.height), xRadius: 1, yRadius: 1).fill()
    }

    override func layout() {
        super.layout()
        layoutOverlays()
    }

    // Rewrapping changes the height SwiftUI measured.
    override func setFrameSize(_ newSize: NSSize) {
        let resized = abs(newSize.width - frame.width) > 0.5
        super.setFrameSize(newSize)
        if resized { enclosingScrollView?.invalidateIntrinsicContentSize() }
    }

    // TextKit highlights selected attachments on its own, ignoring selectedTextAttributes.
    // The editor draws the selection itself, so the system selection view stays invisible.
    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        if String(describing: type(of: subview)) == "_NSTextSelectionView" { subview.alphaValue = 0 }
    }
}
