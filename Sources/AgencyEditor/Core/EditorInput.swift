import AppKit
import SwiftUI


final class EditorInputView: NSTextView {
    private let minimumLineHeight: CGFloat = 24
    private let backingContentStorage = NSTextContentStorage()
    private let backingTextLayoutManager = NSTextLayoutManager()
    private let backingTextContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    private weak var styler: EditorStyler?

    private struct InlineComponent {
        let id: UUID
        let range: NSRange
        let view: EditorAttachmentView
    }
    private var inlineComponents: [InlineComponent] = []

    private(set) var renderedText = ""
    private(set) var renderedVersion = 0

    var registerComponents: (([Entry]) -> Void)?
    var activateEntry: ((Entry) -> Void)?
    var makeInlineComponentView: ((Entry, @escaping () -> Void) -> AnyView)?

    convenience init() { self.init(frame: .zero) }

    override init(frame frameRect: NSRect) {
        backingTextLayoutManager.textContainer = backingTextContainer
        backingContentStorage.addTextLayoutManager(backingTextLayoutManager)
        backingContentStorage.primaryTextLayoutManager = backingTextLayoutManager
        super.init(frame: frameRect, textContainer: backingTextContainer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var plainText: String {
        let attributed = currentAttributedString
        let fullRange = NSRange(location: 0, length: attributed.length)
        var result = ""

        attributed.enumerateAttributes(in: fullRange) { attributes, range, _ in
            if let attachment = attributes[.attachment] as? EditorAttachment {
                result.append(attachment.token)
            } else {
                result.append(attributed.attributedSubstring(from: range).string)
            }
        }

        return result
    }

    var plainSelectedRange: NSRange {
        let selected = selectedRange()
        let location = plainIndex(forDisplayIndex: selected.location)
        let end = plainIndex(forDisplayIndex: selected.location + selected.length)
        return NSRange(location: location, length: max(0, end - location))
    }

    fileprivate func configure(with styler: EditorStyler) {
        self.styler = styler
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
        textContainerInset = NSSize(width: 0, height: 4)
        font = styler.style.baseFont
        textColor = styler.style.textColor
        insertionPointColor = styler.style.textColor
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isGrammarCheckingEnabled = false
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        typingAttributes = styler.typingAttributes
    }

    fileprivate func setPlainSelectedRange(_ range: NSRange) {
        setSelectedRange(displayRange(forPlainRange: range))
    }

    fileprivate func render(
        text: String,
        selectedRange: NSRange,
        renderVersion: Int,
        resolveComponent: (UUID) -> Entry?
    ) {
        guard let styler else { return }
        let attributed = styler.attributedString(for: text, resolveInlineEntry: resolveComponent)
        if let textStorage = backingContentStorage.textStorage {
            textStorage.setAttributedString(attributed)
        } else {
            backingContentStorage.attributedString = attributed
        }
        backingContentStorage.synchronizeTextLayoutManagers(nil)
        renderedText = text
        renderedVersion = renderVersion
        setPlainSelectedRange(selectedRange)
        resetTypingAttributes()
        rebuildInlineComponents()
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        guard let container = textContainer else {
            return NSSize(width: NSView.noIntrinsicMetric, height: minimumLineHeight)
        }

        let targetWidth = max(bounds.width, 1)
        if container.containerSize.width != targetWidth {
            container.containerSize = NSSize(width: targetWidth, height: .greatestFiniteMagnitude)
        }

        backingTextLayoutManager.ensureLayout(
            for: CGRect(origin: .zero, size: CGSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude))
        )

        let rect = backingTextLayoutManager.usageBoundsForTextContainer
        let font = self.font ?? .systemFont(ofSize: NSFont.systemFontSize)
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let measured = ceil(rect.height) + textContainerInset.height * 2
        let minimum = lineHeight + textContainerInset.height * 2

        return NSSize(width: NSView.noIntrinsicMetric, height: max(measured, minimum))
    }

    override func didChangeText() {
        super.didChangeText()
        renderedText = ""
        renderedVersion = -1
        resetTypingAttributes()
        rebuildInlineComponents()
        invalidateIntrinsicContentSize()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if let container = textContainer, container.containerSize.width != newSize.width {
            container.containerSize = NSSize(width: newSize.width, height: .greatestFiniteMagnitude)
        }
        layoutInlineComponents()
        invalidateIntrinsicContentSize()
    }

    override func layout() {
        super.layout()
        layoutInlineComponents()
    }

    override func scrollRangeToVisible(_ range: NSRange) {}

    private func resetTypingAttributes() {
        guard let styler else { return }
        font = styler.style.baseFont
        textColor = styler.style.textColor
        insertionPointColor = styler.style.textColor
        typingAttributes = styler.typingAttributes
    }

    override func copy(_ sender: Any?) {
        let displaySelection = selectedRange()
        guard displaySelection.length > 0 else {
            super.copy(sender)
            return
        }

        let selection = plainSelectedRange
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(plainSubstring(for: selection), forType: .string)

        let entries = inlineEntries(in: displaySelection)
        if !entries.isEmpty,
           let data = try? JSONEncoder().encode(entries) {
            pasteboard.setData(data, forType: EditorInput.inlineEntriesPasteboardType)
        }
    }

    override func cut(_ sender: Any?) {
        let selection = plainSelectedRange
        guard selection.length > 0 else {
            super.cut(sender)
            return
        }

        copy(sender)
        replaceCharacters(in: selectedRange(), with: "")
        didChangeText()
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        if let data = pasteboard.data(forType: EditorInput.inlineEntriesPasteboardType),
           let entries = try? JSONDecoder().decode([Entry].self, from: data),
           !entries.isEmpty {
            registerComponents?(entries)
        }

        guard let string = pasteboard.string(forType: .string) else {
            super.paste(sender)
            return
        }

        replaceCharacters(in: selectedRange(), with: string)
        didChangeText()
    }

    override var acceptsFirstResponder: Bool { true }

    func caretRectForCurrentSelection() -> CGRect {
        let selection = selectedRange()
        guard let window else { return .zero }

        let rectOnScreen = firstRect(forCharacterRange: selection, actualRange: nil)
        if !rectOnScreen.isNull, !rectOnScreen.isEmpty {
            let rectInWindow = window.convertFromScreen(rectOnScreen)
            return convert(rectInWindow, from: nil)
        }

        let fallbackIndex = max(0, min(selection.location, (string as NSString).length))
        if let textRange = characterRange(for: NSRange(location: fallbackIndex, length: 0)),
           let textSegmentFrame = textSegmentFrame(for: textRange) {
            return textSegmentFrame
        }

        return CGRect(x: 0, y: 0, width: 1, height: minimumLineHeight)
    }

    private func displayRange(forPlainRange range: NSRange) -> NSRange {
        let location = displayIndex(forPlainIndex: range.location)
        let end = displayIndex(forPlainIndex: range.location + range.length)
        return NSRange(location: location, length: max(0, end - location))
    }

    private func plainIndex(forDisplayIndex target: Int) -> Int {
        var plain = 0
        let attributed = currentAttributedString
        let fullRange = NSRange(location: 0, length: attributed.length)

        attributed.enumerateAttributes(in: fullRange) { attributes, range, stop in
            if target <= range.location {
                stop.pointee = true
                return
            }

            let segmentEnd = range.location + range.length
            let plainLength = plainLength(for: attributes, range: range)

            if target >= segmentEnd {
                plain += plainLength
                return
            }

            if attributes[.attachment] is EditorAttachment {
                plain += target > range.location ? plainLength : 0
            } else {
                plain += target - range.location
            }
            stop.pointee = true
        }

        return plain
    }

    private func displayIndex(forPlainIndex target: Int) -> Int {
        var plain = 0
        var display = 0
        let attributed = currentAttributedString
        let fullRange = NSRange(location: 0, length: attributed.length)

        attributed.enumerateAttributes(in: fullRange) { attributes, range, stop in
            if target <= plain {
                stop.pointee = true
                return
            }

            let plainLength = plainLength(for: attributes, range: range)
            let plainEnd = plain + plainLength

            if target >= plainEnd {
                plain = plainEnd
                display = range.location + range.length
                return
            }

            if attributes[.attachment] is EditorAttachment {
                display = range.location + (target > plain ? range.length : 0)
            } else {
                display = range.location + (target - plain)
            }
            stop.pointee = true
        }

        return display
    }

    private func plainLength(for attributes: [NSAttributedString.Key: Any], range: NSRange) -> Int {
        if let attachment = attributes[.attachment] as? EditorAttachment {
            return attachment.tokenLength
        }
        return range.length
    }

    private func plainSubstring(for range: NSRange) -> String {
        let plain = plainText as NSString
        let length = plain.length
        let location = min(max(range.location, 0), length)
        let clamped = NSRange(location: location, length: min(range.length, length - location))
        return plain.substring(with: clamped)
    }

    private func inlineEntries(in range: NSRange) -> [Entry] {
        var entries: [Entry] = []
        let attributed = currentAttributedString
        attributed.enumerateAttribute(.attachment, in: range) { value, _, _ in
            guard let attachment = value as? EditorAttachment else { return }
            entries.append(attachment.entry)
        }
        return entries
    }

    private var currentAttributedString: NSAttributedString {
        if let textStorage = backingContentStorage.textStorage {
            return NSAttributedString(attributedString: textStorage)
        }
        return backingContentStorage.attributedString ?? NSAttributedString(string: string)
    }

    private func characterRange(for range: NSRange) -> NSTextRange? {
        let documentRange = backingContentStorage.documentRange
        guard let start = backingContentStorage.location(documentRange.location, offsetBy: range.location) else {
            return nil
        }
        guard let end = backingContentStorage.location(start, offsetBy: range.length) else {
            return nil
        }
        return NSTextRange(location: start, end: end)
    }

    private func textSegmentMetrics(for range: NSTextRange) -> (frame: CGRect, baseline: CGFloat)? {
        var metrics: (frame: CGRect, baseline: CGFloat)?
        backingTextLayoutManager.enumerateTextSegments(
            in: range,
            type: .standard,
            options: .rangeNotRequired
        ) { _, textSegmentFrame, baselinePosition, _ in
            metrics = (textSegmentFrame, baselinePosition)
            return false
        }
        return metrics
    }

    private func textSegmentFrame(for range: NSTextRange) -> CGRect? {
        textSegmentMetrics(for: range)?.frame
    }

    private func rebuildInlineComponents() {
        let existing = Dictionary(uniqueKeysWithValues: inlineComponents.map { ($0.id, $0.view) })
        var next: [InlineComponent] = []
        var kept = Set<UUID>()

        let attributed = currentAttributedString
        let fullRange = NSRange(location: 0, length: attributed.length)

        attributed.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            guard let attachment = value as? EditorAttachment else { return }
            let entry = attachment.entry
            let id = entry.id
            let size = attachment.displaySize
            let rootView = makeInlineComponentView?(entry, { [weak self] in
                self?.handleActivation(for: entry)
            }) ?? AnyView(EmptyView())

            let view: EditorAttachmentView
            if let reused = existing[id] {
                reused.update(entry: entry, size: size, rootView: rootView)
                view = reused
            } else {
                view = EditorAttachmentView(entry: entry, size: size, rootView: rootView)
                addSubview(view)
            }
            kept.insert(id)
            next.append(InlineComponent(id: id, range: range, view: view))
        }

        for (id, view) in existing where !kept.contains(id) {
            view.removeFromSuperview()
        }

        inlineComponents = next
        layoutInlineComponents()
    }

    private func layoutInlineComponents() {
        let containerOrigin = textContainerOrigin
        let font = self.font ?? .systemFont(ofSize: NSFont.systemFontSize)

        for component in inlineComponents {
            guard let textRange = characterRange(for: component.range),
                  let metrics = textSegmentMetrics(for: textRange) else {
                component.view.isHidden = true
                continue
            }

            let size = component.view.size
            let yOffset = EditorAttachment.baselineOffset(size: size, font: font)
            component.view.frame = CGRect(
                x: containerOrigin.x + metrics.frame.minX,
                y: containerOrigin.y + metrics.frame.minY + metrics.baseline - size.height - yOffset,
                width: size.width,
                height: size.height
            )
            component.view.isHidden = false
        }
    }

    private func handleActivation(for entry: Entry) {
        window?.makeFirstResponder(self)
        activateEntry?(entry)
    }
}

struct EditorInput: NSViewRepresentable {
    typealias NSViewType = EditorInputView
    static let inlineEntriesPasteboardType = NSPasteboard.PasteboardType("com.agencyagency.inline-entries")

    let text: String
    let renderVersion: Int
    let selection: NSRange?
    let isFocused: Bool
    let hasFocusedTextEntry: Bool
    let styler: EditorStyler
    let makeInlineComponentView: (Entry, @escaping () -> Void) -> AnyView
    let resolveComponent: (UUID) -> Entry?
    let registerComponents: ([Entry]) -> Void
    let onTextChange: (String, NSRange, CGRect) -> Void
    let onSelectionChange: (NSRange, CGRect) -> Void
    let onFocusGained: () -> Void
    let onActivateEntry: (Entry) -> Void
    let onCommand: (Selector) -> Bool

    func makeCoordinator() -> Self.Coordinator {
        Coordinator(
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            onFocusGained: onFocusGained,
            onCommand: onCommand
        )
    }

    func makeNSView(context: Self.Context) -> EditorInputView {
        let view = EditorInputView()
        view.delegate = context.coordinator
        view.configure(with: styler)

        view.registerComponents = registerComponents
        view.activateEntry = onActivateEntry
        view.makeInlineComponentView = makeInlineComponentView
        view.render(
            text: text,
            selectedRange: clamp(selection ?? .init(location: 0, length: 0), in: text),
            renderVersion: renderVersion,
            resolveComponent: resolveComponent
        )

        if let selection {
            view.setPlainSelectedRange(clamp(selection, in: text))
        }

        context.coordinator.view = view
        return view
    }

    func updateNSView(_ view: EditorInputView, context: Self.Context) {
        view.registerComponents = registerComponents
        view.activateEntry = onActivateEntry
        view.makeInlineComponentView = makeInlineComponentView
        let targetSelection = clamp(selection ?? view.plainSelectedRange, in: text)

        if view.renderedText != text || view.renderedVersion != renderVersion {
            view.render(
                text: text,
                selectedRange: targetSelection,
                renderVersion: renderVersion,
                resolveComponent: resolveComponent
            )
        } else if view.plainSelectedRange != targetSelection {
            view.setPlainSelectedRange(targetSelection)
        }

        context.coordinator.onTextChange = onTextChange
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onFocusGained = onFocusGained
        context.coordinator.onCommand = onCommand
        syncFocus(view: view)
    }

    private func syncFocus(view: EditorInputView) {
        guard let window = view.window else { return }
        let isCurrentlyFocused = window.firstResponder === view

        if isFocused && !isCurrentlyFocused {
            DispatchQueue.main.async { window.makeFirstResponder(view) }
        } else if hasFocusedTextEntry && !isFocused && isCurrentlyFocused {
            DispatchQueue.main.async { window.makeFirstResponder(nil) }
        }
    }

    private func clamp(_ range: NSRange, in string: String) -> NSRange {
        let length = (string as NSString).length
        let location = min(max(range.location, 0), length)
        let maxLength = length - location
        return NSRange(location: location, length: min(range.length, maxLength))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onTextChange: (String, NSRange, CGRect) -> Void
        var onSelectionChange: (NSRange, CGRect) -> Void
        var onFocusGained: () -> Void
        var onCommand: (Selector) -> Bool
        weak var view: EditorInputView?

        init(
            onTextChange: @escaping (String, NSRange, CGRect) -> Void,
            onSelectionChange: @escaping (NSRange, CGRect) -> Void,
            onFocusGained: @escaping () -> Void,
            onCommand: @escaping (Selector) -> Bool
        ) {
            self.onTextChange = onTextChange
            self.onSelectionChange = onSelectionChange
            self.onFocusGained = onFocusGained
            self.onCommand = onCommand
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool { onCommand(selector) }
        func textDidBeginEditing(_ notification: Notification) { onFocusGained() }

        func textDidChange(_ notification: Notification) {
            guard let view else { return }
            onTextChange(view.plainText, view.plainSelectedRange, view.caretRectForCurrentSelection())
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let view else { return }
            onSelectionChange(view.plainSelectedRange, view.caretRectForCurrentSelection())
        }
    }
}
