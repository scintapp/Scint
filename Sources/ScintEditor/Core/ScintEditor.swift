import AppKit


final class ScintEditor: NSTextView, NSTextViewDelegate, @preconcurrency NSTextStorageDelegate {
    let material: Reference
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
    private var saved: [Material.Block] = []
    private var restyling: NSRange?
    private var trigger: Int?
    private var reference: Reference?

    init(_ material: Reference, autofocus: Bool) {
        self.material = material; self.autofocus = autofocus
        content.addTextLayoutManager(textLayout); textLayout.textContainer = container
        super.init(frame: .zero, textContainer: container)
        container.widthTracksTextView = true; container.lineFragmentPadding = 0
        isRichText = false; allowsUndo = true; usesFindBar = true; isIncrementalSearchingEnabled = true
        isVerticallyResizable = true; isHorizontallyResizable = false; autoresizingMask = [.width]
        drawsBackground = false; textContainerInset = .zero
        font = styler.theme.baseFont; insertionPointColor = styler.theme.caretColor; typingAttributes = styler.baseAttributes
        selectedTextAttributes = [.backgroundColor: NSColor.clear]
        delegate = self; textStorage?.delegate = self
        load(Material.with(material, { $0.blocks }) ?? [])
        setSelectedRange(NSRange(location: (string as NSString).length, length: 0))
    }

    required init?(coder: NSCoder) { nil }

    func load(_ blocks: [Material.Block]) {
        guard blocks != saved, !hasMarkedText(), let storage = textStorage else { return }
        saved = blocks
        let caret = selectedRange().location
        storage.setAttributedString(Self.render(blocks))
        history.removeAllActions()
        setSelectedRange(NSRange(location: min(caret, storage.length), length: 0))
        restyle()
    }

    private func save() {
        guard let storage = textStorage else { return }
        let blocks = Self.blocks(in: storage, reusing: saved)
        guard blocks != saved else { return }
        saved = blocks
        Material.update(material) { material in
            let old = material.blocks
            let prefix = zip(old, blocks).prefix(while: { $0 == $1 }).count
            let suffix = zip(old[prefix...].reversed(), blocks[prefix...].reversed()).prefix(while: { $0 == $1 }).count
            for _ in prefix..<(old.count - suffix) { material.delete(at: prefix) }
            material.insert(Array(blocks[prefix..<(blocks.count - suffix)]), at: prefix)
        }
    }

    // Every character edit passes through here: typing, undo, find and replace, reloads.
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        let previous = document
        document = Markdown.scan(textStorage.string)
        tables = Markdown.tableRanges(textStorage.string, document: document)
        // A fence restyles every line after it, as does a second edit before styling catches up.
        let code = { (document: Markdown.Document) in document.blocks.filter { $0.kind == .codeFence || $0.kind == .codeBlock }.count }
        let scope = restyling == nil && code(previous) == code(document)
            ? (textStorage.string as NSString).paragraphRange(for: editedRange) : NSRange(location: 0, length: textStorage.length)
        schedule(scope)
        save()
        needsDisplay = true
        enclosingScrollView?.invalidateIntrinsicContentSize()
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

    /// Lays the text out at `width`. TextKit keeps the old layout after a container resize unless told otherwise.
    func height(for width: CGFloat) -> CGFloat {
        if abs(container.size.width - width) > 0.5 {
            container.size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            textLayout.invalidateLayout(for: textLayout.documentRange)
        }
        textLayout.ensureLayout(for: textLayout.documentRange)
        let font = styler.theme.baseFont
        return max(font.ascender - font.descender + Typography.Prose.paragraphStyle.paragraphSpacing, textLayout.usageBoundsForTextContainer.maxY)
    }

    // MARK: Editing

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

    /// Inserts a card on its own line in place of `range`.
    func insert(_ block: Material.Block, replacing range: NSRange) {
        let source = string as NSString
        guard NSMaxRange(range) <= source.length else { return }
        let card = NSMutableAttributedString(attributedString: NSAttributedString(attachment: CardAttachment(block)))
        if range.location > 0, source.character(at: range.location - 1) != 10 { card.insert(NSAttributedString(string: "\n"), at: 0) }
        if NSMaxRange(range) < source.length, source.character(at: NSMaxRange(range)) != 10 { card.append(NSAttributedString(string: "\n")) }
        replace(range, with: card)
    }

    func replaceCard(_ id: AnyHashable, with block: Material.Block) {
        guard let range = range(of: id) else { return }
        replace(range, with: NSAttributedString(attachment: CardAttachment(block)))
    }

    func card(_ id: AnyHashable) -> CardAttachment? {
        range(of: id).flatMap { textStorage?.attribute(.attachment, at: $0.location, effectiveRange: nil) as? CardAttachment }
    }

    private func range(of id: AnyHashable) -> NSRange? {
        var result: NSRange?
        textStorage?.enumerateAttribute(.attachment, in: NSRange(location: 0, length: (string as NSString).length)) { value, range, stop in
            guard (value as? CardAttachment)?.block.id == id else { return }
            result = NSRange(location: range.location, length: 1); stop.pointee = true
        }
        return result
    }

    private func isCard(at location: Int) -> Bool {
        guard location >= 0, location < (string as NSString).length else { return false }
        return textStorage?.attribute(.attachment, at: location, effectiveRange: nil) is CardAttachment
    }

    private var selectedCard: CardAttachment? {
        let range = selectedRange()
        return range.length == 1 && isCard(at: range.location) ? textStorage?.attribute(.attachment, at: range.location, effectiveRange: nil) as? CardAttachment : nil
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        let typed = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
        if typed == " ", let card = selectedCard { return editCard(card) }
        guard !hasMarkedText() else { return super.insertText(string, replacementRange: replacementRange) }
        // Text typed beside a card starts a new line, so the card keeps its own.
        let range = replacementRange.location == NSNotFound ? selectedRange() : replacementRange
        let before = isCard(at: range.location - 1) && !typed.hasPrefix("\n"), after = isCard(at: NSMaxRange(range)) && !typed.hasSuffix("\n")
        super.insertText((before ? "\n" : "") + typed + (after ? "\n" : ""), replacementRange: replacementRange)
        if after { setSelectedRange(NSRange(location: selectedRange().location - 1, length: 0)) }
        let source = self.string as NSString, offset = selectedRange().location - 1
        guard typed == "/" || typed == "@", offset >= 0 else { return }
        if offset == 0 || " \t\n".contains(source.substring(with: NSRange(location: offset - 1, length: 1))) { trigger = offset; updateTrigger() }
    }

    // Deleting a card also deletes one of its separators, so the lines around it rejoin.
    func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?) -> Bool {
        let source = string as NSString
        guard replacementString == "", range.length > 0, range.length < source.length, !history.isUndoing, !history.isRedoing,
              range.location == 0 || source.character(at: range.location - 1) == 10,
              NSMaxRange(range) == source.length || source.character(at: NSMaxRange(range)) == 10 else { return true }
        var card = false
        textStorage?.enumerateAttribute(.attachment, in: range) { value, _, stop in card = value is CardAttachment; stop.pointee = ObjCBool(card) }
        guard card else { return true }
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
        let source = string as NSString, caret = selectedRange()
        let typed = caret.length == 0 && caret.location > offset && caret.location <= source.length
            ? source.substring(with: NSRange(location: offset, length: caret.location - offset)) : ""
        guard let character = typed.first, "/@".contains(character), !typed.contains("\n") else { return cancelMenu() }
        if menuController.isOpen, case .create = menuController.kind { return }
        menuController.open(kind: character == "/" ? .fixed : .dynamic, query: String(typed.dropFirst()), target: material,
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
        textStorage?.enumerateAttribute(.attachment, in: NSRange(location: 0, length: (string as NSString).length)) { value, range, _ in
            (value as? CardAttachment)?.isSelected = NSIntersectionRange(range, selection).length > 0
        }
        for overlay in overlays.values { overlay.isSelected = NSIntersectionRange(overlay.sourceRange, selection).length > 0 }
        var selected = selectedCard?.reference
        if let link = selectedLink, case .reference(let ref)? = self.link(at: link.range.location)?.link { selected = ref }
        if selected != reference { reference = selected; ReferenceSelection.shared.selected = selected }
        needsDisplay = true
    }

    func link(at offset: Int) -> (range: NSRange, link: EditorLink)? {
        guard let match = document.links.first(where: { NSLocationInRange(offset, $0.range) }) else { return nil }
        let url = (string as NSString).substring(with: match.url)
        if let reference = Reference.Link.reference(in: url) { return (match.range, .reference(reference)) }
        return URL(string: url).map { (match.range, .url($0)) }
    }

    var selectedLink: Markdown.Link? { document.links.first { $0.range == selectedRange() } }

    override func mouseDown(with event: NSEvent) {
        let offset = characterIndexForInsertion(at: convert(event.locationInWindow, from: nil))
        guard let match = link(at: offset) else { return super.mouseDown(with: event) }
        if event.modifierFlags.contains(.command) { return onOpenLink(match.link) }
        window?.makeFirstResponder(self); setSelectedRange(match.range)
    }

    func click(_ card: CardAttachment, with event: NSEvent) {
        guard let range = range(of: card.block.id) else { return }
        if event.modifierFlags.contains(.command) { if let ref = card.reference { onOpenLink(.reference(ref)) }; return }
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
