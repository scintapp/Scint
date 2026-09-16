import AppKit

// The harness instruments the production scanner at compilation, so this counts
// actual scan calls, including indirect calls through computed editor properties.
final class MarkdownScanProbe: @unchecked Sendable {
    static let shared = MarkdownScanProbe()
    private let lock = NSLock()
    private var count = 0
    func record() { lock.lock(); count += 1; lock.unlock() }
    func reset() { lock.lock(); count = 0; lock.unlock() }
    var calls: Int { lock.lock(); defer { lock.unlock() }; return count }
}

@MainActor enum EditorPerformance {
    static func run() {
        for (count, withTables) in [(100, false), (300, false), (600, false), (300, true)] {
            let source = (0..<count).map { index in
                let paragraph = "\(index % 3 == 0 ? "- " : "")Paragraph \(index): **bold text**, `inline code`, and a [link](https://example.com/path)."
                return withTables && index % 15 == 0 ? paragraph + "\n\n| Item | Value |\n| --- | --- |\n| Entry | 123 |\n\n" : paragraph
            }.joined(separator: "\n")
            let ref = Reference(), id = UUID()
            Material.store[ref] = Material(blocks: [.text(id, source)])
            let editor = Editor(material: ref)
            let host = EditorDocumentView(editor: editor, sizing: .fitsContent, autofocus: false, onFocus: {}, onReturn: nil, onEditCard: { _, _ in })
            let view = EditorTextView(editor: editor, id: id, host: host)
            view.setFrameSize(CGSize(width: 640, height: 600))
            view.setFrameSize(CGSize(width: 640, height: view.contentHeight))
            editor.attach(view, to: id)
            let scroll = NSScrollView(frame: CGRect(x: 0, y: 0, width: 640, height: 600))
            scroll.documentView = view
            let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
            window.contentView = scroll
            view.layoutSubtreeIfNeeded()
            let image = NSImage(size: CGSize(width: 640, height: 600))
            var times: [Double] = []
            for index in 0..<3 {
                let y = min(max(0, view.bounds.height - 600), CGFloat(index + 1) * 240)
                image.lockFocus()
                NSGraphicsContext.saveGraphicsState()
                let transform = AffineTransform(translationByX: 0, byY: -y)
                (transform as NSAffineTransform).concat()
                CGRect(x: 0, y: y, width: 640, height: 600).clip()
                MarkdownScanProbe.shared.reset()
                let start = CFAbsoluteTimeGetCurrent()
                scroll.contentView.scroll(to: CGPoint(x: 0, y: y))
                scroll.reflectScrolledClipView(scroll.contentView)
                view.layoutSubtreeIfNeeded()
                view.draw(CGRect(x: 0, y: y, width: 640, height: 600))
                times.append((CFAbsoluteTimeGetCurrent() - start) * 1000)
                precondition(MarkdownScanProbe.shared.calls == 0, "Scrolling reparsed Markdown \(MarkdownScanProbe.shared.calls) times")
                guard let visible = view.sourceRange(intersecting: CGRect(x: 0, y: y, width: 640, height: 600)) else {
                    preconditionFailure("Benchmark failed to draw visible text")
                }
                precondition(visible.length > 0 && visible.length < source.utf16.count, "Draw did not restrict layout to the viewport")
                NSGraphicsContext.restoreGraphicsState()
                image.unlockFocus()
            }
            // A range selection and a link selection must use the same cached
            // scan as a caret; selectedLink used to hide an indirect full parse.
            for range in [NSRange(location: 0, length: 5), view.document.links[0].range] {
                editor.place(.text(id: id, anchor: range.location, head: NSMaxRange(range)))
                image.lockFocus()
                MarkdownScanProbe.shared.reset()
                scroll.contentView.scroll(to: .zero)
                view.draw(CGRect(x: 0, y: 0, width: 640, height: 600))
                precondition(MarkdownScanProbe.shared.calls == 0, "Drawing a selection reparsed Markdown")
                image.unlockFocus()
            }
            let result = "Editor scroll benchmark: \(count) paragraphs\(withTables ? " + 20 tables" : ""), \(source.utf16.count) UTF-16 units, frame milliseconds \(times.map { String(format: "%.2f", $0) }.joined(separator: ", "))\n"
            FileHandle.standardError.write(Data(result.utf8))
            precondition(times.sorted()[times.count / 2] < 100, "Scroll frame exceeded the 100 ms regression ceiling")
            precondition(view.storage.string == source && editor.string(id) == source, "Scrolling changed source")
            window.contentView = nil
        }
    }
}
