import AppKit
import SwiftUI
import ScintRuntime


enum EditorLink: Equatable { case reference(Reference), url(URL) }

struct EditorView: NSViewRepresentable {
    enum Sizing { case fitsContent, grows(min: CGFloat, max: CGFloat) }

    let document: Reference
    let sizing: Sizing
    let autofocus: Bool
    let onFocus: () -> Void
    let onOpenLink: (EditorLink) -> Void

    init(_ document: Reference, sizing: Sizing = .fitsContent, autofocus: Bool = true,
         onFocus: @escaping () -> Void = {}, onOpenLink: @escaping (EditorLink) -> Void = { _ in }) {
        self.document = document; self.sizing = sizing; self.autofocus = autofocus
        self.onFocus = onFocus; self.onOpenLink = onOpenLink
    }

    func makeNSView(context: Self.Context) -> EditorScrollView {
        EditorScrollView(ScintEditor(document, autofocus: autofocus), sizing: sizing)
    }

    func updateNSView(_ view: EditorScrollView, context: Self.Context) {
        view.editor.onFocus = onFocus; view.editor.onOpenLink = onOpenLink
        view.editor.load(Document.with(document, { $0.blocks }) ?? [])
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView view: EditorScrollView, context: Self.Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let height = view.editor.height(for: width) + (view.isFindBarVisible ? view.findBarView?.frame.height ?? 0 : 0)
        guard case .grows(let lower, let upper) = sizing else { return CGSize(width: width, height: height) }
        return CGSize(width: width, height: min(max(height, lower), upper))
    }
}

final class EditorScrollView: NSScrollView {
    let editor: ScintEditor
    private let scrolls: Bool

    init(_ editor: ScintEditor, sizing: EditorView.Sizing) {
        self.editor = editor
        if case .grows = sizing { scrolls = true } else { scrolls = false }
        super.init(frame: .zero)
        drawsBackground = false; hasVerticalScroller = scrolls; documentView = editor
    }

    required init?(coder: NSCoder) { nil }

    override var isFindBarVisible: Bool { didSet { invalidateIntrinsicContentSize() } }
    override func findBarViewDidChangeHeight() { super.findBarViewDidChangeHeight(); invalidateIntrinsicContentSize() }

    override func scrollWheel(with event: NSEvent) {
        if scrolls { super.scrollWheel(with: event) } else { nextResponder?.scrollWheel(with: event) }
    }
}
