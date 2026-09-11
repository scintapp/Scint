import AppKit
import SwiftUI


struct EditorInput: NSViewRepresentable {
    @Environment(EditorState.self) private var editor
    @Environment(\.editorFocus) private var focus
    let id: AnyHashable
    let ids: [AnyHashable]
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

        for id in ids { focus.register(view, for: id) }
        context.coordinator.onFocusUnregister = { for id in ids { focus.unregister(id) } }
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
        for id in ids { focus.register(view, for: id) }

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
            if selector == #selector(NSResponder.insertNewline(_:)), view.editSelectedTable() { return true }
            return onCommand(selector, view.plainSelectedRange, (view.plainText as NSString).length)
        }

        func textDidBeginEditing(_ notification: Notification) {
            reportCaretRect()
            onFocusGained()
            scheduleCaretScroll()
        }

        func textDidEndEditing(_ notification: Notification) {
            view?.restoreTablePresentation()
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

final class EditorInputView: NSTextView {
    private(set) var renderedText = ""
    private var minimumLineHeight: CGFloat { Typography.Prose.appKitLineHeight }
    private let contentStorage = NSTextContentStorage()
    private let layout = NSTextLayoutManager()
    private let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    private var storage: NSTextStorage { contentStorage.textStorage! }
    private weak var styler: EditorThemer?
    private var styleRevision: Int?
    private var didConfigureView = false
    private var isRestyling = false
    var documentUndoManager: UndoManager?
    fileprivate var isApplyingTextStorageChange = false

    var plainText: String {
        guard hasAttachments else { return storage.string }

        let display = storage.string as NSString
        var result = ""
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            if let attachment = value as? any SourceAttachment { result += attachment.source }
            else { result += display.substring(with: range) }
        }
        return result
    }

    var plainSelectedRange: NSRange { sourceRange(for: selectedRange()) }

    private var hasAttachments: Bool {
        var found = false
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, _, stop in
            if value != nil { found = true; stop.pointee = true }
        }
        return found
    }

    private struct Run { let display: NSRange; let source: NSRange }

    private var runs: [Run] {
        var result: [Run] = []
        var display = 0
        var source = 0

        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            let length = (value as? any SourceAttachment).map { ($0.source as NSString).length } ?? range.length
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

    fileprivate var plainCaretRect: CGRect? {
        caretRect(at: selectedRange().location).map(styledInsertionRect)
    }

    fileprivate var screenCaretRect: CGRect? {
        guard let window, let rect = plainCaretRect else { return nil }
        return window.convertToScreen(convert(rect, to: nil))
    }

    convenience init() { self.init(frame: .zero) }

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

    override func doCommand(by selector: Selector) {
        let up = selector == #selector(NSResponder.moveUp(_:))
        let down = selector == #selector(NSResponder.moveDown(_:))

        if up || down {
            let before = selectedRange()
            if up { super.moveUp(nil) } else { super.moveDown(nil) }
            if selectedRange() != before { return }
        }

        super.doCommand(by: selector)
    }

    override func selectAll(_ sender: Any?) {
        if let delegate = delegate, delegate.textView?(self, doCommandBy: #selector(NSResponder.selectAll(_:))) == true { return }
        super.selectAll(sender)
    }

    override var acceptsFirstResponder: Bool { true }

    override var undoManager: UndoManager? { documentUndoManager ?? super.undoManager }

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

    fileprivate func setPlainSelectedRange(_ range: NSRange) { setSelectedRange(displayRange(for: range)) }

    fileprivate func render(text: String, selectedRange: NSRange) {
        isApplyingTextStorageChange = true
        defer { isApplyingTextStorageChange = false }

        if plainText != text {
            guard let styler else { return }
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

        connectTableActions()
        renderedText = text
        setPlainSelectedRange(selectedRange)
        resetTypingAttributes()
        invalidateEditorLayout()
    }

    private func connectTableActions() {
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
            guard let table = value as? MarkdownTableAttachment else { return }
            table.onEdit = { [weak self, weak table] in
                guard let self, let table else { return }
                var found: NSRange?
                self.storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: self.storage.length)) { value, range, stop in
                    if (value as? MarkdownTableAttachment) === table { found = range; stop.pointee = true }
                }
                guard let found else { return }
                self.window?.makeFirstResponder(self)
                self.setSelectedRange(found)
                _ = self.editSelectedTable()
            }
        }
    }

    @discardableResult fileprivate func editSelectedTable() -> Bool {
        let selection = selectedRange()
        guard selection.length == 1, selection.location < storage.length,
              let table = storage.attribute(.attachment, at: selection.location, effectiveRange: nil) as? MarkdownTableAttachment,
              let styler else { return false }
        isApplyingTextStorageChange = true
        defer { isApplyingTextStorageChange = false }
        let source = NSMutableAttributedString(string: table.source)
        styler.applyStyle(to: source)
        replaceTablePresentation(in: selection, with: source)
        setSelectedRange(NSRange(location: selection.location, length: 0))
        invalidateEditorLayout()
        return true
    }

    fileprivate func restoreTablePresentation() {
        guard let styler else { return }
        let source = plainText
        let selection = plainSelectedRange
        isApplyingTextStorageChange = true
        defer { isApplyingTextStorageChange = false }
        guard !Markdown.tableRanges(storage.string).isEmpty else { return }
        replaceTablePresentation(in: NSRange(location: 0, length: storage.length), with: styler.attributedString(for: source))
        connectTableActions()
        setPlainSelectedRange(selection)
        invalidateEditorLayout()
    }

    /// Presentation replacements change TextKit offsets too. Keep their inverse
    /// in native undo history so text edits never replay against collapsed ranges.
    private func replaceTablePresentation(in range: NSRange, with replacement: NSAttributedString) {
        breakUndoCoalescing()
        let previous = storage.attributedSubstring(from: range)
        let selection = selectedRange()
        let replaced = NSRange(location: range.location, length: replacement.length)
        undoManager?.registerUndo(withTarget: self) { view in
            view.replaceTablePresentation(in: replaced, with: previous)
            view.setSelectedRange(selection)
            view.connectTableActions()
            view.invalidateEditorLayout()
        }
        storage.replaceCharacters(in: range, with: replacement)
    }

    override func draw(_ dirtyRect: NSRect) {
        let document = Markdown.scan(storage.string)
        let origin = textContainerOrigin
        let frames: (NSRange) -> [CGRect] = { range in
            guard range.length > 0,
                  let start = self.contentStorage.location(self.contentStorage.documentRange.location, offsetBy: range.location),
                  let end = self.contentStorage.location(self.contentStorage.documentRange.location, offsetBy: NSMaxRange(range)),
                  let textRange = NSTextRange(location: start, end: end) else { return [] }
            var result: [CGRect] = []
            self.layout.enumerateTextSegments(in: textRange, type: .standard, options: [.rangeNotRequired]) { _, rect, _, _ in
                result.append(rect.offsetBy(dx: origin.x, dy: origin.y))
                return true
            }
            return result
        }
        for span in document.spans where span.kind == .inlineCode {
            for rect in frames(span.range) {
                MarkdownDecoration.code(rect.insetBy(dx: -Style.Spacing.sm, dy: -Style.Spacing.xs))
            }
        }
        var codeRect: CGRect?
        // Segments stop short of the spacing between lines, so a run of quote lines is gathered into one bar.
        var quoteRect: CGRect?
        for block in document.blocks {
            if block.kind == .codeBlock {
                for rect in frames(block.range) { codeRect = codeRect.map { $0.union(rect) } ?? rect }
                continue
            }
            if let rect = codeRect {
                MarkdownDecoration.code(CGRect(x: origin.x, y: rect.minY - Style.Spacing.xs, width: container.size.width, height: rect.height + Style.Spacing.sm))
                codeRect = nil
            }
            if block.kind == .quote {
                for rect in frames(block.range) { quoteRect = quoteRect.map { $0.union(rect) } ?? rect }
                continue
            }
            if let rect = quoteRect {
                NSColor(Style.Foreground.faint).setFill()
                CGRect(x: origin.x, y: rect.minY, width: Style.Dimension.markdownQuoteBar, height: rect.height).fill()
                quoteRect = nil
            }
            if block.kind == .bullet, let rect = frames(block.marker).first {
                NSColor(Style.Foreground.subtle).setFill()
                NSBezierPath(ovalIn: CGRect(x: rect.minX, y: rect.midY - Style.Dimension.markdownBullet / 2, width: Style.Dimension.markdownBullet, height: Style.Dimension.markdownBullet)).fill()
            }
        }
        if let rect = codeRect {
            MarkdownDecoration.code(CGRect(x: origin.x, y: rect.minY - Style.Spacing.xs, width: container.size.width, height: rect.height + Style.Spacing.sm))
        }
        if let rect = quoteRect {
            NSColor(Style.Foreground.faint).setFill()
            CGRect(x: origin.x, y: rect.minY, width: Style.Dimension.markdownQuoteBar, height: rect.height).fill()
        }
        super.draw(dirtyRect)
    }

    override func didChangeText() {
        super.didChangeText()
        guard !isApplyingTextStorageChange else { return }
        renderedText = plainText
        resetTypingAttributes()
        invalidateEditorLayout()
    }

    func measuredSize(for proposedWidth: CGFloat?) -> CGSize {
        let font = self.font ?? .systemFont(ofSize: NSFont.systemFontSize)
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let minimum = lineHeight + textContainerInset.height * 2
        let targetWidth = proposedWidth ?? bounds.width

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

    private var selectedAttachmentRange: NSRange? {
        let selected = selectedRange()
        guard selected.length > 0 else { return nil }

        var found: NSRange?
        storage.enumerateAttribute(.attachment, in: selected) { value, range, stop in
            guard value is any SourceAttachment, range == selected else { return }
            found = range
            stop.pointee = true
        }
        return found
    }

    override var selectedTextAttributes: [NSAttributedString.Key: Any] {
        get { selectedAttachmentRange == nil ? super.selectedTextAttributes : [:] }
        set { super.selectedTextAttributes = newValue }
    }

    private func attachmentRange(at point: NSPoint) -> NSRange? {
        guard hasAttachments else { return nil }

        let origin = textContainerOrigin
        let local = NSPoint(x: point.x - origin.x, y: point.y - origin.y)
        layout.ensureLayout(for: layout.documentRange)

        var found: NSRange?
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, stop in
            guard value is any SourceAttachment,
                  let start = contentStorage.location(contentStorage.documentRange.location, offsetBy: range.location),
                  let end = contentStorage.location(contentStorage.documentRange.location, offsetBy: NSMaxRange(range)),
                  let textRange = NSTextRange(location: start, end: end)
            else { return }

            layout.enumerateTextSegments(in: textRange, type: .standard, options: [.rangeNotRequired]) { _, frame, _, _ in
                guard frame.contains(local) else { return true }
                found = range
                return false
            }

            if found != nil { stop.pointee = true }
        }
        return found
    }

    override func mouseDown(with event: NSEvent) {
        guard let range = attachmentRange(at: convert(event.locationInWindow, from: nil)) else {
            super.mouseDown(with: event)
            return
        }

        if window?.firstResponder !== self { window?.makeFirstResponder(self) }
        setSelectedRange(range)
        if event.clickCount == 2 { _ = editSelectedTable() }
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

    override func setNeedsDisplay(_ invalidRect: NSRect, avoidAdditionalLayout flag: Bool) {
        var rect = invalidRect
        rect.size.width = max(rect.width, (styler?.theme.caretWidth ?? 1) + 1)
        super.setNeedsDisplay(rect, avoidAdditionalLayout: flag)
    }

    private func resetTypingAttributes() {
        guard let styler else { return }
        insertionPointColor = styler.theme.caretColor
        typingAttributes = styler.typingAttributes
    }

    private func restyle(coalescing: Bool = true, in scope: NSRange? = nil) {
        guard let styler, !isRestyling else { return }
        isRestyling = true
        if coalescing { storage.beginEditing() }
        styler.applyStyle(to: storage, in: scope)
        if coalescing { storage.endEditing() }
        isRestyling = false
    }

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
    func textStorage( _ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        restyle(coalescing: false, in: editedRange)
    }
}
