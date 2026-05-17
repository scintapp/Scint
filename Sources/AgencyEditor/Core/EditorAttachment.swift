import AppKit
import SwiftUI


final class EditorAttachmentView: NSView {
    private(set) var entry: Entry
    private(set) var size: CGSize
    private let host: NSHostingView<AnyView>

    init(entry: Entry, size: CGSize, rootView: AnyView) {
        self.entry = entry
        self.size = size
        self.host = NSHostingView(rootView: rootView)
        super.init(frame: CGRect(origin: .zero, size: size))
        host.translatesAutoresizingMaskIntoConstraints = true
        addSubview(host)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(entry: Entry, size: CGSize, rootView: AnyView) {
        self.entry = entry
        self.size = size
        host.rootView = rootView
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: size.width, height: size.height)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        discardCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func layout() {
        super.layout()
        host.frame = bounds
    }
}

nonisolated final class EditorAttachment: NSTextAttachment {
    nonisolated private static let tokenRegex = try! NSRegularExpression(
        pattern: #"\{\{component:([0-9A-Fa-f\-]{36})\}\}"#
    )

    let entry: Entry

    nonisolated init(entry: Entry) {
        self.entry = entry
        super.init(data: nil, ofType: nil)
        self.allowsTextAttachmentView = false
        self.attachmentCell = nil
        self.lineLayoutPadding = 0
        self.bounds = CGRect(origin: .zero, size: displaySize)
    }

    nonisolated required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var token: String {
        Self.token(for: entry.id)
    }

    var tokenLength: Int {
        (token as NSString).length
    }

    nonisolated var displaySize: CGSize {
        InlineComponentView.size(for: entry)
    }

    nonisolated static func token(for id: UUID) -> String {
        "{{component:\(id.uuidString.lowercased())}}"
    }

    nonisolated static func matches(in text: String) -> [NSTextCheckingResult] {
        tokenRegex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }

    nonisolated static func id(in result: NSTextCheckingResult, text: String) -> UUID? {
        guard result.numberOfRanges > 1 else { return nil }
        let value = (text as NSString).substring(with: result.range(at: 1))
        return UUID(uuidString: value)
    }

    nonisolated override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        let size = displaySize
        return CGRect(x: 0, y: -2, width: size.width, height: size.height)
    }

    nonisolated override func image(
        for bounds: CGRect,
        attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?
    ) -> NSImage? {
        nil
    }

}
