import AppKit
import SwiftUI


struct EditorInput: NSViewRepresentable {
    @Environment(EditorState.self) private var editor
    @Environment(\.editorFocus) private var focus
    let id: AnyHashable
    let text: String
    let selection: NSRange?
    let isEditing: Bool
    let onTextChange: (String, NSRange) -> Void
    let onSelectionChange: (NSRange) -> Void
    let onCaretRectChange: (CGRect) -> Void
    let onFocusGained: () -> Void
    let onCommand: (Selector, NSRange, Int) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            onCaretRectChange: onCaretRectChange,
            onFocusGained: {
                focus.claim(id)
                onFocusGained()
            },
            onCommand: onCommand
        )
    }

    func makeNSView(context: Self.Context) -> EditorInputView {
        let view = EditorInputView()
        view.delegate = context.coordinator
        view.documentUndoManager = editor.material.undoManager
        view.configure(with: editor.themer, revision: editor.themeRevision)
        view.render(text: text, selectedRange: clamp(selection ?? .init(location: 0, length: 0), in: text))
        context.coordinator.view = view

        focus.register(view, for: id)
        context.coordinator.onFocusUnregister = { focus.unregister(id) }
        if isEditing { context.coordinator.beginTracking() }
        return view
    }

    func updateNSView(_ view: EditorInputView, context: Self.Context) {
        view.documentUndoManager = editor.material.undoManager
        view.configure(with: editor.themer, revision: editor.themeRevision)
        let targetSelection = clamp(selection ?? view.plainSelectedRange, in: text)
        if view.renderedText != text { view.render(text: text, selectedRange: targetSelection) }
        else if view.plainSelectedRange != targetSelection { view.setPlainSelectedRange(targetSelection) }

        context.coordinator.onTextChange = onTextChange
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onCaretRectChange = onCaretRectChange
        context.coordinator.onFocusGained = {
            focus.claim(id)
            onFocusGained()
        }
        context.coordinator.onCommand = onCommand
        context.coordinator.lastSelection = view.plainSelectedRange
        focus.register(view, for: id)

        // Never hand first responder back to the window here. Sibling `updateNSView` calls run in
        // no guaranteed order, so blanking the responder from the block being left routinely fired
        // *after* the block being entered had claimed it, dropping focus into the void. Moving
        // focus is `EditorFocusCoordinator`'s job, and `makeFirstResponder` resigns the previous
        // responder on its own.
        if isEditing { context.coordinator.beginTracking() }
        else { context.coordinator.setViewportTracking(false) }
    }

    static func dismantleNSView(_ view: EditorInputView, coordinator: Coordinator) {
        coordinator.setViewportTracking(false)
        coordinator.onFocusUnregister?()
    }

    private func clamp(_ range: NSRange, in string: String) -> NSRange {
        let length = (string as NSString).length
        let location = min(max(range.location, 0), length)
        let maxLength = length - location
        return NSRange(location: location, length: min(range.length, maxLength))
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var onTextChange: (String, NSRange) -> Void
        var onSelectionChange: (NSRange) -> Void
        var onCaretRectChange: (CGRect) -> Void
        var onFocusGained: () -> Void
        var onCommand: (Selector, NSRange, Int) -> Bool
        var onFocusUnregister: (() -> Void)?
        weak var view: EditorInputView?
        var lastSelection: NSRange?
        private weak var observedClipView: NSClipView?
        private var viewportObserver: NSObjectProtocol?

        init(onTextChange: @escaping (String, NSRange) -> Void, onSelectionChange: @escaping (NSRange) -> Void,
             onCaretRectChange: @escaping (CGRect) -> Void,
             onFocusGained: @escaping () -> Void, onCommand: @escaping (Selector, NSRange, Int) -> Bool) {
            self.onTextChange = onTextChange
            self.onSelectionChange = onSelectionChange
            self.onCaretRectChange = onCaretRectChange
            self.onFocusGained = onFocusGained
            self.onCommand = onCommand
        }

        @MainActor deinit {
            if let viewportObserver { NotificationCenter.default.removeObserver(viewportObserver) }
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard let view else { return false }
            return onCommand(selector, view.plainSelectedRange, (view.plainText as NSString).length)
        }

        func textDidBeginEditing(_ notification: Notification) {
            reportCaretRect()
            onFocusGained()
            scheduleCaretScroll()
        }

        func textDidChange(_ notification: Notification) {
            guard let view, !view.isApplyingTextStorageChange else { return }
            lastSelection = view.plainSelectedRange
            reportCaretRect()
            onTextChange(view.plainText, view.plainSelectedRange)
            scheduleCaretScroll()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let view, !view.isApplyingTextStorageChange else { return }
            let selection = view.plainSelectedRange
            guard selection != lastSelection else { return }
            lastSelection = selection
            reportCaretRect()
            onSelectionChange(selection)
            scheduleCaretScroll()
        }

        func beginTracking() {
            setViewportTracking(true)
            reportCaretRect()
            scheduleCaretScroll()
        }

        func reportCaretRect() {
            guard let view, let rect = view.screenCaretRect else { return }
            onCaretRectChange(rect)
        }

        func scheduleCaretScroll() {
            guard view != nil else { return }
            DispatchQueue.main.async { [weak view] in
                guard let view else { return }
                view.window?.contentView?.layoutSubtreeIfNeeded()
                view.scrollCaretToVisible()
            }
        }

        func setViewportTracking(_ enabled: Bool) {
            guard enabled, let clipView = view?.ancestorClipView else {
                if let viewportObserver { NotificationCenter.default.removeObserver(viewportObserver) }
                viewportObserver = nil
                observedClipView = nil
                return
            }
            guard observedClipView !== clipView else { return }

            if let viewportObserver { NotificationCenter.default.removeObserver(viewportObserver) }
            clipView.postsBoundsChangedNotifications = true
            observedClipView = clipView
            viewportObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.reportCaretRect() }
            }
        }
    }
}

/// A single `Material.Block` of text.
///
/// The view owns one TextKit 1 stack outright. It previously constructed a TextKit 2 stack and
/// then wrote through `textStorage` as well, which makes `NSTextView` spin up its compatibility
/// layout manager — leaving two live layout managers over one content store, with measurement
/// asking the one that wasn't driving the display.
final class EditorInputView: NSTextView {
    private(set) var renderedText = ""
    private var minimumLineHeight: CGFloat { Typography.Prose.appKitLineHeight }
    private let contentStorage = NSTextContentStorage()
    private let layout = NSTextLayoutManager()
    private let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    /// The character store behind the content storage. Never `NSTextView.textStorage` — touching
    /// that property is what spins up the TextKit 1 compatibility layout manager alongside this
    /// one, which is the two-stacks-over-one-store bug this view had before.
    private var storage: NSTextStorage { contentStorage.textStorage! }
    private weak var styler: EditorThemer?
    private var styleRevision: Int?
    private var didConfigureView = false
    private var isRestyling = false
    /// The document's undo manager, so typing and structural edits share one ordered history
    /// rather than two stacks that can replay into each other's changes.
    var documentUndoManager: UndoManager?
    fileprivate var isApplyingTextStorageChange = false

    /// The document's own text.
    ///
    /// Diverges from `storage.string` wherever an inline reference sits: the storage holds one
    /// attachment character, the source holds the whole `[Label](scint://…)`. Everything outside
    /// this view — the model, the lexer, the menu — speaks source, so this is what they get.
    var plainText: String {
        guard hasAttachments else { return storage.string }

        let display = storage.string as NSString
        var result = ""
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            if let attachment = value as? ReferenceAttachment { result += attachment.source }
            else { result += display.substring(with: range) }
        }
        return result
    }

    /// The selection in source coordinates.
    var plainSelectedRange: NSRange { sourceRange(for: selectedRange()) }

    private var hasAttachments: Bool {
        var found = false
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, _, stop in
            if value != nil { found = true; stop.pointee = true }
        }
        return found
    }

    /// One stretch of text that maps one-to-one, or one attachment that does not.
    private struct Run { let display: NSRange; let source: NSRange }

    private var runs: [Run] {
        var result: [Run] = []
        var display = 0
        var source = 0

        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            let length = (value as? ReferenceAttachment).map { ($0.source as NSString).length } ?? range.length
            result.append(
                Run(
                    display: NSRange(location: display, length: range.length),
                    source: NSRange(location: source, length: length)
                )
            )
            display += range.length
            source += length
        }
        return result
    }

    /// A caret inside an attachment has no meaningful source position, so it snaps to whichever
    /// end of the reference it is nearer — the chip behaves as one character, which is what makes
    /// backspace delete the whole thing.
    private func sourceOffset(forDisplay offset: Int) -> Int {
        guard hasAttachments else { return offset }
        var end = 0

        for run in runs {
            end = NSMaxRange(run.source)
            guard offset < NSMaxRange(run.display) else { continue }
            let inside = offset - run.display.location
            guard run.source.length != run.display.length else { return run.source.location + inside }
            return run.source.location + (inside > 0 ? run.source.length : 0)
        }
        return end
    }

    private func displayOffset(forSource offset: Int) -> Int {
        guard hasAttachments else { return offset }
        var end = 0

        for run in runs {
            end = NSMaxRange(run.display)
            guard offset < NSMaxRange(run.source) else { continue }
            let inside = offset - run.source.location
            guard run.source.length != run.display.length else { return run.display.location + inside }
            return run.display.location + (inside > 0 ? run.display.length : 0)
        }
        return end
    }

    private func sourceRange(for display: NSRange) -> NSRange {
        let start = sourceOffset(forDisplay: display.location)
        let end = sourceOffset(forDisplay: NSMaxRange(display))
        return NSRange(location: start, length: max(0, end - start))
    }

    private func displayRange(for source: NSRange) -> NSRange {
        let start = displayOffset(forSource: source.location)
        let end = displayOffset(forSource: NSMaxRange(source))
        let length = min(max(0, end - start), max(0, storage.length - start))
        return NSRange(location: min(start, storage.length), length: length)
    }

    fileprivate var ancestorClipView: NSClipView? {
        var ancestor = superview
        while let view = ancestor {
            if let clipView = view as? NSClipView { return clipView }
            ancestor = view.superview
        }
        return nil
    }

    /// Caret geometry straight from the layout manager.
    ///
    /// This used to go through `firstRect(forCharacterRange:actualRange:)`, which is the
    /// `NSTextInputClient` hook for placing IME candidate windows: it answers in screen space,
    /// returns the *union* rect for a range, and returns a null rect whenever layout is stale or
    /// the view is out of a window. Menu anchoring read those nulls as the origin.
    fileprivate var plainCaretRect: CGRect? {
        // Display coordinates: this is geometry, not a document position.
        caretRect(at: selectedRange().location).map(styledInsertionRect)
    }

    /// The caret in screen coordinates, for anchoring the menu window.
    ///
    /// This replaces a chain that reported the caret in view space, stored it, offset it by the
    /// block's frame in a named SwiftUI coordinate space, and then corrected again for whichever
    /// container the overlay happened to hang off. Screen space is the one frame every one of
    /// those hops was trying to reach.
    fileprivate var screenCaretRect: CGRect? {
        guard let window, let rect = plainCaretRect else { return nil }
        return window.convertToScreen(convert(rect, to: nil))
    }

    convenience init() { self.init(frame: .zero) }

    /// Blurs the editor when a click lands outside every editor view.
    ///
    /// SwiftUI controls aren't focusable `NSView`s, so clicking one doesn't move first responder
    /// on its own. The previous version of this blanked the responder on *any* click that missed
    /// the current view — including clicks landing on a sibling block — which raced the focus
    /// coordinator. It now ignores clicks that stay inside the editor and lets the coordinator
    /// move focus on its own.
    private static var defocusMonitor: Any?

    private static func installDefocusMonitorIfNeeded() {
        guard defocusMonitor == nil else { return }
        defocusMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { event in
            guard let window = event.window,
                  window.firstResponder is EditorInputView,
                  let contentView = window.contentView
            else { return event }

            var hit = contentView.hitTest(contentView.convert(event.locationInWindow, from: nil))
            while let view = hit {
                if view is EditorInputView || view is EntryResponderView { return event }
                hit = view.superview
            }

            window.makeFirstResponder(nil)
            return event
        }
    }

    override init(frame frameRect: NSRect) {
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        container.lineFragmentPadding = 0
        layout.textContainer = container
        contentStorage.addTextLayoutManager(layout)
        contentStorage.primaryTextLayoutManager = layout
        super.init(frame: frameRect, textContainer: container)
        storage.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Key handling

    // No per-selector overrides here. `NSTextView` consults its delegate's `doCommandBy` before
    // dispatching to `insertNewline(_:)` and friends, so overriding those as well meant the same
    // handler ran twice for every key it declined.

    override var acceptsFirstResponder: Bool { true }

    override var undoManager: UndoManager? { documentUndoManager ?? super.undoManager }

    // MARK: - Configuration

    fileprivate func configure(with themer: EditorThemer, revision: Int) {
        Self.installDefocusMonitorIfNeeded()
        let needsRestyle = styler !== themer || styleRevision != revision
        styler = themer
        styleRevision = revision

        if !didConfigureView {
            didConfigureView = true
            container.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            isEditable = true
            isSelectable = true
            isRichText = true
            allowsUndo = true
            maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            isHorizontallyResizable = false
            isVerticallyResizable = false
            autoresizingMask = [.width]
            wantsLayer = false
            drawsBackground = false
            textContainerInset = NSSize(width: .zero, height: Style.Spacing.sm)
            minSize = NSSize(width: 0, height: minimumLineHeight + textContainerInset.height * 2)
            isAutomaticQuoteSubstitutionEnabled = false
            isAutomaticDashSubstitutionEnabled = false
            isAutomaticTextReplacementEnabled = false
            isAutomaticSpellingCorrectionEnabled = false
            isGrammarCheckingEnabled = false
            setContentHuggingPriority(.defaultLow, for: .horizontal)
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        guard needsRestyle else { return }
        font = themer.theme.baseFont
        textColor = themer.theme.textColor
        resetTypingAttributes()
        restyle()
    }

    /// Takes a source range, which is what the model stores.
    fileprivate func setPlainSelectedRange(_ range: NSRange) { setSelectedRange(displayRange(for: range)) }

    /// Takes on a new value from the model. Characters are replaced only when they actually
    /// differ; styling happens through the storage delegate, never by swapping the storage.
    fileprivate func render(text: String, selectedRange: NSRange) {
        isApplyingTextStorageChange = true
        defer { isApplyingTextStorageChange = false }

        if plainText != text {
            guard let styler else { return }
            // The model pushing a value in is not a user edit; registering it would put a second,
            // conflicting entry on the stack for a change already recorded structurally.
            let wasEnabled = undoManager?.isUndoRegistrationEnabled ?? false
            if wasEnabled { undoManager?.disableUndoRegistration() }
            storage.replaceCharacters(
                in: NSRange(location: 0, length: storage.length),
                with: styler.attributedString(for: text)
            )
            if wasEnabled { undoManager?.enableUndoRegistration() }
        } else {
            restyle()
        }

        renderedText = text
        setPlainSelectedRange(selectedRange)
        resetTypingAttributes()
        invalidateEditorLayout()
    }

    override func didChangeText() {
        super.didChangeText()
        guard !isApplyingTextStorageChange else { return }
        renderedText = plainText
        resetTypingAttributes()
        invalidateEditorLayout()
    }

    // MARK: - Measurement

    func measuredSize(for proposedWidth: CGFloat?) -> CGSize {
        let font = self.font ?? .systemFont(ofSize: NSFont.systemFontSize)
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let minimum = lineHeight + textContainerInset.height * 2
        let targetWidth = proposedWidth ?? bounds.width

        // Before the first real layout pass the view has no width. Measuring at a 1pt container
        // reports a column of single characters — a wildly tall block that then snaps down on the
        // next pass. Report the single-line minimum until there is a width to measure against.
        guard targetWidth > 1 else { return CGSize(width: max(targetWidth, 0), height: minimum) }

        if container.containerSize.width != targetWidth {
            container.containerSize = NSSize(width: targetWidth, height: .greatestFiniteMagnitude)
        }

        layout.ensureLayout(for: layout.documentRange)
        let used = layout.usageBoundsForTextContainer
        let measured = ceil(used.height) + textContainerInset.height * 2

        return CGSize(width: targetWidth, height: max(measured, minimum))
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: measuredSize(for: bounds.width).height)
    }

    override var fittingSize: NSSize {
        let measured = measuredSize(for: bounds.width)
        return NSSize(width: measured.width, height: measured.height)
    }

    func setPanelSize(_ newSize: NSSize) {
        if container.containerSize.width != newSize.width {
            container.containerSize = NSSize(width: newSize.width, height: .greatestFiniteMagnitude)
        }
        invalidateEditorLayout()
    }

    // MARK: - Caret

    /// Caret geometry from TextKit 2 text segments.
    ///
    /// The TextKit 1 version of this walked glyph indices and line fragments and special-cased the
    /// extra line fragment at the end of the text. `enumerateTextSegments` answers directly, and
    /// keeps answering correctly once inline attachments are in the line.
    private func caretRect(at location: Int) -> CGRect? {
        let origin = textContainerOrigin
        let length = storage.length

        guard length > 0 else {
            return CGRect(origin: origin, size: CGSize(width: 1, height: minimumLineHeight))
        }

        layout.ensureLayout(for: layout.documentRange)

        let offset = min(max(location, 0), length)
        guard let position = contentStorage.location(contentStorage.documentRange.location, offsetBy: offset)
        else { return nil }
        let range = NSTextRange(location: position)

        var segment: CGRect?
        layout.enumerateTextSegments(in: range, type: .standard, options: [.rangeNotRequired]) { _, frame, _, _ in
            segment = frame
            return false
        }

        guard let segment, !segment.isNull, !segment.isInfinite else { return nil }
        return CGRect(
            x: segment.minX + origin.x,
            y: segment.minY + origin.y,
            width: 1,
            height: segment.height > 0 ? segment.height : minimumLineHeight
        )
    }

    fileprivate func scrollCaretToVisible() {
        guard let caretRect = plainCaretRect else { return }
        let targetRect = caretRect.insetBy(dx: -Style.Spacing.lg, dy: -Style.Spacing.xxxl)

        guard let clipView = ancestorClipView, let documentView = clipView.documentView else {
            scrollToVisible(targetRect)
            return
        }

        documentView.scrollToVisible(documentView.convert(targetRect, from: self))
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard let styler else {
            super.drawInsertionPoint(in: rect, color: color, turnedOn: flag)
            return
        }
        guard flag else { return }

        let caretRect = styledInsertionRect(rect)
        styler.theme.caretColor.setFill()
        NSBezierPath(
            roundedRect: caretRect,
            xRadius: caretRect.width / 2,
            yRadius: caretRect.width / 2
        ).fill()
    }

    /// Widens every invalidation to cover the caret we actually draw.
    ///
    /// `NSTextView` invalidates exactly the natural, one-point-wide insertion point rect when the
    /// caret blinks or moves. Ours is `caretWidth` wide, so the extra columns were never erased
    /// and each caret position left an imprint behind. The old code tried to patch this by
    /// tracking the last drawn rect and invalidating it by hand, which misses every invalidation
    /// AppKit issues for its own reasons — blink, scroll, resize, window activation.
    override func setNeedsDisplay(_ invalidRect: NSRect, avoidAdditionalLayout flag: Bool) {
        var rect = invalidRect
        rect.size.width = max(rect.width, (styler?.theme.caretWidth ?? 1) + 1)
        super.setNeedsDisplay(rect, avoidAdditionalLayout: flag)
    }

    // MARK: - Styling

    private func resetTypingAttributes() {
        guard let styler else { return }
        insertionPointColor = styler.theme.caretColor
        typingAttributes = styler.typingAttributes
    }

    /// `coalescing` opens an edit transaction around the attribute writes so the layout manager
    /// is invalidated once. It must be false when called from `didProcessEditing`, which is
    /// already inside one.
    private func restyle(coalescing: Bool = true) {
        guard let styler, !isRestyling else { return }
        isRestyling = true
        if coalescing { storage.beginEditing() }
        styler.applyStyle(to: storage)
        if coalescing { storage.endEditing() }
        isRestyling = false
    }

    /// Only the width is ours. The height follows the line, so the caret is the right size on a
    /// heading as well as on body text — a fixed `caretHeight` both looked wrong on headings and
    /// drew outside the rect AppKit erases.
    private func styledInsertionRect(_ rect: NSRect) -> NSRect {
        guard let styler else { return rect }
        return NSRect(
            x: rect.minX,
            y: rect.minY,
            width: max(styler.theme.caretWidth, 1),
            height: rect.height
        )
    }

    private func invalidateEditorLayout() {
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    private func clamp(_ range: NSRange, in string: String) -> NSRange {
        let length = (string as NSString).length
        let location = min(max(range.location, 0), length)
        let maxLength = length - location
        return NSRange(location: location, length: min(range.length, maxLength))
    }
}

extension EditorInputView: @preconcurrency NSTextStorageDelegate {
    /// Restyles on every character edit, attributes only.
    ///
    /// The old path rebuilt an `NSAttributedString` and called `setAttributedString` from inside
    /// `didChangeText` — replacing the entire storage on each keystroke. That drops the marked
    /// range mid-composition (so IME and dead-key accents lose characters), invalidates the undo
    /// stack's ranges, and relayouts the whole block per character. Attributes can be rewritten
    /// here freely; characters must not be.
    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        guard editedMask.contains(.editedCharacters) else { return }
        restyle(coalescing: false)
    }
}
