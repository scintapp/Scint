import AppKit
import SwiftUI
import ScintRuntime


typealias Document = ScintRuntime.Document

final class CardAttachment: NSTextAttachment {
    let block: Document.Block
    @MainActor weak var view: CardView?
    @MainActor var isSelected = false { didSet { if isSelected != oldValue { view?.rootView = DocumentBlock(block: block, isSelected: isSelected) } } }

    var reference: Reference? {
        switch block {
        case .artifact(let ref), .command(let ref), .document(let ref): ref
            case .task, .text, .series: nil
        }
    }

    init(_ block: Document.Block) {
        self.block = block
        super.init(data: nil, ofType: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewProvider(for parentView: NSView?, location: any NSTextLocation, textContainer: NSTextContainer?) -> NSTextAttachmentViewProvider? {
        let provider = CardProvider(textAttachment: self, parentView: parentView, textLayoutManager: textContainer?.textLayoutManager, location: location)
        provider.tracksTextAttachmentViewBounds = true
        return provider
    }
}

final class CardProvider: NSTextAttachmentViewProvider {
    override func loadView() {
        nonisolated(unsafe) let provider = self
        MainActor.assumeIsolated {
            guard let card = provider.textAttachment as? CardAttachment else { return }
            let view = CardView(card)
            card.view = view; provider.view = view
        }
    }

    override func attachmentBounds(for attributes: [NSAttributedString.Key: Any], location: any NSTextLocation, textContainer: NSTextContainer?,
                                   proposedLineFragment: CGRect, position: CGPoint) -> CGRect {
        nonisolated(unsafe) let provider = self
        return MainActor.assumeIsolated {
            if provider.view == nil { provider.loadView() }
            guard let view = provider.view as? CardView, proposedLineFragment.width.isFinite, proposedLineFragment.width > 1 else { return .zero }
            view.frame.size.width = proposedLineFragment.width
            return CGRect(x: 0, y: 0, width: proposedLineFragment.width, height: view.height(at: proposedLineFragment.width))
        }
    }
}

class EmbeddedView<Content: View>: NSHostingView<Content> {
    private let sizer: NSHostingController<Content>

    required init(rootView: Content) {
        sizer = NSHostingController(rootView: rootView)
        super.init(rootView: rootView)
    }

    required init?(coder: NSCoder) { nil }

    func height(at width: CGFloat) -> CGFloat {
        guard width.isFinite, width > 1 else { return 1 }
        return max(1, sizer.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }
}

final class CardView: EmbeddedView<DocumentBlock> {
    weak var card: CardAttachment?

    convenience init(_ card: CardAttachment) {
        self.init(rootView: DocumentBlock(block: card.block, isSelected: card.isSelected))
        self.card = card
    }

    override func mouseDown(with event: NSEvent) {
        guard let card, let editor = enclosingScrollView?.documentView as? ScintEditor else { return }
        editor.click(card, with: event)
    }
}

extension ScintEditor {
    /// Blocks joined by newlines. The newline on either side of a card separates it; it is not text.
    static func render(_ blocks: [ScintRuntime.Document.Block]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, block) in blocks.enumerated() {
            if index > 0 { result.append(NSAttributedString(string: "\n")) }
            if case .text(_, let text) = block { result.append(NSAttributedString(string: text)) }
            else { result.append(NSAttributedString(attachment: CardAttachment(block))) }
        }
        return result
    }

    /// The inverse of `render`. Text blocks keep the ids of the previous text blocks, in order.
    static func blocks(in text: NSAttributedString, reusing previous: [ScintRuntime.Document.Block]) -> [ScintRuntime.Document.Block] {
        let source = text.string as NSString
        var ids = previous.compactMap { block -> UUID? in if case .text(let id, _) = block { id } else { nil } }
        var blocks: [ScintRuntime.Document.Block] = [], start = 0
        func appendText(upTo end: Int) {
            var range = NSRange(location: start, length: end - start)
            if start > 0, range.length > 0, source.character(at: range.location) == 10 { range.location += 1; range.length -= 1 }
            if end < source.length, range.length > 0, source.character(at: NSMaxRange(range) - 1) == 10 { range.length -= 1 }
            let value = source.substring(with: range).replacingOccurrences(of: "\u{FFFC}", with: "")
            guard !value.isEmpty else { return }
            blocks.append(.text(ids.isEmpty ? UUID() : ids.removeFirst(), value))
        }
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let card = value as? CardAttachment else { return }
            appendText(upTo: range.location)
            if !blocks.contains(where: { $0.id == card.block.id }) { blocks.append(card.block) }
            start = NSMaxRange(range)
        }
        appendText(upTo: source.length)
        return blocks
    }
}
