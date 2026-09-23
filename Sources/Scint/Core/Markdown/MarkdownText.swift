import AppKit
import SwiftUI
import ScintRuntime
import ScintComponents


struct MarkdownText: NSViewRepresentable {
    let content: String
    var font: NSFont = Typography.Prose.text
    var reasoning = false
    var completed = false
    var alignment: NSTextAlignment = .left
    var hugs = false
    @Environment(\.lineLimit) private var lineLimit

    func makeNSView(context: Self.Context) -> MarkdownTextView {
        MarkdownTextView()
    }

    func updateNSView(_ view: MarkdownTextView, context: Self.Context) {
        view.setLineLimit(lineLimit)
        view.render(content, font: font, reasoning: reasoning, alignment: alignment, completed: completed)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: MarkdownTextView, context: Self.Context) -> CGSize? {
        nsView.measure(proposal.width ?? Typography.Prose.readableWidth, hugs: hugs)
    }
}

final class MarkdownTextView: NSTextView {
    private let markdownLayout = NSLayoutManager()
    private let markdownContainer = NSTextContainer(size: .zero)
    private let measurementStorage = NSTextStorage()
    private let measurementLayout = NSLayoutManager()
    private let measurementContainer = NSTextContainer(size: .zero)
    private var rendered: NSAttributedString?

    init() {
        let storage = NSTextStorage()
        storage.addLayoutManager(markdownLayout)
        markdownLayout.addTextContainer(markdownContainer)
        super.init(frame: .zero, textContainer: markdownContainer)
        measurementStorage.addLayoutManager(measurementLayout)
        measurementLayout.addTextContainer(measurementContainer)
        measurementContainer.lineFragmentPadding = .zero
        drawsBackground = false
        isEditable = false
        isSelectable = true
        isRichText = true
        isVerticallyResizable = false
        isHorizontallyResizable = false
        textContainerInset = NSSize(width: 0, height: Typography.Prose.textInset)
        markdownContainer.lineFragmentPadding = .zero
        markdownContainer.widthTracksTextView = true
        linkTextAttributes = [
            .foregroundColor: NSColor(Style.Tint.accent.bright),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func render(_ text: String, font: NSFont, reasoning: Bool, alignment: NSTextAlignment, completed: Bool = false) {
        let result = Attribute.markdown(text, font: font, reasoning: reasoning, alignment: alignment)
        if completed {
            result.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: result.length))
        }
        guard rendered?.isEqual(to: result) != true else { return }
        rendered = result
        textStorage?.setAttributedString(result)
        measurementStorage.setAttributedString(result)
        invalidateIntrinsicContentSize()
    }

    func setLineLimit(_ limit: Int?) {
        for container in [markdownContainer, measurementContainer] {
            container.maximumNumberOfLines = limit ?? 0
            container.lineBreakMode = limit == nil ? .byWordWrapping : .byTruncatingTail
        }
    }

    func measure(_ width: CGFloat, hugs: Bool = false) -> CGSize {
        measurementContainer.containerSize = CGSize(width: max(1, width), height: .greatestFiniteMagnitude)
        measurementLayout.ensureLayout(for: measurementContainer)
        let used = measurementLayout.usedRect(for: measurementContainer)
        return CGSize(width: hugs ? min(width, ceil(used.width)) : width, height: ceil(used.height) + textContainerInset.height * 2)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        markdownContainer.containerSize = CGSize(width: max(1, newSize.width), height: .greatestFiniteMagnitude)
    }

    override func draw(_ dirtyRect: NSRect) {
        markdownLayout.ensureLayout(for: markdownContainer)
        if let storage = textStorage {
            let font = Typography.Prose.code
            storage.enumerateAttribute(.markdownCode, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
                guard value != nil else { return }
                let glyphs = markdownLayout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                markdownLayout.enumerateLineFragments(forGlyphRange: glyphs) { fragment, _, _, line, _ in
                    let run = NSIntersectionRange(line, glyphs)
                    let baseline = fragment.minY + self.markdownLayout.location(forGlyphAt: run.location).y
                    self.markdownLayout.enumerateEnclosingRects(forGlyphRange: run, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: self.markdownContainer) { rect, _ in
                        let chip = CGRect(x: rect.minX, y: baseline - font.ascender, width: rect.width, height: font.ascender - font.descender)
                        MarkdownDecoration.code(chip.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y).insetBy(dx: 0, dy: -Typography.Prose.textInset))
                    }
                }
            }
        }
        super.draw(dirtyRect)
    }

    override func clicked(onLink link: Any, at charIndex: Int) {
        let url = (link as? URL) ?? (link as? String).flatMap(URL.init(string:))
        guard let url else { return }
        if let ref = Reference.Link.reference(in: url.absoluteString) { CallbackRouter.open(ref) }
        else { NSWorkspace.shared.open(url) }
    }
}

enum MarkdownDecoration {
    static func code(_ rect: CGRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: Typography.Prose.codeRadius, yRadius: Typography.Prose.codeRadius)
        NSColor(Style.Background.surface).setFill()
        path.fill()
        NSColor(Style.Border.panel).setStroke()
        path.lineWidth = 0.75
        path.stroke()
    }
}

extension NSAttributedString.Key {
    static let markdownCode = Self("ScintMarkdownCode")
}

enum Attribute {
    static func markdown(_ text: String, font: NSFont, reasoning: Bool, alignment: NSTextAlignment) -> NSMutableAttributedString {
        let document = Markdown.scan(text)
        let paragraph = Typography.Prose.paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
        paragraph.alignment = alignment

        let base: [NSAttributedString.Key: Any] = [
            .font: reasoning ? NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) : font,
            .foregroundColor: NSColor(reasoning ? Style.Foreground.secondary : Style.Foreground.primary),
            .paragraphStyle: paragraph
        ]

        let output = NSMutableAttributedString(string: text, attributes: base)
        var hidden = IndexSet()

        for span in document.spans {
            switch span.kind {
                case .strong:
                    output.addAttribute(.font, value: NSFont.systemFont(ofSize: font.pointSize, weight: .semibold), range: span.range)
                case .emphasis:
                    output.enumerateAttribute(.font, in: span.range) { value, range, _ in
                        output.addAttribute(.font, value: NSFontManager.shared.convert(value as? NSFont ?? font, toHaveTrait: .italicFontMask), range: range)
                    }
                case .inlineCode:
                    output.addAttributes([.font: Typography.Prose.code, .markdownCode: true], range: span.range)
                case .strikethrough, .completed:
                    output.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: span.range)
                case .syntax, .linkURL:
                    hidden.insert(integersIn: span.range.location..<NSMaxRange(span.range))
                default: break
            }
        }

        let source = text as NSString

        for link in document.links {
            let destination = source.substring(with: link.url)
            guard let url = URL(string: destination) else { continue }
            output.addAttribute(.link, value: url, range: link.label)
        }

        for span in document.spans where span.kind == .inlineCode {
            output.addAttribute(.font, value: Typography.Prose.code, range: span.range)
            let before = span.range.location - 1
            let after = NSMaxRange(span.range)
            guard before >= 0, after < output.length else { continue }
            for index in [before, after] {
                hidden.remove(index)
                output.replaceCharacters(in: NSRange(location: index, length: 1), with: "\u{00a0}")
                output.setAttributes(base.merging([
                    .markdownCode: true
                ], uniquingKeysWith: { _, new in new }), range: NSRange(location: index, length: 1))
            }
        }
        for range in hidden.rangeView.reversed() {
            output.deleteCharacters(in: NSRange(location: range.lowerBound, length: range.count))
        }
        return output
    }
}
