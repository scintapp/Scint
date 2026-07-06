import AppKit
import SwiftUI


struct EditorInput: NSViewRepresentable {
    @Environment(EditorState.self) private var editor
    @Environment(\.editorFocus) private var focus
    let id: UUID
    let text: String
    let selection: NSRange?
    let isEditing: Bool
    let onTextChange: (String, NSRange) -> Void
    let onSelectionChange: (NSRange) -> Void
    let onFocusGained: () -> Void
    let onCommand: (Selector, Bool, Bool) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            onFocusGained: onFocusGained,
            onCommand: onCommand
        )
    }

    func makeNSView(context: Context) -> EditorInputView {
        let view = EditorInputView()
        view.delegate = context.coordinator
        view.configure(with: editor.themer, revision: editor.themeRevision)
        view.render(text: text, selectedRange: clamp(selection ?? .init(location: 0, length: 0), in: text))
        context.coordinator.view = view

        view.onCommandFromView = { [weak coordinator = context.coordinator, weak view] selector in
            guard let coordinator, let view else { return false }
            return coordinator.onCommand(selector, view.caretIsOnFirstLine, view.caretIsOnLastLine)
        }

        focus.register(view, for: id)
        return view
    }

    func updateNSView(_ view: EditorInputView, context: Context) {
        view.configure(with: editor.themer, revision: editor.themeRevision)
        let targetSelection = clamp(selection ?? view.plainSelectedRange, in: text)
        if view.renderedText != text { view.render(text: text, selectedRange: targetSelection) }
        else if view.plainSelectedRange != targetSelection { view.setPlainSelectedRange(targetSelection) }

        context.coordinator.onTextChange = onTextChange
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onFocusGained = onFocusGained
        context.coordinator.onCommand = onCommand
        context.coordinator.lastSelection = view.plainSelectedRange
        focus.register(view, for: id)
    }

    static func dismantleNSView(_ view: EditorInputView, coordinator: Coordinator) {}

    private func clamp(_ range: NSRange, in string: String) -> NSRange {
        let length = (string as NSString).length
        let location = min(max(range.location, 0), length)
        let maxLength = length - location
        return NSRange(location: location, length: min(range.length, maxLength))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onTextChange: (String, NSRange) -> Void
        var onSelectionChange: (NSRange) -> Void
        var onFocusGained: () -> Void
        var onCommand: (Selector, Bool, Bool) -> Bool
        weak var view: EditorInputView?
        var lastSelection: NSRange?

        init(onTextChange: @escaping (String, NSRange) -> Void, onSelectionChange: @escaping (NSRange) -> Void,
             onFocusGained: @escaping () -> Void, onCommand: @escaping (Selector, Bool, Bool) -> Bool) {
            self.onTextChange = onTextChange
            self.onSelectionChange = onSelectionChange
            self.onFocusGained = onFocusGained
            self.onCommand = onCommand
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard let view = view else { return onCommand(selector, true, true) }
            return onCommand(selector, view.caretIsOnFirstLine, view.caretIsOnLastLine)
        }

        func textDidBeginEditing(_ notification: Notification) { onFocusGained() }

        func textDidChange(_ notification: Notification) {
            guard let view else { return }
            guard !view.isApplyingTextStorageChange else { return }
            lastSelection = view.plainSelectedRange
            onTextChange(view.plainText, view.plainSelectedRange)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let view else { return }
            guard !view.isApplyingTextStorageChange else { return }
            let selection = view.plainSelectedRange
            guard selection != lastSelection else { return }
            lastSelection = selection
            onSelectionChange(selection)
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

    private var currentAttributedString: NSAttributedString {
        if let textStorage { return NSAttributedString(attributedString: textStorage) }
        if let textStorage = backingContentStorage.textStorage { return NSAttributedString(attributedString: textStorage) }
        return backingContentStorage.attributedString ?? NSAttributedString(string: string)
    }

    var plainText: String { currentAttributedString.string }
    var plainSelectedRange: NSRange { selectedRange() }
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

    var caretIsOnFirstLine: Bool {
        let ns = plainText as NSString
        let caret = min(selectedRange().location, ns.length)
        return ns.substring(to: caret).range(of: "\n", options: .backwards) == nil
    }

    var caretIsOnLastLine: Bool {
        let ns = plainText as NSString
        let caret = min(selectedRange().location, ns.length)
        return ns.substring(from: caret).range(of: "\n") == nil
    }

    private func caretLineFragmentRect(at location: Int) -> CGRect? {
        var result: CGRect?
        let target = min(max(location, 0), (plainText as NSString).length)
        backingTextLayoutManager.enumerateTextLayoutFragments(
            from: backingTextLayoutManager.documentRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            let range = fragment.rangeInElement
            let start = backingTextLayoutManager.offset(
                from: backingTextLayoutManager.documentRange.location,
                to: range.location
            )
            let end = backingTextLayoutManager.offset(
                from: backingTextLayoutManager.documentRange.location,
                to: range.endLocation
            )
            if target >= start && target <= end {
                result = fragment.layoutFragmentFrame
                return false
            }
            return true
        }
        return result
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

    override func scrollRangeToVisible(_ range: NSRange) {}

    override var acceptsFirstResponder: Bool { true }

    private func resetTypingAttributes() {
        guard let styler else { return }
        insertionPointColor = styler.theme.textColor
        typingAttributes = styler.typingAttributes
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
