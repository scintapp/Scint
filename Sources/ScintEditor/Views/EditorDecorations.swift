import AppKit
import SwiftUI
import ScintRuntime
import ScintComponents


extension ScintEditor {
    func textRange(_ range: NSRange) -> NSTextRange? {
        guard let start = content.location(content.documentRange.location, offsetBy: range.location),
              let end = content.location(start, offsetBy: range.length) else { return nil }
        return NSTextRange(location: start, end: end)
    }

    func frames(for range: NSRange, type: NSTextLayoutManager.SegmentType = .standard) -> [CGRect] {
        guard let range = textRange(range) else { return [] }
        var frames: [CGRect] = []
        textLayout.enumerateTextSegments(in: range, type: type, options: [.rangeNotRequired]) { _, frame, _, _ in
            frames.append(frame.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y)); return true
        }
        return frames
    }

    private func characters(in rect: CGRect) -> NSRange {
        let top = textLayout.textLayoutFragment(for: CGPoint(x: 0, y: rect.minY - textContainerOrigin.y))?.rangeInElement.location ?? content.documentRange.location
        let bottom = textLayout.textLayoutFragment(for: CGPoint(x: 0, y: rect.maxY - textContainerOrigin.y))?.rangeInElement.endLocation ?? content.documentRange.endLocation
        return NSRange(location: content.offset(from: content.documentRange.location, to: top), length: max(0, content.offset(from: top, to: bottom)))
    }

    override func draw(_ dirtyRect: NSRect) {
        let visible = characters(in: dirtyRect), source = self.source, selected = selectedLink
        func shows(_ range: NSRange) -> Bool { NSIntersectionRange(range, visible).length > 0 || NSLocationInRange(range.location, visible) }
        func covered(_ range: NSRange) -> Bool { overlays.values.contains { NSIntersectionRange($0.sourceRange, range).length > 0 } }
        for span in document.spans where span.kind == .inlineCode && shows(span.range) && !covered(span.range) {
            for rect in frames(for: span.range) { MarkdownDecoration.code(rect.insetBy(dx: -Style.Spacing.detail, dy: -Style.Spacing.detail)) }
        }
        for rect in runs(of: .codeBlock, where: shows) {
            MarkdownDecoration.code(CGRect(x: textContainerOrigin.x, y: rect.minY, width: container.size.width, height: rect.height).insetBy(dx: 0, dy: -Style.Spacing.detail))
        }
        styler.theme.bulletColor.setFill()
        for rect in runs(of: .quote, where: shows) {
            CGRect(x: textContainerOrigin.x, y: rect.minY, width: Typography.Prose.quoteBarWidth, height: rect.height).fill()
        }
        for (index, block) in document.blocks.enumerated() where (block.kind == .bullet || block.kind == .numbered) && shows(block.range) {
            guard let line = frames(for: block.range).first else { continue }
            let gutter = CGRect(x: textContainerOrigin.x + styler.listIndent(for: block), y: line.minY, width: styler.gutter(for: block, in: source), height: line.height)
            if block.kind == .bullet {
                let size = Typography.Prose.bulletSize
                NSBezierPath(ovalIn: CGRect(x: gutter.midX - size / 2, y: gutter.midY - size / 2, width: size, height: size)).fill()
            } else {
                ("\(ordinal(at: index))." as NSString).draw(at: gutter.origin, withAttributes: [.font: styler.theme.baseFont, .foregroundColor: styler.theme.bulletColor])
            }
        }
        for link in document.links where shows(link.range) && !covered(link.range) {
            let isSelected = selected?.range == link.range
            guard isSelected || { if case .reference? = target(of: link) { true } else { false } }() else { continue }
            (isSelected ? NSColor.selectedTextBackgroundColor : styler.theme.codeBgColor).setFill()
            for rect in frames(for: link.label) { NSBezierPath(roundedRect: rect.insetBy(dx: -2, dy: -1), xRadius: 4, yRadius: 4).fill() }
        }
        if selected == nil {
            (window?.isKeyWindow == true && window?.firstResponder === self ? NSColor.selectedTextBackgroundColor : .unemphasizedSelectedTextBackgroundColor).setFill()
            for range in highlighted(selectedRange()) where shows(range) {
                for rect in frames(for: range, type: .selection) { rect.fill() }
            }
        }
        if let origin = placeholderOrigin {
            ("Press ‘/’ for commands" as NSString).draw(
                at: origin,
                withAttributes: [
                    .font: styler.theme.baseFont,
                    .foregroundColor: NSColor(Color(red: 0.2902, green: 0.29804, blue: 0.31765))
                ]
            )
        }
        super.draw(dirtyRect)
    }

    private var placeholderOrigin: CGPoint? {
        let selection = selectedRange(), source = self.source
        guard window?.firstResponder === self, selection.length == 0, !hasMarkedText(), !menuController.isOpen else { return nil }
        guard source.substring(with: source.lineRange(for: selection)).trimmingCharacters(in: .newlines).isEmpty else { return nil }
        return frames(for: selection, type: .selection).first?.origin
    }

    private func runs(of kind: Markdown.BlockKind, where shows: (NSRange) -> Bool) -> [CGRect] {
        var rects: [CGRect] = [], previous = -2
        for (index, block) in document.blocks.enumerated() where block.kind == kind && shows(block.range) {
            let line = frames(for: NSRange(location: block.range.location, length: min(block.range.length + 1, source.length - block.range.location)))
            guard let first = line.first else { continue }
            let rect = line.reduce(first) { $0.union($1) }
            if index == previous + 1, let last = rects.popLast() { rects.append(last.union(rect)) } else { rects.append(rect) }
            previous = index
        }
        return rects
    }

    private func highlighted(_ selection: NSRange) -> [NSRange] {
        guard selection.length > 0, let storage = textStorage else { return [] }
        let hidden = overlays.values.map(\.sourceRange).sorted { $0.location < $1.location }
        var ranges: [NSRange] = []
        storage.enumerateAttribute(.attachment, in: selection) { value, range, _ in
            guard !(value is CardAttachment) else { return }
            var cursor = range.location
            for overlay in hidden where NSIntersectionRange(overlay, range).length > 0 {
                if overlay.location > cursor { ranges.append(NSRange(location: cursor, length: overlay.location - cursor)) }
                cursor = max(cursor, NSMaxRange(overlay))
            }
            if NSMaxRange(range) > cursor { ranges.append(NSRange(location: cursor, length: NSMaxRange(range) - cursor)) }
        }
        return ranges
    }

    /// Counts back through numbered items at the same depth, skipping deeper items, until the list changes.
    private func ordinal(at index: Int) -> Int {
        let depth = document.blocks[index].depth
        var ordinal = 1
        for block in document.blocks[..<index].reversed() {
            guard block.kind.isList, block.depth >= depth else { break }
            guard block.depth == depth else { continue }
            guard block.kind == .numbered else { break }
            ordinal += 1
        }
        return ordinal
    }

    /// A reference link alone on its line shows as a card; a table shows as its rendered block.
    /// The source stays in the text, hidden, with its line as tall as the component.
    func styleOverlays() {
        guard let storage = textStorage else { return }
        let source = storage.mutableString
        var active = Set<OverlayKey>()
        func install(_ range: NSRange, link: EditorLink?, root: AnyView) {
            let key = OverlayKey(offset: range.location, source: source.substring(with: range))
            active.insert(key)
            let overlay = overlays[key] ?? EditorOverlayView(editor: self, range: range, link: link, root: root)
            if overlays[key] == nil { overlays[key] = overlay; addSubview(overlay) } else { overlay.rootView = root }
            overlay.reserved = overlay.height(at: container.size.width)
            storage.addAttributes([.font: Typography.Prose.hiddenSyntax, .foregroundColor: NSColor.clear], range: range)
            // The overlay's own height is the whole of the component's room. Every
            // hidden source line beneath it must contribute nothing — including line
            // spacing, which `maximumLineHeight` does not clamp — and the last line
            // owns the gap to whatever follows, the way any other block does.
            let lines = document.blocks.filter { NSIntersectionRange($0.range, range).length > 0 }
            for (index, line) in lines.enumerated() {
                let paragraph = NSMutableParagraphStyle()
                paragraph.setParagraphStyle(Typography.Prose.paragraphStyle)
                paragraph.lineSpacing = 0
                paragraph.paragraphSpacingBefore = 0
                paragraph.paragraphSpacing = index == lines.count - 1 ? Typography.Prose.blockSpacing : 0
                if index == 0 {
                    paragraph.minimumLineHeight = overlay.reserved
                } else {
                    paragraph.minimumLineHeight = 0
                    paragraph.maximumLineHeight = Typography.Prose.hiddenSyntax.pointSize
                }
                storage.addAttribute(.paragraphStyle, value: paragraph, range: NSIntersectionRange(line.range, range))
            }
        }
        for link in document.links {
            guard case .reference(let reference)? = target(of: link),
                  source.substring(with: source.lineRange(for: link.range)).trimmingCharacters(in: .whitespacesAndNewlines) == source.substring(with: link.range) else { continue }
            install(link.range, link: .reference(reference), root: AnyView(Card(ref: reference, style: .group, isSelected: selectedRange() == link.range)))
        }
        for table in tables { install(table, link: nil, root: AnyView(TextBlock(content: source.substring(with: table)))) }
        for key in Set(overlays.keys).subtracting(active) { overlays.removeValue(forKey: key)?.removeFromSuperview() }
    }

    func layoutOverlays() {
        for overlay in overlays.values {
            guard let location = textRange(NSRange(location: overlay.sourceRange.location, length: 0))?.location,
                  let fragment = textLayout.textLayoutFragment(for: location) else { continue }
            let height = overlay.height(at: container.size.width)
            overlay.frame = CGRect(x: textContainerOrigin.x, y: fragment.layoutFragmentFrame.minY + textContainerOrigin.y, width: container.size.width, height: height)
            // A component that changed size since styling needs its line resized to match.
            if abs(height - overlay.reserved) > 0.5 { restyleOverlays() }
        }
    }
}

struct OverlayKey: Hashable { let offset: Int; let source: String }

final class EditorOverlayView: EmbeddedView<AnyView> {
    weak var editor: ScintEditor?
    private(set) var sourceRange = NSRange()
    private(set) var link: EditorLink?
    /// The line height set aside for the component when the text was styled.
    var reserved: CGFloat = 0
    var isSelected = false {
        didSet {
            guard isSelected != oldValue, case .reference(let ref)? = link else { return }
            rootView = AnyView(Card(ref: ref, style: .group, isSelected: isSelected))
        }
    }

    convenience init(editor: ScintEditor, range: NSRange, link: EditorLink?, root: AnyView) {
        self.init(rootView: root)
        self.editor = editor; sourceRange = range; self.link = link
    }

    override func mouseDown(with event: NSEvent) {
        editor?.activate(link == nil ? NSRange(location: sourceRange.location, length: 0) : sourceRange, link: link, with: event)
    }
}
