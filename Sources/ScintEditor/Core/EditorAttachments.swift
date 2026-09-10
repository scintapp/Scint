import AppKit
import SwiftUI


final class ReferenceAttachment: NSTextAttachment, @unchecked Sendable {
    let ref: Reference
    let label: String
    let source: String
    let standalone: Bool

    init(ref: Reference, label: String, source: String, standalone: Bool) {
        self.ref = ref
        self.label = label
        self.source = source
        self.standalone = standalone
        super.init(data: nil, ofType: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func isStandalone(in text: NSString, range: NSRange) -> Bool {
        text.substring(with: text.lineRange(for: range))
            .trimmingCharacters(in: .whitespacesAndNewlines) == text.substring(with: range)
    }

    override func viewProvider(
        for parentView: NSView?,
        location: any NSTextLocation,
        textContainer: NSTextContainer?
    ) -> NSTextAttachmentViewProvider? {
        let provider = ReferenceAttachmentProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
        provider.tracksTextAttachmentViewBounds = true
        return provider
    }
}

final class ReferenceAttachmentProvider: NSTextAttachmentViewProvider {
    private var measureCard: (@MainActor @Sendable (CGSize) -> CGSize)?

    override func loadView() {
        guard let attachment = textAttachment as? ReferenceAttachment else { return }
        let ref = attachment.ref
        let label = attachment.label
        let standalone = attachment.standalone

        if standalone {
            let (hostedView, measure) = MainActor.assumeIsolated {
                let controller = NSHostingController(rootView: ReferenceCard(ref: ref))
                controller.view.translatesAutoresizingMaskIntoConstraints = false
                let measure: @MainActor @Sendable (CGSize) -> CGSize = { size in
                    controller.sizeThatFits(in: size)
                }
                return (controller.view, measure)
            }
            measureCard = measure
            view = hostedView
        } else {
            view = MainActor.assumeIsolated {
                let hosting = NSHostingView(rootView: ReferenceChip(ref: ref, label: label))
                hosting.translatesAutoresizingMaskIntoConstraints = false
                return hosting
            }
        }
    }

    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        guard let view else { return .zero }
        let measureCard = measureCard
        let padding = textContainer?.lineFragmentPadding ?? .zero
        let available = max((textContainer?.size.width ?? proposedLineFragment.width) - padding * 2, Style.Dimension.border)
        let baseline = (attributes[.font] as? NSFont ?? Typography.Prose.appKitText).descender

        return MainActor.assumeIsolated {
            guard let measureCard else {
                let size = view.fittingSize
                return CGRect(x: 0, y: baseline, width: size.width, height: size.height)
            }

            // Fitting size uses the unconstrained ideal width and misses wrapped text's height.
            let size = measureCard(CGSize(width: available, height: .greatestFiniteMagnitude))
            return CGRect(x: 0, y: baseline, width: available, height: ceil(size.height))
        }
    }
}
