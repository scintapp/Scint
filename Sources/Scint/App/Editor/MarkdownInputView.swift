import AppKit
import ScintRuntime
import ScintComponents


enum Exit { case previous, next }

@MainActor final class MarkdownInputView: NSTextView, NSTextViewDelegate, @preconcurrency NSTextStorageDelegate {
    let ref: Reference
    var target: EditorFocus.Target
    let focus: EditorFocus
    var listStart = 0 { didSet { if listStart != oldValue { needsDisplay = true } } }
    var onOpenLink: (EditorLink) -> Void = { _ in }
    var placeholder = "Press ‘/’ for commands"
    var commands = true
    var pending: (() -> Void)?
    let content = NSTextContentStorage()
    let textLayout = NSTextLayoutManager()
    let container = NSTextContainer(size: CGSize(width: 500, height: CGFloat.greatestFiniteMagnitude))
    let panels: PanelModel
    var document: Markdown.Document = .empty
    private var restyling: NSRange?
    private var trigger: Int?

    init(_ ref: Reference, _ target: EditorFocus.Target, focus: EditorFocus, panels: PanelModel) {
        self.ref = ref
        self.target = target
        self.focus = focus
        self.panels = panels
        content.addTextLayoutManager(textLayout); textLayout.textContainer = container
        super.init(frame: .zero, textContainer: container)
        container.widthTracksTextView = true; container.lineFragmentPadding = 0
        isRichText = false; allowsUndo = false; usesFindBar = true; isIncrementalSearchingEnabled = true
        isVerticallyResizable = false; isHorizontallyResizable = false
        drawsBackground = false; textContainerInset = .zero
        font = Typography.Prose.text; insertionPointColor = NSColor(Style.Tint.space.dull); typingAttributes = Styler.baseAttributes
        selectedTextAttributes = [.backgroundColor: NSColor.clear]
        delegate = self; textStorage?.delegate = self
        load(EditorIO(ref: ref).text(of: target.id))
    }

    required init?(coder: NSCoder) { nil }

    var source: NSString { textStorage?.mutableString ?? NSString() }

    func load(_ text: String) {
        guard !hasMarkedText(), let storage = textStorage, !source.isEqual(to: text) else { return }
        let caret = selectedRange().location
        storage.setAttributedString(NSAttributedString(string: text, attributes: typingAttributes))
        setSelectedRange(NSRange(location: min(caret, storage.length), length: 0))
        restyle()
    }

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        let previous = document
        document = Markdown.scan(textStorage.string)
        let code = { (document: Markdown.Document) in document.blocks.filter { $0.kind == .codeFence || $0.kind == .codeBlock }.count }
        let scope = restyling == nil && code(previous) == code(document)
            ? textStorage.mutableString.paragraphRange(for: editedRange) : NSRange(location: 0, length: textStorage.length)
        schedule(scope)
    }

    private func schedule(_ scope: NSRange) {
        if restyling == nil { RunLoop.main.perform(inModes: [.common]) { MainActor.assumeIsolated { self.restyle() } } }
        restyling = scope
    }

    private func restyle() {
        guard let storage = textStorage, let scope = restyling else { return }
        restyling = nil
        storage.beginEditing()
        Styler.apply(to: storage, document: document, scope: [scope])
        storage.endEditing()
        needsDisplay = true; needsLayout = true
        guard abs(height(for: container.size.width) - frame.height) > 0.5 else { return }
        invalidateIntrinsicContentSize()
        window?.contentView?.layoutSubtreeIfNeeded()
    }

    func textDidChange(_ notification: Notification) {
        restyle()
        EditorIO(ref: ref).write(target.id, string)
        updateTrigger()
    }

    func height(for width: CGFloat) -> CGFloat {
        ProseDrawing.height(of: textLayout, in: container, width: width, font: Typography.Prose.text)
    }

    func replace(_ range: NSRange, with text: String) {
        guard let storage = textStorage, NSMaxRange(range) <= storage.length,
              shouldChangeText(in: range, replacementString: text) else { return }
        storage.replaceCharacters(in: range, with: NSAttributedString(string: text, attributes: typingAttributes))
        setSelectedRange(NSRange(location: range.location + (text as NSString).length, length: 0))
        didChangeText()
    }

    func insert(_ blocks: [Document.Block], replacing range: NSRange) {
        replace(range, with: "")
        focus.insert(blocks, into: target, at: range.location)
    }

    override func paste(_ sender: Any?) {
        let chunks = NSPasteboard.general.string(forType: .string).map(Markdown.chunks) ?? []
        guard chunks.count > 1 else { return super.paste(sender) }
        insert(chunks.map { EditorIO.block(UUID(), markdown: $0) }, replacing: selectedRange())
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)
        guard !hasMarkedText() else { return }
        let typed = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
        let source = self.source, offset = selectedRange().location - 1
        guard commands, typed == "/" || typed == "@", offset >= 0 else { return }
        if offset == 0 || " \t\n".contains(source.substring(with: NSRange(location: offset - 1, length: 1))) { trigger = offset; updateTrigger() }
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

    private func atEdge(_ exit: Exit) -> Bool {
        let selection = selectedRange()
        guard selection.length == 0 else { return false }
        let caret = firstRect(forCharacterRange: selection, actualRange: nil)
        let edge = firstRect(forCharacterRange: NSRange(location: exit == .next ? source.length : 0, length: 0), actualRange: nil)
        return abs(caret.midY - edge.midY) < max(caret.height, edge.height) / 2
    }

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if panels.editor.state.presented, panels.editor.editor === self, !panels.editor.surface.form {
            switch selector {
            case #selector(moveDown(_:)), #selector(insertTab(_:)): PanelFactory.move(panels.editor.surface(panels), by: 1); return true
            case #selector(moveUp(_:)), #selector(insertBacktab(_:)): PanelFactory.move(panels.editor.surface(panels), by: -1); return true
            case #selector(insertNewline(_:)): PanelFactory.choose(panels.editor.surface(panels)); return true
            case #selector(cancelOperation(_:)): closeMenu(); return true
            default: break
            }
        }
        switch selector {
        case #selector(moveUp(_:)): return atEdge(.previous) && focus.move(from: target, .previous)
        case #selector(moveDown(_:)): return atEdge(.next) && focus.move(from: target, .next)
        case #selector(insertNewline(_:)):
            let selection = selectedRange(), source = self.source
            let line = document.blocks.first { NSLocationInRange(selection.location, $0.range) || NSMaxRange($0.range) == selection.location }
            let fences = document.blocks.filter { $0.kind == .codeFence && $0.range.location <= line?.range.location ?? 0 }.count
            if line?.kind == .codeBlock || (line?.kind == .codeFence && fences % 2 == 1) { return false }
            if let line, line.kind.isList, line.content.length == 0 { replace(line.prefix, with: ""); return true }
            let indent = line.map { source.substring(with: $0.indent) } ?? "", marker = line.map { source.substring(with: $0.marker) } ?? ""
            let continued = switch line?.kind {
                case .numbered: indent + "\((Int(marker.prefix { $0.isNumber }) ?? 0) + 1)" + marker.drop { $0.isNumber }
                case .checklist: indent + "- [ ] "
                case .bullet: indent + marker
                default: ""
            }
            return focus.split(target, source.substring(to: selection.location).trimmingCharacters(in: .newlines),
                               continued + source.substring(from: NSMaxRange(selection)).trimmingCharacters(in: .newlines))
        case #selector(insertLineBreak(_:)): insertText("\n", replacementRange: selectedRange()); return true
        case #selector(deleteBackward(_:)) where selectedRange().length == 0:
            let caret = selectedRange().location
            if let line = document.blocks.first(where: { $0.marker.length > 0 && NSMaxRange($0.prefix) == caret }) { replace(line.prefix, with: ""); return true }
            return caret == 0 && focus.join(target)
        case #selector(insertTab(_:)): return indent(by: 1)
        case #selector(insertBacktab(_:)): _ = indent(by: -1); return true
        case #selector(cancelOperation(_:)): focus.select(target, caret: selectedRange().location); return true
        default: return false
        }
    }

    private func updateTrigger() {
        guard let offset = trigger, !hasMarkedText() else { return }
        let source = self.source, caret = selectedRange()
        let typed = caret.length == 0 && caret.location > offset && caret.location <= source.length
            ? source.substring(with: NSRange(location: offset, length: caret.location - offset)) : ""
        guard let character = typed.first, "/@".contains(character), !typed.contains("\n") else { return closeMenu() }
        if panels.editor.state.presented, panels.editor.surface.form { return }
        panels.editor.open(character == "/" ? .commands : .references, in: self, query: String(typed.dropFirst()),
                           range: NSRange(location: offset, length: caret.location - offset),
                           anchor: firstRect(forCharacterRange: caret, actualRange: nil))
        presentMenu()
    }

    func presentMenu() {
        guard let window else { return }
        panels.present(panels.editor, in: window) { self.trigger = nil }
    }

    func closeMenu() {
        trigger = nil
        if panels.editor.editor === self { panels.dismiss(panels.editor) }
    }

    func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange old: NSRange, toCharacterRange new: NSRange) -> NSRange {
        guard new.length == 0,
              let line = document.blocks.first(where: { $0.marker.length > 0 && new.location >= $0.range.location && new.location < NSMaxRange($0.prefix) })
        else { return new }
        if new.location < old.location, line.range.location > 0 { return NSRange(location: line.range.location - 1, length: 0) }
        return NSRange(location: NSMaxRange(line.prefix), length: 0)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        updateTrigger()
        needsDisplay = true
    }

    private func target(of link: Markdown.Link) -> EditorLink? {
        let url = source.substring(with: link.url)
        if let reference = Runtime.shared.resolve(url) { return .reference(reference) }
        return URL(string: url).map(EditorLink.url)
    }

    private func link(at offset: Int) -> (range: NSRange, link: EditorLink)? {
        guard let match = document.links.first(where: { NSLocationInRange(offset, $0.range) }), let target = target(of: match) else { return nil }
        return (match.range, target)
    }

    var selectedLink: Markdown.Link? { document.links.first { $0.range == selectedRange() } }

    override func mouseDown(with event: NSEvent) {
        let offset = characterIndexForInsertion(at: convert(event.locationInWindow, from: nil))
        guard let match = link(at: offset) else { return super.mouseDown(with: event) }
        if event.modifierFlags.contains(.command) { return onOpenLink(match.link) }
        window?.makeFirstResponder(self)
        setSelectedRange(event.modifierFlags.contains(.shift) ? NSUnionRange(selectedRange(), match.range) : match.range)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { closeMenu() }
        guard window != nil, let pending else { return }
        self.pending = nil
        DispatchQueue.main.async(execute: pending)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder(); if result { needsDisplay = true; if focus.editing != target { focus.edit(target) } }; return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result { needsDisplay = true; if !panels.editor.surface.form { closeMenu() } }
        return result
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard flag, selectedLink == nil else { return }
        NSColor(Style.Tint.space.dull).setFill()
        NSBezierPath(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: 4, height: rect.height), xRadius: 1, yRadius: 1).fill()
    }

    override func setFrameSize(_ newSize: NSSize) {
        let resized = abs(newSize.width - frame.width) > 0.5
        super.setFrameSize(newSize)
        if resized { invalidateIntrinsicContentSize() }
    }

    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        if String(describing: type(of: subview)) == "_NSTextSelectionView" { subview.alphaValue = 0 }
    }
}
