import AppKit
import SwiftUI
import AgencyRuntime


enum ArtifactPresentation {
    static func from(_ entry: Artifact.Entry?) -> (image: String, color: Color, value: String) {
        guard let entry else { return ("doc", .gray, "Artifact") }

        let value = entry.url?.absoluteString ?? entry.name

        switch entry {
        case .app: return ("app", Design.Tint.artifact, value)
        case .file: return ("doc", Design.Tint.artifact, value)
        case .http: return ("link", Design.Tint.artifact, value)
        case .image: return ("photo", Design.Tint.artifact, value)
        case .script: return ("scroll", Design.Tint.artifact, value)
        case .skill: return ("sparkles", Design.Tint.artifact, value)
        case .exec: return ("terminal", Design.Tint.artifact, value)
        }
    }
}

private struct InlineArtifactChip: View {
    let ref: Reference
    let activate: () -> Void

    var body: some View {
        if let artifact = Artifact.with(ref, { $0 }) {
            let presentation = ArtifactPresentation.from(artifact.entry)
            InlineChip(
                title: artifact.name,
                icon: presentation.image,
                tint: presentation.color,
                isMuted: false,
                isStruck: false,
                action: activate
            )
            .help(presentation.value)
        }
    }
}

private struct InlineControlChip: View {
    let ref: Reference
    let activate: () -> Void

    var body: some View {
        let title = Control.with(ref) { $0.name } ?? "Control"
        let value = Control.with(ref) { control in
            Artifact.with(control.exec) { artifact in
                artifact.entry.url?.absoluteString
                ?? artifact.name
            }
        }.flatMap { $0 } ?? "Control"

        InlineChip(
            title: title,
            icon: "switch.2",
            tint: Design.Tint.control,
            isMuted: false,
            isStruck: false,
            action: activate
        )
        .help(value)
    }
}

private struct InlineChip: View {
    let title: String
    let icon: String
    let tint: Color
    let isMuted: Bool
    let isStruck: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(tint.opacity(isMuted ? 0.48 : 1.0))
                        .frame(maxWidth: 21, maxHeight: 21, alignment: .leading)
                }
                .padding(4)
                .frame(maxWidth: 21, maxHeight: 21, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(isMuted ? 0.08 : 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(tint.opacity(isMuted ? 0.12 : 0.21), lineWidth: 0.5)
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Text(title)
                .frame(maxHeight: 21, alignment: .leading)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(.primary.opacity(isMuted ? 0.45 : 0.9))
                .strikethrough(isStruck, color: .primary.opacity(0.4))
                .lineLimit(1)
        }
        .buttonStyle(.plain)
    }
}

struct InlineComponentView: View {
    let entry: Entry
    let activate: () -> Void

    nonisolated static func size(for entry: Entry) -> CGSize {
        let title = title(for: entry)
        let font = NSFont.systemFont(ofSize: 13)
        let titleWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
        return CGSize(width: max(72, titleWidth + 42), height: 21)
    }

    private nonisolated static func title(for entry: Entry) -> String {
        switch entry {
        case .artifact(let ref):
            let artifact = Artifact.with(ref) { $0 }
            if let artifact { return artifact.name }
            return "Artifact"
        case .control(let ref): return Control.with(ref) { $0.name } ?? "Control"
        case .sheet(let ref): return Sheet.with(ref) { $0.name } ?? "Sheet"
        case .text: return "Component"
        case .todo(_, let title, _): return title
        }
    }

    var body: some View {
        Group {
            switch entry {
            case .text: EmptyView()
            case .artifact(let ref):
                InlineArtifactChip(ref: ref, activate: activate)
                    .offset(y: 7)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)

            case .control(let ref):
                InlineControlChip(ref: ref, activate: activate)
                    .offset(y: 7)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)

            case .todo:
                EmptyView()

            case .sheet(let ref):
                InlineArtifactChip(ref: ref, activate: activate)
                    .offset(y: 7)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
            }
        }
    }
}
