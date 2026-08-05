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
    let onViewportRectChange: (CGRect) -> Void
    let onFocusGained: () -> Void
    let onCommand: (Selector, NSRange, Int) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            onCaretRectChange: onCaretRectChange,
            onViewportRectChange: onViewportRectChange,
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
        view.configure(with: editor.themer, revision: editor.themeRevision)
        view.render(text: text, selectedRange: clamp(selection ?? .init(location: 0, length: 0), in: text))
        context.coordinator.view = view

        view.onCommandFromView = { [weak coordinator = context.coordinator, weak view] selector in
            guard let coordinator, let view else { return false }
            return coordinator.onCommand(selector, view.plainSelectedRange, (view.plainText as NSString).length)
        }

        focus.register(view, for: id)
        if isEditing {
            DispatchQueue.main.async { [weak coordinator = context.coordinator] in
                coordinator?.setViewportTracking(true)
                coordinator?.reportCaretRect()
                coordinator?.scheduleCaretScroll()
            }
        }
        return view
    }

    func updateNSView(_ view: EditorInputView, context: Self.Context) {
        view.configure(with: editor.themer, revision: editor.themeRevision)
        let targetSelection = clamp(selection ?? view.plainSelectedRange, in: text)
        if view.renderedText != text { view.render(text: text, selectedRange: targetSelection) }
        else if view.plainSelectedRange != targetSelection { view.setPlainSelectedRange(targetSelection) }

        context.coordinator.onTextChange = onTextChange
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onCaretRectChange = onCaretRectChange
        context.coordinator.onViewportRectChange = onViewportRectChange
        context.coordinator.onFocusGained = {
            focus.claim(id)
            onFocusGained()
        }
        context.coordinator.onCommand = onCommand
        context.coordinator.lastSelection = view.plainSelectedRange
        focus.register(view, for: id)
        if isEditing {
            DispatchQueue.main.async { [weak coordinator = context.coordinator] in
                coordinator?.setViewportTracking(true)
                coordinator?.reportCaretRect()
                coordinator?.scheduleCaretScroll()
            }
        } else if view.window?.firstResponder === view {
            context.coordinator.setViewportTracking(false)
            view.window?.makeFirstResponder(nil)
        } else {
            context.coordinator.setViewportTracking(false)
        }
    }

    static func dismantleNSView(_ view: EditorInputView, coordinator: Coordinator) {
        coordinator.setViewportTracking(false)
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
        var onViewportRectChange: (CGRect) -> Void
        var onFocusGained: () -> Void
        var onCommand: (Selector, NSRange, Int) -> Bool
        weak var view: EditorInputView?
        var lastSelection: NSRange?
        private weak var observedClipView: NSClipView?
        private var viewportObserver: NSObjectProtocol?

        init(onTextChange: @escaping (String, NSRange) -> Void, onSelectionChange: @escaping (NSRange) -> Void,
             onCaretRectChange: @escaping (CGRect) -> Void,
             onViewportRectChange: @escaping (CGRect) -> Void,
             onFocusGained: @escaping () -> Void, onCommand: @escaping (Selector, NSRange, Int) -> Bool) {
            self.onTextChange = onTextChange
            self.onSelectionChange = onSelectionChange
            self.onCaretRectChange = onCaretRectChange
            self.onViewportRectChange = onViewportRectChange
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
            guard let view else { return }
            guard !view.isApplyingTextStorageChange else { return }
            lastSelection = view.plainSelectedRange
            reportCaretRect()
            onTextChange(view.plainText, view.plainSelectedRange)
            scheduleCaretScroll()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let view else { return }
            guard !view.isApplyingTextStorageChange else { return }
            let selection = view.plainSelectedRange
            guard selection != lastSelection else { return }
            lastSelection = selection
            reportCaretRect()
            onSelectionChange(selection)
            scheduleCaretScroll()
        }

        func reportCaretRect() {
            guard let view else { return }
            if let rect = view.plainCaretRect { onCaretRectChange(rect) }
            if let rect = view.plainViewportRect { onViewportRectChange(rect) }
        }

        func scheduleCaretScroll() {
            guard let view else { return }
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
    private static var defocusMonitor: Any?
    private(set) var renderedText = ""
    private let minimumLineHeight: CGFloat = 28
    private let backingContentStorage = NSTextContentStorage()
    private let backingTextLayoutManager = NSTextLayoutManager()
    private let backingTextContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    private weak var styler: EditorThemer?
    private var styleRevision: Int?
    private var didConfigureView = false
    fileprivate var isApplyingTextStorageChange = false
    private var lastDrawnInsertionRect = NSRect.zero

    private var currentAttributedString: NSAttributedString {
        if let textStorage { return NSAttributedString(attributedString: textStorage) }
        if let textStorage = backingContentStorage.textStorage { return NSAttributedString(attributedString: textStorage) }
        return backingContentStorage.attributedString ?? NSAttributedString(string: string)
    }

    var plainText: String { currentAttributedString.string }
    var plainSelectedRange: NSRange { selectedRange() }
    fileprivate var ancestorClipView: NSClipView? {
        var ancestor = superview
        while let view = ancestor {
            if let clipView = view as? NSClipView { return clipView }
            ancestor = view.superview
        }
        return nil
    }
    fileprivate var plainViewportRect: CGRect? {
        if let clipView = ancestorClipView {
            return convert(clipView.bounds, from: clipView)
        }
        guard let contentView = window?.contentView else { return nil }
        return convert(contentView.bounds, from: contentView)
    }
    fileprivate var plainCaretRect: CGRect? {
        guard let window else { return nil }
        let location = min(plainSelectedRange.location, (plainText as NSString).length)
        var actualRange = NSRange(location: NSNotFound, length: 0)
        let screenRect = firstRect(
            forCharacterRange: NSRange(location: location, length: 0),
            actualRange: &actualRange
        )
        guard !screenRect.isNull, !screenRect.isInfinite else { return nil }
        return styledInsertionRect(convert(window.convertFromScreen(screenRect), from: nil))
    }

    fileprivate func scrollCaretToVisible() {
        guard let caretRect = plainCaretRect else { return }
        let targetRect = caretRect.insetBy(dx: -12, dy: -48)

        guard let clipView = ancestorClipView,
              let documentView = clipView.documentView
        else {
            scrollToVisible(targetRect)
            return
        }

        let documentRect = documentView.convert(targetRect, from: self)
        documentView.scrollToVisible(documentRect)
    }
    var onCommandFromView: ((Selector) -> Bool)?

    convenience init() { self.init(frame: .zero) }

    override init(frame frameRect: NSRect) {
        backingTextLayoutManager.textContainer = backingTextContainer
        backingContentStorage.addTextLayoutManager(backingTextLayoutManager)
        backingContentStorage.primaryTextLayoutManager = backingTextLayoutManager
        super.init(frame: frameRect, textContainer: backingTextContainer)
    }

    override func insertNewline(_ sender: Any?) {
        if onCommandFromView?(#selector(NSResponder.insertNewline(_:))) == true { return }
        super.insertNewline(sender)
    }

    override func deleteBackward(_ sender: Any?) {
        if onCommandFromView?(#selector(NSResponder.deleteBackward(_:))) == true { return }
        super.deleteBackward(sender)
    }

    override func cancelOperation(_ sender: Any?) {
        if onCommandFromView?(#selector(NSResponder.cancelOperation(_:))) == true { return }
        super.cancelOperation(sender)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    fileprivate func configure(with themer: EditorThemer, revision: Int) {
        Self.installDefocusMonitorIfNeeded()
        let needsRestyle = styler !== themer || styleRevision != revision
        styler = themer
        styleRevision = revision

        if !didConfigureView {
            didConfigureView = true
            backingTextContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            backingTextContainer.widthTracksTextView = true
            backingTextContainer.heightTracksTextView = false
            backingTextContainer.lineFragmentPadding = 0
            isEditable = true
            isSelectable = true
            isRichText = true
            allowsUndo = true
            minSize = NSSize(width: 0, height: minimumLineHeight)
            maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            isHorizontallyResizable = false
            isVerticallyResizable = false
            autoresizingMask = [.width]
            wantsLayer = false
            drawsBackground = false
            textContainerInset = NSSize(width: 0, height: 5)
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
        if !renderedText.isEmpty { restylePreservingSelection() }
    }

    fileprivate func setPlainSelectedRange(_ range: NSRange) { setSelectedRange(clamp(range, in: plainText)) }

    fileprivate func render(text: String, selectedRange: NSRange) {
        guard let styler else { return }
        let attributed = styler.attributedString(for: text)
        isApplyingTextStorageChange = true
        defer { isApplyingTextStorageChange = false }
        applyStyledText(attributed)
        renderedText = text
        setPlainSelectedRange(selectedRange)
        resetTypingAttributes()
        invalidateEditorLayout()
    }

    func measuredSize(for proposedWidth: CGFloat?) -> CGSize {
        let targetWidth = max(proposedWidth ?? bounds.width, 1)
        if backingTextContainer.containerSize.width != targetWidth {
            backingTextContainer.containerSize = NSSize(width: targetWidth, height: .greatestFiniteMagnitude)
        }

        backingTextLayoutManager.ensureLayout(
            for: CGRect(origin: .zero, size: CGSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude))
        )

        let rect = backingTextLayoutManager.usageBoundsForTextContainer
        let font = self.font ?? .systemFont(ofSize: NSFont.systemFontSize)
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let measured = ceil(rect.height) + textContainerInset.height * 2
        let minimum = lineHeight + textContainerInset.height * 2

        return CGSize(width: targetWidth, height: max(measured, minimum))
    }

    override var intrinsicContentSize: NSSize {
        let measured = measuredSize(for: bounds.width)
        return NSSize(width: NSView.noIntrinsicMetric, height: measured.height)
    }

    override var fittingSize: NSSize {
        let measured = measuredSize(for: bounds.width)
        return NSSize(width: measured.width, height: measured.height)
    }

    override func didChangeText() {
        super.didChangeText()
        guard !isApplyingTextStorageChange else { return }
        renderedText = plainText
        restylePreservingSelection()
        resetTypingAttributes()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if backingTextContainer.containerSize.width != newSize.width {
            backingTextContainer.containerSize = NSSize(width: newSize.width, height: .greatestFiniteMagnitude)
        }
        invalidateEditorLayout()
    }

    override var acceptsFirstResponder: Bool { true }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard let styler else {
            super.drawInsertionPoint(in: rect, color: color, turnedOn: flag)
            return
        }

        let caretRect = styledInsertionRect(rect).integral
        if flag {
            if !lastDrawnInsertionRect.isEmpty, lastDrawnInsertionRect != caretRect {
                setNeedsDisplay(lastDrawnInsertionRect)
            }
            styler.theme.caretColor.setFill()
            NSBezierPath(
                roundedRect: caretRect,
                xRadius: min(caretRect.width / 2, 1),
                yRadius: min(caretRect.width / 2, 1)
            ).fill()
            lastDrawnInsertionRect = caretRect
        } else {
            if !lastDrawnInsertionRect.isEmpty { setNeedsDisplay(lastDrawnInsertionRect) }
            setNeedsDisplay(caretRect)
            lastDrawnInsertionRect = caretRect
        }
    }

    private func resetTypingAttributes() {
        guard let styler else { return }
        insertionPointColor = styler.theme.caretColor
        typingAttributes = styler.typingAttributes
    }

    private func styledInsertionRect(_ rect: NSRect) -> NSRect {
        guard let styler else { return rect }
        let width = max(styler.theme.caretWidth, 1)
        let height = max(styler.theme.caretHeight, 1)
        return NSRect(
            x: rect.minX,
            y: rect.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func restylePreservingSelection() {
        guard let styler else { return }

        let selection = selectedRange()
        let text = plainText
        let attributed = styler.attributedString(for: text)
        let wasUndoRegistrationEnabled = undoManager?.isUndoRegistrationEnabled ?? false

        isApplyingTextStorageChange = true
        if wasUndoRegistrationEnabled { undoManager?.disableUndoRegistration() }

        applyStyledText(attributed)

        if wasUndoRegistrationEnabled { undoManager?.enableUndoRegistration() }
        setPlainSelectedRange(selection)
        isApplyingTextStorageChange = false

        renderedText = text
        invalidateEditorLayout()
    }

    private func applyStyledText(_ attributed: NSAttributedString) {
        if let textStorage { textStorage.setAttributedString(attributed) }

        if let backingTextStorage = backingContentStorage.textStorage {
            if backingTextStorage !== textStorage { backingTextStorage.setAttributedString(attributed) }
        }
        else { backingContentStorage.attributedString = attributed }

        backingContentStorage.synchronizeTextLayoutManagers(nil)
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

    private static func installDefocusMonitorIfNeeded() {
        guard defocusMonitor == nil else { return }
        defocusMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { event in
            guard let window = event.window,
                  let current = window.firstResponder as? EditorInputView,
                  let contentView = window.contentView
            else { return event }

            let point = contentView.convert(event.locationInWindow, from: nil)
            let hit = contentView.hitTest(point)
            if let hit, hit === current || hit.isDescendant(of: current) { return event }

            window.makeFirstResponder(nil)
            return event
        }
    }
}
