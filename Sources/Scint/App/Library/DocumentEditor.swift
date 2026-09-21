import AppKit
import SwiftUI
import ScintRuntime
import ScintComponents


struct BlockEditor: NSViewRepresentable {
    let content: String
    let onChange: (String) -> Void

    func makeNSView(context: Self.Context) -> BlockTextView {
        let view = BlockTextView()
        view.delegate = context.coordinator
        view.string = content
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ view: BlockTextView, context: Self.Context) {
        context.coordinator.onChange = onChange
        if view.string != content { view.string = content }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView view: BlockTextView, context: Self.Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        return CGSize(width: width, height: view.height(for: width))
    }

    func makeCoordinator() -> Coordinator { Coordinator(onChange) }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var onChange: (String) -> Void

        init(_ onChange: @escaping (String) -> Void) { self.onChange = onChange }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            onChange(view.string)
        }
    }
}

final class BlockTextView: NSTextView {
    private let content = NSTextContentStorage()
    private let textLayout = NSTextLayoutManager()
    private let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))

    init() {
        content.addTextLayoutManager(textLayout)
        textLayout.textContainer = container
        container.lineFragmentPadding = 0
        container.widthTracksTextView = true
        super.init(frame: .zero, textContainer: container)
        isRichText = false
        drawsBackground = false
        textContainerInset = .zero
        font = Typography.Prose.text
    }

    required init?(coder: NSCoder) { nil }

    func height(for width: CGFloat) -> CGFloat {
        container.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        textLayout.ensureLayout(for: textLayout.documentRange)
        return textLayout.usageBoundsForTextContainer.height
    }
}
