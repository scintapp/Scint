import AppKit
import ScintComponents
import ScintRuntime
import SwiftUI


/// One text block's surface: TextKit 2, sized to its own content, styled by the app's
/// shared markdown grammar. It knows nothing of blocks, menus or components — it reports
/// what its text and caret did and lets the canvas decide what that means.
final class EditTextView: NSTextView {
    private static let styler = Styler()

    private let content = NSTextContentStorage()
    private let layout = NSTextLayoutManager()
    private let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))

    /// The text the host last pushed, so an echo of our own edit isn't re-rendered.
    private(set) var rendered = ""
    private(set) var isRestyling = false

    /// Set while the host wants the navigation keys, because it is showing something of
    /// its own. The surface does not know or care what.
    var defers = false
    var onEvent: (EditEvent) -> Bool = { _ in false }

    private var markdown: Markdown.Document = .empty
    private var reported: EditTrigger?
    private var entry: EditEdge?

    convenience init() { self.init(frame: .zero) }

    override init(frame: NSRect) {
        layout.textContainer = container
        content.addTextLayoutManager(layout)
        content.primaryTextLayoutManager = layout
        super.init(frame: frame, textContainer: container)
        configure()
    }

    required init?(coder: NSCoder) { nil }

    private func configure() {
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        container.lineFragmentPadding = 0
        isEditable = true
        isSelectable = true
        isRichText = true
        allowsUndo = true
        isHorizontallyResizable = false
        isVerticallyResizable = false
        autoresizingMask = [.width]
        drawsBackground = false
        wantsLayer = false
        textContainerInset = NSSize(width: Typography.Prose.codeInset, height: Style.Spacing.detail)
        minSize = NSSize(width: 0, height: lineHeight)
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isGrammarCheckingEnabled = false
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        font = Self.styler.theme.baseFont
        textColor = Self.styler.theme.textColor
        insertionPointColor = Self.styler.theme.caretColor
        typingAttributes = Self.styler.baseAttributes
    }

    // MARK: Focus

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { _ = onEvent(.focused) }
        return became
    }

    func takeFocus(at edge: EditEdge?) {
        guard let edge else { return }
        entry = edge
        place(edge)
    }

    private func place(_ edge: EditEdge) {
        let length = (string as NSString).length
        let location = switch edge {
            case .start: 0
            case .end: length
            case .offset(let offset): min(max(offset, 0), length)
        }
        setSelectedRange(NSRange(location: location, length: 0))
    }

    // MARK: Text

    /// Text pushed down from the host. A caret the host asked for wins over the one on
    /// screen, because it was chosen against text this surface had not received yet.
    func render(_ text: String) {
        let pending = entry
        apply(text, selection: selectedRange())
        if let pending { place(pending); entry = nil }
    }

    /// The surface's own text changed: report it, then restyle around the caret.
    func edited() {
        guard !isRestyling else { return }
        // The AppKit edit is finished; report its value and nothing else. No trigger
        // detection, no restyle, no block mutation from inside the notification.
        _ = onEvent(.changed(string))
        entry = nil
    }

    /// The caret moved. A trigger is only re-read while one is already live, so putting
    /// the caret back beside an old `/` doesn't summon anything.
    func movedCaret() {
        guard !isRestyling, reported != nil else { return }
        report(detect())
    }

    /// Styling is an attribute edit and TextKit moves the selection during it, so the
    /// caret is put back afterwards and the restyle stays out of the undo stack.
    private func apply(_ text: String, selection: NSRange) {
        let undoWasOn = undoManager?.isUndoRegistrationEnabled ?? false
        isRestyling = true
        if undoWasOn { undoManager?.disableUndoRegistration() }

        markdown = Markdown.scan(text)
        let styled = NSMutableAttributedString(string: text, attributes: Self.styler.baseAttributes)
        Self.styler.apply(to: styled, document: markdown, scope: [NSRange(location: 0, length: styled.length)])
        if let storage = content.textStorage { storage.setAttributedString(styled) }
        else { content.attributedString = styled }
        content.synchronizeTextLayoutManagers(nil)

        if undoWasOn { undoManager?.enableUndoRegistration() }
        rendered = text
        setSelectedRange(Self.clamp(selection, in: text))
        // Only the typing attributes: `font` and `textColor` are whole-text setters on
        // NSTextView and would flatten everything the styler just applied.
        typingAttributes = Self.styler.baseAttributes
        isRestyling = false

        needsDisplay = true
    }

    static func clamp(_ range: NSRange, in string: String) -> NSRange {
        let length = (string as NSString).length
        let location = min(max(range.location, 0), length)
        return NSRange(location: location, length: min(max(range.length, 0), length - location))
    }

    // MARK: Trigger

    private func report(_ trigger: EditTrigger?) {
        guard trigger != reported else { return }
        reported = trigger
        _ = onEvent(.trigger(trigger))
    }

    /// A `/` or `@` standing at a word boundary behind the caret, with everything typed
    /// since as its query.
    private func detect() -> EditTrigger? {
        let source = string as NSString
        let caret = selectedRange()
        guard caret.length == 0, caret.location > 0, caret.location <= source.length else { return nil }

        for index in stride(from: caret.location - 1, through: 0, by: -1) {
            let symbol = source.substring(with: NSRange(location: index, length: 1))
            if " \t\n".contains(symbol) { return nil }
            guard symbol == "/" || symbol == "@" else { continue }
            let boundary = index == 0 || " \t\n".contains(source.substring(with: NSRange(location: index - 1, length: 1)))
            guard boundary else { return nil }
            let range = NSRange(location: index, length: caret.location - index)
            return EditTrigger(
                symbol: symbol,
                query: source.substring(with: NSRange(location: index + 1, length: range.length - 1)),
                range: range,
                anchor: firstRect(forCharacterRange: range, actualRange: nil)
            )
        }
        return nil
    }

    // MARK: Keys

    /// The keys this surface hands up: a delete that would reach past the start, escape,
    /// and the caret leaving by an edge. While deferring, Return goes up too and every
    /// vertical key is an exit, because the host is driving something with them.
    func handle(_ selector: Selector) -> Bool {
        switch selector {
            case #selector(insertNewline(_:)):
                // A newline is text and stays in the block — unless the host asked for
                // the key, in which case what it is doing with it is not this surface's
                // business.
                guard defers else { return false }
                return onEvent(.newline)

            case #selector(cancelOperation(_:)):
                return onEvent(.escape)

            case #selector(moveUp(_:)):
                guard defers || caretIsOnBoundary(.start) else { return false }
                return onEvent(.exit(.start))

            case #selector(insertBacktab(_:)):
                guard defers else { return false }
                return onEvent(.exit(.start))

            case #selector(moveDown(_:)), #selector(insertTab(_:)):
                guard defers || caretIsOnBoundary(.end) else { return false }
                return onEvent(.exit(.end))

            case #selector(deleteBackward(_:)):
                let caret = selectedRange()
                guard caret.location == 0, caret.length == 0 else { return false }
                return onEvent(.deleteAtStart)

            default:
                return false
        }
    }

    // NSTextView answers Return and Escape itself before the delegate ever sees them.
    override func insertNewline(_ sender: Any?) {
        if !handle(#selector(NSResponder.insertNewline(_:))) { super.insertNewline(sender) }
    }

    override func cancelOperation(_ sender: Any?) {
        if !handle(#selector(NSResponder.cancelOperation(_:))) { super.cancelOperation(sender) }
    }

    /// Geometric, not textual: a soft-wrapped paragraph has no newline to look for, so
    /// the caret's line is compared against the line at the very start or end.
    private func caretIsOnBoundary(_ edge: EditEdge) -> Bool {
        let selection = selectedRange()
        guard selection.length == 0 else { return false }
        let caret = firstRect(forCharacterRange: NSRange(location: selection.location, length: 0), actualRange: nil)
        let edgeLocation = edge == .start ? 0 : (string as NSString).length
        let boundary = firstRect(forCharacterRange: NSRange(location: edgeLocation, length: 0), actualRange: nil)
        return abs(caret.midY - boundary.midY) < max(caret.height, boundary.height) / 2
    }

    // MARK: Decorations

    /// `Styler` hides the markdown it stands in for — list markers, quote markers,
    /// fences — and reserves the room. Filling that room is the other half of the job,
    /// and without it the syntax is gone and nothing has replaced it.
    override func draw(_ dirtyRect: NSRect) {
        let source = string as NSString

        for span in markdown.spans where span.kind == .inlineCode {
            for rect in frames(for: span.range) {
                MarkdownDecoration.code(
                    rect.insetBy(dx: -Typography.Prose.codeChipPadding, dy: -Typography.Prose.codeChipPadding)
                )
            }
        }

        // Across the whole view, not the text container: the inset either side is the
        // room the box is meant to occupy.
        for rect in runs(of: .codeBlock) {
            MarkdownDecoration.code(
                CGRect(x: 0, y: rect.minY, width: bounds.width, height: rect.height)
                    .insetBy(dx: 0, dy: -Typography.Prose.codeBlockPadding)
            )
        }

        Self.styler.theme.bulletColor.setFill()
        let bar = textContainerOrigin.x + Typography.Prose.listInset
        + (Typography.Prose.markerWidth - Typography.Prose.quoteBarWidth) / 2
        for rect in runs(of: .quote) {
            CGRect(x: bar, y: rect.minY, width: Typography.Prose.quoteBarWidth, height: rect.height).fill()
        }

        for (index, block) in markdown.blocks.enumerated() where block.kind == .bullet || block.kind == .numbered {
            guard let line = frames(for: block.range).first else { continue }
            let gutter = CGRect(
                x: textContainerOrigin.x + Self.styler.listIndent(for: block),
                y: line.minY,
                width: Typography.Prose.markerWidth,
                height: line.height
            )
            if block.kind == .bullet {
                let size = Typography.Prose.bulletSize
                NSBezierPath(ovalIn: CGRect(x: gutter.midX - size / 2, y: gutter.midY - size / 2, width: size, height: size)).fill()
            } else {
                ("\(ordinal(at: index))." as NSString).draw(
                    at: gutter.origin,
                    withAttributes: [.font: Self.styler.theme.baseFont, .foregroundColor: Self.styler.theme.bulletColor]
                )
            }
        }

        super.draw(dirtyRect)
    }

    private func textRange(_ range: NSRange) -> NSTextRange? {
        guard let start = content.location(content.documentRange.location, offsetBy: range.location),
              let end = content.location(start, offsetBy: range.length)
                else { return nil }
        return NSTextRange(location: start, end: end)
    }

    private func frames(for range: NSRange) -> [CGRect] {
        guard let range = textRange(range) else { return [] }
        var frames: [CGRect] = []
        layout.enumerateTextSegments(in: range, type: .standard, options: [.rangeNotRequired]) { _, frame, _, _ in
            frames.append(frame.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y))
            return true
        }
        return frames
    }

    /// Consecutive lines of one kind, unioned into a single rect per run.
    private func runs(of kind: Markdown.BlockKind) -> [CGRect] {
        var rects: [CGRect] = []
        var previous = -2
        let length = (string as NSString).length
        for (index, block) in markdown.blocks.enumerated() where block.kind == kind {
            let span = NSRange(
                location: block.range.location,
                length: min(block.range.length + 1, length - block.range.location)
            )
            let lines = frames(for: span)
            guard let first = lines.first else { continue }
            let rect = lines.reduce(first) { $0.union($1) }
            if index == previous + 1, let last = rects.popLast() { rects.append(last.union(rect)) }
            else { rects.append(rect) }
            previous = index
        }
        return rects
    }

    /// Counts back through items at the same depth, skipping deeper ones, until the list
    /// changes.
    private func ordinal(at index: Int) -> Int {
        let depth = markdown.blocks[index].depth
        var ordinal = 1
        for block in markdown.blocks[..<index].reversed() {
            guard block.kind.isList, block.depth >= depth else { break }
            guard block.depth == depth else { continue }
            guard block.kind == .numbered else { break }
            ordinal += 1
        }
        return ordinal
    }

    // MARK: Links

    override func mouseDown(with event: NSEvent) {
        let offset = characterIndexForInsertion(at: convert(event.locationInWindow, from: nil))
        guard let match = markdown.links.first(where: { NSLocationInRange(offset, $0.range) }) else {
            return super.mouseDown(with: event)
        }
        guard event.modifierFlags.contains(.command) else {
            window?.makeFirstResponder(self)
            // The styler collapses the URL, so the caret has nowhere to sit inside it.
            return setSelectedRange(match.range)
        }
        open((string as NSString).substring(with: match.url))
    }

    /// Reference links go through the app's callback router; anything else to the system.
    private func open(_ url: String) {
        if let ref = Reference.Link.reference(in: url) { CallbackRouter.open(ref) }
        else if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    }

    // MARK: Sizing

    private var lineHeight: CGFloat {
        let font = self.font ?? Self.styler.theme.baseFont
        return ceil(font.ascender - font.descender + font.leading)
    }

    /// Measured at the width the host proposes, never at `bounds`, which is zero on the
    /// first pass and would lay the text out one point wide.
    func height(for width: CGFloat) -> CGFloat {
        let textWidth = max(0, width - textContainerInset.width * 2)
        if abs(container.size.width - textWidth) > 0.5 {
            container.size = CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude)
        }
        layout.ensureLayout(for: layout.documentRange)
        let inset = textContainerInset.height * 2
        return max(ceil(layout.usageBoundsForTextContainer.height) + inset, lineHeight + inset)
    }
}


struct EditText: NSViewRepresentable {
    let text: String
    let isFocused: Bool
    let entry: EditEdge?
    let defers: Bool
    let onEvent: (EditEvent) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Self.Context) -> EditTextView {
        let view = EditTextView()
        view.delegate = context.coordinator
        context.coordinator.view = view
        apply(to: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ view: EditTextView, context: Self.Context) {
        apply(to: view, coordinator: context.coordinator)
    }

    /// SwiftUI probes with unspecified and infinite widths; measuring at those tells it
    /// nothing and makes the block jump on the pass after.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView view: EditTextView, context: Self.Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        return CGSize(width: width, height: view.height(for: width))
    }

    private func apply(to view: EditTextView, coordinator: Coordinator) {
        view.onEvent = onEvent
        view.defers = defers

        // The caret the canvas asked for is placed before the text it was chosen
        // against arrives, so `render` puts it back once the text is in.
        if isFocused, let entry, coordinator.entry != entry {
            coordinator.entry = entry
            view.takeFocus(at: entry)
        }
        if view.rendered != text { view.render(text) }

        coordinator.wantsFocus = isFocused
        guard isFocused else {
            coordinator.cancelFocusRequest()
            coordinator.entry = nil
            if view.window?.firstResponder === view { view.window?.makeFirstResponder(nil) }
            return
        }

        coordinator.focusGeneration += 1
        let generation = coordinator.focusGeneration

        // AppKit first responder and SwiftUI focus settle in different passes, so the
        // claim is made after this one and re-checked in case it went stale.
        DispatchQueue.main.async { [weak view, weak coordinator] in
            guard let view, let coordinator,
                  coordinator.wantsFocus,
                  coordinator.focusGeneration == generation,
                  view.superview != nil,
                  view.window?.firstResponder !== view
                    else { return }
            view.window?.makeFirstResponder(view)
        }
    }

    static func dismantleNSView(_ view: EditTextView, coordinator: Coordinator) {
        coordinator.cancelFocusRequest()
        coordinator.entry = nil
        coordinator.view = nil
        view.delegate = nil
        view.onEvent = { _ in false }
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        weak var view: EditTextView?
        var wantsFocus = false
        var entry: EditEdge?
        var focusGeneration = 0

        func cancelFocusRequest() {
            focusGeneration += 1
            wantsFocus = false
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            view?.handle(selector) ?? false
        }

        func textDidChange(_ notification: Notification) { view?.edited() }

        func textViewDidChangeSelection(_ notification: Notification) { view?.movedCaret() }
    }
}
