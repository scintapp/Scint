import AppKit
import SwiftUI


struct EditorView: View {
    @State private var editor: ScintEditor
    let sizing: Sizing
    let autofocus: Bool
    let onFocus: () -> Void
    let onReturn: (() -> Bool)?
    let onEditCard: (AnyHashable, CGRect) -> Void
    let onOpenLink: (ScintEditor.Link) -> Void

    enum Sizing { case fitsContent, grows(min: CGFloat, max: CGFloat), fills }

    init(_ material: Reference, sizing: Sizing = .fitsContent, autofocus: Bool = true,
         onFocus: @escaping () -> Void = {}, onReturn: (() -> Bool)? = nil,
         onEditCard: @escaping (AnyHashable, CGRect) -> Void = { _, _ in },
         onOpenLink: @escaping (ScintEditor.Link) -> Void = { _ in }) {
        _editor = State(initialValue: ScintEditor(material))
        self.sizing = sizing; self.autofocus = autofocus; self.onFocus = onFocus
        self.onReturn = onReturn; self.onEditCard = onEditCard; self.onOpenLink = onOpenLink
    }

    var body: some View {
        EditorViewport(editor: editor, sizing: sizing, autofocus: autofocus, onFocus: onFocus, onReturn: onReturn, onEditCard: onEditCard)
            .onAppear { editor.onOpenLink = onOpenLink }
            .onChange(of: editor.selectedReference) { _, reference in ReferenceSelection.shared.selected = reference }
    }
}

private struct EditorViewport: NSViewRepresentable {
    let editor: ScintEditor
    let sizing: EditorView.Sizing
    let autofocus: Bool
    let onFocus: () -> Void
    let onReturn: (() -> Bool)?
    let onEditCard: (AnyHashable, CGRect) -> Void

    func makeNSView(context: Self.Context) -> EditorDocumentView {
        EditorDocumentView(editor: editor, sizing: sizing, autofocus: autofocus, onFocus: onFocus, onReturn: onReturn, onEditCard: onEditCard)
    }

    func updateNSView(_ view: EditorDocumentView, context: Self.Context) {
        _ = editor.position; _ = editor.blocks; _ = editor.trigger
        view.refresh()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: EditorDocumentView, context: Self.Context) -> CGSize? {
        let width = proposal.width ?? 500
        nsView.setFrameSize(CGSize(width: width, height: nsView.bounds.height))
        let content = nsView.documentHeight
        let height: CGFloat
        switch sizing {
        case .fitsContent: height = content
        case .grows(let min, let max): height = Swift.min(Swift.max(content, min), max)
        case .fills: height = proposal.height ?? content
        }
        return CGSize(width: width, height: height)
    }
}
