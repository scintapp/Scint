import AppKit

extension ScintEditorView {
    func textRange(_ range: NSRange) -> NSTextRange? {
        guard let start = content.location(content.documentRange.location, offsetBy: range.location),
              let end = content.location(content.documentRange.location, offsetBy: NSMaxRange(range)) else { return nil }
        return NSTextRange(location: start, end: end)
    }
    func sourceRange(_ range: NSTextRange) -> NSRange {
        NSRange(location: content.offset(from: content.documentRange.location, to: range.location),
                length: content.offset(from: range.location, to: range.endLocation))
    }
    func frames(for range: NSRange) -> [CGRect] {
        guard let range = textRange(range) else { return [] }
        var frames: [CGRect] = []
        textLayout.enumerateTextSegments(in: range, type: .standard, options: [.rangeNotRequired]) { _, frame, _, _ in
            frames.append(frame.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y)); return true
        }
        return frames
    }
    var caretScreenRect: CGRect {
        guard case .text(id, _, let head) = editor.position else { return .zero }
        return firstRect(forCharacterRange: NSRange(location: head, length: 0), actualRange: nil)
    }
    func navigate(_ direction: NSTextSelectionNavigation.Direction, destination: NSTextSelectionNavigation.Destination, extending: Bool) {
        guard case .text(id, let anchor, let head) = editor.position,
              let range = textRange(NSRange(location: min(anchor, head), length: abs(head - anchor))) else { return }
        let selection = NSTextSelection(range: range, affinity: head < anchor ? .upstream : .downstream, granularity: .character)
        guard let next = textLayout.textSelectionNavigation.destinationSelection(for: selection, direction: direction, destination: destination, extending: extending, confined: false),
              let nextRange = next.textRanges.first else { return }
        let source = sourceRange(nextRange)
        let nextHead = next.affinity == .upstream ? source.location : NSMaxRange(source)
        if nextHead == head && (direction == .up || direction == .down) {
            if !extending { editor.crossBoundary(direction == .up ? .up : .down) }
        } else { editor.place(.text(id: id, anchor: extending ? anchor : nextHead, head: nextHead)) }
    }
    // Use laid-out fragments to locate the repaint range. Scrolling must not ask
    // TextKit for segments of every paragraph, including offscreen paragraphs.
    func sourceRange(intersecting rect: CGRect) -> NSRange? {
        let local = rect.offsetBy(dx: -textContainerOrigin.x, dy: -textContainerOrigin.y)
        let viewport = textLayout.textViewportLayoutController
        let start = viewport.viewportBounds.minY <= local.minY ? viewport.viewportRange?.location : nil
        var first: (any NSTextLocation)?, last: (any NSTextLocation)?
        textLayout.enumerateTextLayoutFragments(from: start ?? textLayout.documentRange.location, options: []) { fragment in
            let frame = fragment.layoutFragmentFrame
            if frame.minY > local.maxY { return false }
            if frame.maxY >= local.minY {
                if first == nil { first = fragment.rangeInElement.location }
                last = fragment.rangeInElement.endLocation
            }
            return true
        }
        guard let first, let last, let range = NSTextRange(location: first, end: last) else { return nil }
        return sourceRange(range)
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let visible = sourceRange(intersecting: dirtyRect.insetBy(dx: -4, dy: -4)) else {
            super.draw(dirtyRect); return
        }
        // Derived once from Editor.position and the already cached scan.
        let selectedLink = selectedMarkdownLink
        for span in document.spans where span.kind == .inlineCode && NSIntersectionRange(span.range, visible).length > 0 {
            guard !overlays.values.contains(where: { NSIntersectionRange($0.sourceRange, span.range).length > 0 }) else { continue }
            for rect in frames(for: span.range) where rect.intersects(dirtyRect.insetBy(dx: -4, dy: -4)) {
                MarkdownDecoration.code(rect.insetBy(dx: -Style.Spacing.sm, dy: -Style.Spacing.xs))
            }
        }
        for (index, block) in document.blocks.enumerated() where NSIntersectionRange(block.range, visible).length > 0 {
            switch block.kind {
            case .codeBlock, .quote, .bullet, .numbered: break
            default: continue
            }
            guard let frame = frames(for: block.range).first else { continue }
            switch block.kind {
            case .codeBlock:
                MarkdownDecoration.code(CGRect(x: textContainerOrigin.x, y: frame.minY, width: container.size.width, height: frame.height))
            case .quote:
                styler.theme.bulletColor.setFill()
                CGRect(x: frame.minX, y: frame.minY, width: Style.Dimension.markdownQuoteBar, height: frame.height).fill()
            case .bullet:
                styler.theme.bulletColor.setFill()
                NSBezierPath(ovalIn: CGRect(x: frame.minX, y: frame.midY - 2, width: 4, height: 4)).fill()
            case .numbered:
                let ordinal = listContexts[index]?.ordinal ?? 1
                ("\(ordinal)." as NSString).draw(at: frame.origin, withAttributes: [.font: styler.theme.baseFont, .foregroundColor: styler.theme.bulletColor])
            default: break
            }
        }
        let source = storage.string as NSString
        for link in document.links where NSIntersectionRange(link.range, visible).length > 0 {
            let isReference = Reference.Link.reference(in: source.substring(with: link.url)) != nil
            let selected = selectedLink?.range == link.range
            guard isReference || selected else { continue }
            for rect in frames(for: link.label) {
                (selected ? NSColor.selectedTextBackgroundColor : styler.theme.codeBgColor).setFill()
                NSBezierPath(roundedRect: rect.insetBy(dx: -2, dy: -1), xRadius: 4, yRadius: 4).fill()
            }
        }
        super.draw(dirtyRect)
    }
}
