import AppKit
import SwiftUI
import AgencyRuntime


private enum InlineComponentPresentation {
    case artifact(Reference)
    case control(Reference)
    case service(Reference)
    case sheet(Reference)
    case todo(UUID, String, Bool)

    init?(_ entry: Entry) {
        switch entry {
        case .artifact(let ref), .control(let ref), .service(let ref), .sheet(let ref):
            self.init(ref)
        case .todo(let id, let title, let complete):
            self = .todo(id, title, complete)
        case .text:
            return nil
        }
    }

    nonisolated static func title(for entry: Entry) -> String {
        Self(entry)?.title ?? ""
    }

    private init?(_ ref: Reference) {
        switch ref.type {
        case is Artifact.Type:
            self = .artifact(ref)
        case is Control.Type:
            self = .control(ref)
        case is Service.Type:
            self = .service(ref)
        case is Sheet.Type:
            self = .sheet(ref)
        default:
            return nil
        }
    }

    var title: String {
        switch self {
        case .artifact(let ref), .control(let ref), .service(let ref), .sheet(let ref): return ref.name
        case .todo(_, let title, _): return title
        }
    }

    var icon: String {
        switch self {
        case .artifact(let ref), .control(let ref), .service(let ref), .sheet(let ref):
            return Design.Component.icon(for: ref)
        case .todo(_, _, let complete): return complete ? "checkmark.circle.fill" : "circle"
        }
    }

    var tint: Color {
        switch self {
        case .artifact: return Design.Tint.artifact
        case .control: return Design.Tint.control
        case .service: return Design.Tint.service
        case .sheet: return Design.Tint.sheet
        case .todo:
            return Design.Tint.task
        }
    }

    var isMuted: Bool {
        switch self {
        case .artifact, .control, .service, .sheet: return false
        case .todo(_, _, let complete): return complete
        }
    }

    var isStruck: Bool {
        switch self {
        case .artifact, .control, .service, .sheet: return false
        case .todo(_, _, let complete): return complete
        }
    }

    var help: String {
        switch self {
        case .artifact(let ref), .control(let ref), .service(let ref), .sheet(let ref):
            return ref.description
        case .todo: return ""
        }
    }
}


struct InlineComponentView: View {
    let entry: Entry
    let activate: () -> Void
    let update: (Entry) -> Void

    nonisolated static var chipHeight: CGFloat { 21 }

    nonisolated static func size(for entry: Entry) -> CGSize {
        let title = InlineComponentPresentation.title(for: entry)
        let font = NSFont.systemFont(ofSize: 13, weight: .light)
        let titleWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
        return CGSize(width: max(72, titleWidth + 42), height: chipHeight)
    }

    var body: some View {
        if let presentation = InlineComponentPresentation(entry) {
            Button(action: performActivation) {
                HStack(spacing: 6) {
                    Image(systemName: presentation.icon)
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(presentation.tint.opacity(presentation.isMuted ? 0.48 : 1.0))
                        .frame(width: 13, height: 13)
                        .frame(width: Self.chipHeight, height: Self.chipHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(presentation.tint.opacity(presentation.isMuted ? 0.08 : 0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(presentation.tint.opacity(presentation.isMuted ? 0.12 : 0.21), lineWidth: 0.5)
                                )
                        )

                    Text(presentation.title)
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(.primary.opacity(presentation.isMuted ? 0.45 : 0.9))
                        .strikethrough(presentation.isStruck, color: .primary.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxHeight: Self.chipHeight, alignment: .leading)
                }
                .frame(height: Self.chipHeight)
            }
            .buttonStyle(.plain)
            .frame(
                width: Self.size(for: entry).width,
                height: Self.chipHeight,
                alignment: .center
            )
            .help(presentation.help)
        }
    }

    private func performActivation() {
        switch entry {
        case .todo(let id, let title, let complete):
            update(.todo(id, title, !complete))
        default:
            activate()
        }
    }
}
