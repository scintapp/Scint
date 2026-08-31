import AppKit
import SwiftUI


/// How an inline reference presents itself.
///
/// Artifacts — and tags, when they arrive — are chips: a name in a sentence. Materials and
/// commands are components, because they have enough surface to be summarised and worked with in
/// place rather than just named.
enum ReferencePresentation {
    case chip
    case component

    static func of(_ ref: Reference) -> ReferencePresentation {
        switch ref.type {
            case is Command.Type, is Material.Type: return .component
            default: return .chip
        }
    }

    var fillsWidth: Bool { self == .component }
}

struct ReferenceView: View {
    let ref: Reference
    let label: String
    let presentation: ReferencePresentation

    var body: some View {
        switch presentation {
            case .chip: ReferenceChip(ref: ref, label: label)
            case .component: ReferenceComponent(ref: ref)
        }
    }
}

struct ReferenceComponent: View {
    let ref: Reference

    @State private var isHovered = false

    private var isSelected: Bool { ReferenceSelection.shared.selected == ref }

    var body: some View {
        Button {
            ReferenceSelection.shared.selected = ref
            ReferenceRouter.open(ref)
        } label: {
            card
                .background(Style.Shape.medium.fill(Style.Background.panel))
                .overlay(
                    Style.Shape.medium.strokeBorder(
                        isSelected
                            ? Iconography.accent(for: ref).opacity(Style.Opacity.faint)
                            : isHovered
                            ? Color.primary.opacity(Style.Opacity.hairline)
                            : Style.Border.raised,
                        lineWidth: 1
                    )
                )
                .contentShape(Style.Shape.medium)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .referenceMenu(ref)
    }

    @ViewBuilder private var card: some View {
        switch ref.type {
            case is Command.Type: CommandCard(ref: ref)
            case is Material.Type: MaterialRefCard(ref: ref)
            default: EmptyView()
        }
    }
}

struct ReferenceChip: View {
    let ref: Reference
    let label: String

    @State private var isHovered = false

    private var tint: Color { Iconography.accent(for: ref) }
    private var isSelected: Bool { ReferenceSelection.shared.selected == ref }

    private var fill: Color {
        tint.opacity(isSelected ? Style.Opacity.faint : isHovered ? Style.Opacity.hairline : Style.Opacity.washed)
    }

    private var stroke: Color {
        tint.opacity(isSelected ? Style.Opacity.strong : Style.Opacity.faint)
    }

    var body: some View {
        Button {
            ReferenceSelection.shared.selected = ref
            ReferenceRouter.open(ref)
        } label: {
            HStack(spacing: Style.Spacing.sm) {
                Iconography.icon(for: ref, size: Typography.Scale.inline)
                    .frame(width: Typography.Scale.inline, height: Typography.Scale.inline)

                Text(label)
                    .font(Typography.chip)
                    .foregroundStyle(Style.Foreground.base)
                    .lineLimit(Style.Limit.singleLine)
            }
            .padding(.horizontal, Style.Spacing.md)
            // Matched to the line it sits on, so a chip never pushes the leading around it.
            .frame(height: Typography.Prose.appKitLineHeight)
            .background(Style.Shape.capsule.fill(fill))
            .overlay(Style.Shape.capsule.strokeBorder(stroke, lineWidth: 1))
            .contentShape(Style.Shape.capsule)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .referenceMenu(ref)
    }
}

/// Copying the address out of a document.
///
/// The URL is concealed where it sits, which is right for reading and leaves no way to get one
/// into a terminal, a note, or another app. This is that way.
extension View {
    func referenceMenu(_ ref: Reference) -> some View {
        contextMenu {
            Button("Copy Link") {
                guard let url = ReferenceURL.url(for: ref) else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            }
            Button("Copy Markdown Link") {
                guard let markdown = ReferenceURL.markdown(for: ref) else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(markdown, forType: .string)
            }
        }
    }
}

/// A reference standing in for its markdown link inside the text.
///
/// The storage holds one attachment character where the source holds `[Label](scint://…)`.
/// `source` is what goes back to the document, so the text still round-trips as plain markdown —
/// nothing about the stored value changed to make chips possible.
/// `@unchecked Sendable` because `NSTextAttachment`'s view-provider hook is nonisolated, so the
/// class cannot be `@MainActor` without breaking the override. Every instance is created by the
/// themer and read by the layout manager, both on the main thread only.
final class ReferenceAttachment: NSTextAttachment, @unchecked Sendable {
    let ref: Reference
    let label: String
    let source: String
    let presentation: ReferencePresentation

    init(ref: Reference, label: String, source: String) {
        self.ref = ref
        self.label = label
        self.source = source
        self.presentation = .of(ref)
        super.init(data: nil, ofType: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewProvider(
        for parentView: NSView?,
        location: any NSTextLocation,
        textContainer: NSTextContainer?
    ) -> NSTextAttachmentViewProvider? {
        let provider = ReferenceChipProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
        provider.tracksTextAttachmentViewBounds = true
        return provider
    }
}

/// Hosts the chip as a real view in the text flow. This is the whole reason the input view runs on
/// TextKit 2 — TextKit 1 attachment cells draw, but they cannot host a live, clickable view.
/// `NSTextAttachmentViewProvider` declares these overrides nonisolated, so they cannot be made
/// `@MainActor` without mismatching the superclass. TextKit calls both during layout of an
/// `NSTextView`, which is main-thread work, so the isolation is asserted rather than assumed away.
final class ReferenceChipProvider: NSTextAttachmentViewProvider {
    override func loadView() {
        guard let attachment = textAttachment as? ReferenceAttachment else { return }
        // Only Sendable values cross into the view; the attachment itself stays put.
        let ref = attachment.ref
        let label = attachment.label
        let presentation = attachment.presentation

        view = MainActor.assumeIsolated {
            let hosting = NSHostingView(
                rootView: ReferenceView(ref: ref, label: label, presentation: presentation)
            )
            hosting.translatesAutoresizingMaskIntoConstraints = false
            return hosting
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
        let fillsWidth = (textAttachment as? ReferenceAttachment)?.presentation.fillsWidth ?? false
        let available = max(textContainer?.size.width ?? proposedLineFragment.width, 1)
        // The descender, not the font: `NSFont` is not Sendable and only this number is needed.
        let baseline = (attributes[.font] as? NSFont ?? Typography.Prose.appKitText).descender

        return MainActor.assumeIsolated {
            // Sit on the text baseline rather than the line's bottom, so an inline reference lines
            // up with the words either side of it instead of riding high.
            guard fillsWidth else {
                let size = view.fittingSize
                return CGRect(x: 0, y: baseline, width: size.width, height: size.height)
            }

            // A component takes the column, and its height follows its content.
            view.frame.size.width = available
            return CGRect(x: 0, y: baseline, width: available, height: view.fittingSize.height)
        }
    }
}
