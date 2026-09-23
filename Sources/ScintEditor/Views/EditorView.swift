import AppKit
import SwiftUI
import ScintRuntime


enum EditorLink: Equatable { case reference(Reference), url(URL) }

final class BlockText: NSView {
    let styler = Styler()
    let content = NSTextContentStorage()
    let layout = NSTextLayoutManager()
    let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    var document: Markdown.Document = .empty
    var listStart = 0 { didSet { if listStart != oldValue { needsDisplay = true } } }
    var onClick: (Int) -> Void = { _ in }

    override var isFlipped: Bool { true }

    init() {
        content.addTextLayoutManager(layout); layout.textContainer = container; container.lineFragmentPadding = 0
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    var source: NSString { content.textStorage?.mutableString ?? NSString() }

    func load(_ text: String) {
        guard let storage = content.textStorage, !source.isEqual(to: text) else { return }
        document = Markdown.scan(text)
        content.performEditingTransaction {
            storage.setAttributedString(NSAttributedString(string: text, attributes: styler.baseAttributes))
            styler.apply(to: storage, document: document, scope: [NSRange(location: 0, length: storage.length)])
        }
        needsDisplay = true
        invalidateIntrinsicContentSize()
    }

    func height(for width: CGFloat) -> CGFloat {
        ProseDrawing.height(of: layout, in: container, width: width, font: styler.theme.baseFont)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if abs(container.size.width - newSize.width) > 0.5 { _ = height(for: newSize.width); needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        ProseDrawing(layout: layout, content: content, origin: .zero, width: container.size.width, document: document, styler: styler, source: source, listStart: listStart)
            .draw(dirtyRect, selectedLink: nil)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        layout.enumerateTextLayoutFragments(from: layout.documentRange.location, options: [.ensuresLayout]) { fragment in
            let frame = fragment.layoutFragmentFrame
            if frame.intersects(dirtyRect) { fragment.draw(at: frame.origin, in: context) }
            return frame.minY < dirtyRect.maxY
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let selection = layout.textSelectionNavigation.textSelections(
            interactingAt: point, inContainerAt: layout.documentRange.location, anchors: [], modifiers: [], selecting: false, bounds: .zero
        ).first
        onClick(selection?.textRanges.first.map { content.offset(from: content.documentRange.location, to: $0.location) } ?? source.length)
    }
}

struct BlockTextView: NSViewRepresentable {
    let text: String
    var listStart = 0
    var onClick: (Int) -> Void = { _ in }

    func makeNSView(context: Self.Context) -> BlockText { BlockText() }

    func updateNSView(_ view: BlockText, context: Self.Context) {
        view.onClick = onClick; view.listStart = listStart
        view.load(text)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView view: BlockText, context: Self.Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        return CGSize(width: width, height: view.height(for: width))
    }
}

struct EditorView: NSViewRepresentable {
    let text: String
    var focus: BlockList.Focus?
    var onFocus: () -> Void = {}
    var onChange: (String) -> Void = { _ in }
    var onInsert: ([ScintRuntime.Document.Block], Int) -> Void = { _, _ in }
    var onExit: (ScintEditor.Exit) -> Bool = { _ in false }
    var onSplit: (String, String) -> Bool = { _, _ in false }
    var onDeleteAtStart: () -> Bool = { false }
    var onEscape: (Int) -> Bool = { _ in false }
    var listStart = 0
    var onOpenLink: (EditorLink) -> Void = { _ in }
    var placeholder = "Press ‘/’ for commands"
    var commands = true

    final class Coordinator { var handled: UUID? }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Self.Context) -> ScintEditor {
        ScintEditor(text)
    }

    func updateNSView(_ editor: ScintEditor, context: Self.Context) {
        editor.onFocus = onFocus; editor.onChange = onChange; editor.onInsert = onInsert
        editor.onExit = onExit; editor.onOpenLink = onOpenLink
        editor.onSplit = onSplit; editor.onDeleteAtStart = onDeleteAtStart; editor.onEscape = onEscape; editor.listStart = listStart
        editor.placeholder = placeholder; editor.commands = commands
        editor.load(text)
        guard let focus, focus.request != context.coordinator.handled else { return }
        context.coordinator.handled = focus.request
        guard editor.window?.firstResponder !== editor else { return }
        let take = {
            editor.window?.makeFirstResponder(editor)
            let end = editor.source.length
            if let caret = focus.caret { editor.setSelectedRange(NSRange(location: min(caret, end), length: 0)) }
            else if let entry = focus.entry { editor.setSelectedRange(NSRange(location: entry == .next ? 0 : end, length: 0)) }
        }
        if editor.window == nil { editor.pending = take }
        else { DispatchQueue.main.async(execute: take) }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView editor: ScintEditor, context: Self.Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        return CGSize(width: width, height: editor.height(for: width))
    }
}
