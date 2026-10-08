import AppKit
import SwiftUI
import ScintRuntime
import ScintComponents


@MainActor struct ProseDrawing {
    let layout: NSTextLayoutManager
    let content: NSTextContentStorage
    let origin: CGPoint
    let width: CGFloat
    let document: Markdown.Document
    let styler: Styler
    let source: NSString
    let listStart: Int

    static func height(of layout: NSTextLayoutManager, in container: NSTextContainer, width: CGFloat, font: NSFont) -> CGFloat {
        if abs(container.size.width - width) > 0.5 {
            container.size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            layout.invalidateLayout(for: layout.documentRange)
        }
        layout.ensureLayout(for: layout.documentRange)
        var bottom: CGFloat = 0
        layout.enumerateTextLayoutFragments(from: layout.documentRange.endLocation, options: [.reverse, .ensuresLayout, .ensuresExtraLineFragment]) {
            bottom = $0.layoutFragmentFrame.maxY; return false
        }
        return max(font.ascender - font.descender, layout.usageBoundsForTextContainer.maxY, bottom)
    }

    func textRange(_ range: NSRange) -> NSTextRange? {
        guard let start = content.location(content.documentRange.location, offsetBy: range.location),
              let end = content.location(start, offsetBy: range.length) else { return nil }
        return NSTextRange(location: start, end: end)
    }

    func frames(for range: NSRange, type: NSTextLayoutManager.SegmentType = .standard) -> [CGRect] {
        guard let range = textRange(range) else { return [] }
        var frames: [CGRect] = []
        layout.enumerateTextSegments(in: range, type: type, options: [.rangeNotRequired]) { _, frame, _, _ in
            frames.append(frame.offsetBy(dx: origin.x, dy: origin.y)); return true
        }
        return frames
    }

    func draw(_ dirtyRect: CGRect, selectedLink: Markdown.Link?) {
        let top = layout.textLayoutFragment(for: CGPoint(x: 0, y: dirtyRect.minY - origin.y))?.rangeInElement.location ?? content.documentRange.location
        let bottom = layout.textLayoutFragment(for: CGPoint(x: 0, y: dirtyRect.maxY - origin.y))?.rangeInElement.endLocation ?? content.documentRange.endLocation
        let visible = NSRange(location: content.offset(from: content.documentRange.location, to: top), length: max(0, content.offset(from: top, to: bottom)))
        func shows(_ range: NSRange) -> Bool { NSIntersectionRange(range, visible).length > 0 || NSLocationInRange(range.location, visible) }
        func runs(of kind: Markdown.BlockKind) -> [CGRect] {
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

        for span in document.spans where span.kind == .inlineCode && shows(span.range) {
            guard let range = textRange(span.range) else { continue }
            layout.enumerateTextSegments(in: range, type: .standard, options: [.rangeNotRequired]) { _, frame, baseline, _ in
                let run = frame.offsetBy(dx: origin.x, dy: origin.y)
                MarkdownDecoration.inlineCode(run, baseline: run.minY + baseline); return true
            }
        }
        for rect in runs(of: .codeBlock) {
            let padding = Typography.Prose.codeBlockPadding
            MarkdownDecoration.codeBlock(CGRect(x: origin.x, y: rect.minY - padding.top, width: width, height: rect.height + padding.top + padding.bottom))
        }
        styler.theme.bulletColor.setFill()
        for rect in runs(of: .quote) {
            CGRect(x: origin.x, y: rect.minY, width: Typography.Prose.quoteBarWidth, height: rect.height).fill()
        }
        for (index, block) in document.blocks.enumerated() where (block.kind == .bullet || block.kind == .numbered) && shows(block.range) {
            guard let line = frames(for: block.range).first else { continue }
            let gutter = CGRect(x: origin.x + styler.listIndent(for: block), y: line.minY, width: styler.gutter(for: block, in: source), height: line.height)
            if block.kind == .bullet {
                let size = Typography.Prose.bulletSize
                NSBezierPath(ovalIn: CGRect(x: gutter.midX - size / 2, y: gutter.midY - size / 2, width: size, height: size)).fill()
            } else {
                var ordinal = 1, continued = true
                for previous in document.blocks[..<index].reversed() {
                    guard previous.kind.isList, previous.depth >= block.depth else { continued = false; break }
                    guard previous.depth == block.depth else { continue }
                    guard previous.kind == .numbered else { continued = false; break }
                    ordinal += 1
                }
                ("\(ordinal + (continued ? listStart : 0))." as NSString).draw(at: gutter.origin, withAttributes: [.font: styler.theme.baseFont, .foregroundColor: styler.theme.bulletColor])
            }
        }
        for link in document.links where shows(link.range) {
            let isSelected = selectedLink?.range == link.range
            guard isSelected || Reference.Link.resolve(in: source.substring(with: link.url)) != nil else { continue }
            (isSelected ? NSColor.selectedTextBackgroundColor : styler.theme.codeBgColor).setFill()
            for rect in frames(for: link.label) { NSBezierPath(roundedRect: rect.insetBy(dx: -2, dy: -1), xRadius: 4, yRadius: 4).fill() }
        }
    }
}

extension ScintEditor {
    var prose: ProseDrawing {
        ProseDrawing(
            layout: textLayout, content: content, origin: textContainerOrigin, width: container.size.width,
            document: document, styler: styler, source: source, listStart: listStart
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let prose = prose, selected = selectedLink
        prose.draw(dirtyRect, selectedLink: selected)
        if selected == nil {
            (window?.isKeyWindow == true && window?.firstResponder === self ? NSColor.selectedTextBackgroundColor : .unemphasizedSelectedTextBackgroundColor).setFill()
            if selectedRange().length > 0 { for rect in prose.frames(for: selectedRange(), type: .selection) { rect.fill() } }
        }
        if let origin = placeholderOrigin {
            (placeholder as NSString).draw(
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
        guard window?.firstResponder === self, selection.length == 0, !hasMarkedText(), !menuProvider.isOpen else { return nil }
        guard source.substring(with: source.lineRange(for: selection)).trimmingCharacters(in: .newlines).isEmpty else { return nil }
        return prose.frames(for: selection, type: .selection).first?.origin
    }
}
