import AgencyRuntime
import SwiftUI


struct EntryCard<Body: View>: View {
    let icon: String
    let label: String
    @ViewBuilder var content: () -> Body

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Design.SheetEntry.accent)

                Text(label.uppercased())
                    .font(.system(size: 12))
                    .foregroundStyle(Design.SheetEntry.textTertiary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .background(Design.SheetEntry.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Design.SheetEntry.stroke, lineWidth: 1)
        )
    }
}

struct StatusPill: View {
    let label: String

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Design.SheetEntry.accent)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(Design.SheetEntry.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Design.SheetEntry.accentSoft)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(Design.SheetEntry.accent.opacity(0.35), lineWidth: 1)
        )
    }
}

struct GhostButton: View {
    let label: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(label.uppercased())
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(1)
        }
        .foregroundStyle(Design.SheetEntry.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Design.SheetEntry.stroke, lineWidth: 1)
        )
    }
}

struct SheetTextView: View {
    let text: String

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var looksLikeBlock: Bool { text.contains("\n") && (trimmed.contains("- ") || trimmed.hasPrefix("##")) }
    private var isHeading: Bool { !trimmed.contains("\n") && trimmed.hasPrefix("#") }
    private var isQuote: Bool { trimmed.hasPrefix(">") }
    private var quotePrefix: String { ">" }

    private var attributed: AttributedString {
        (try? AttributedString(
            markdown: trimmed,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(trimmed)
    }

    private func stripped(_ prefix: String) -> String {
        var s = trimmed
        while s.hasPrefix(prefix) || s.hasPrefix(" ") {
            if s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
            else { s.removeFirst() }
        }
        return s
    }

    var body: some View {
        if looksLikeBlock {
            Text(text)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(Design.SheetEntry.textPrimary)
                .lineSpacing(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Design.SheetEntry.codeBlockBg)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Design.SheetEntry.accent.opacity(0.45), lineWidth: 1)
                )
        } else if isQuote {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Design.SheetEntry.accent)
                    .frame(width: 3)
                Text(stripped(quotePrefix))
                    .font(.system(size: 18, weight: .regular))
                    .italic()
                    .foregroundStyle(Design.SheetEntry.textSecondary)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 18)
            }
        } else if isHeading {
            Text(stripped("#"))
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Design.SheetEntry.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        } else {
            Text(attributed)
                .font(.system(size: 17))
                .foregroundStyle(Design.SheetEntry.textPrimary)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

//struct SheetEntryView: View {
//    var entry: Sheet.Entry
//
//    private func control(_ ref: Reference) -> some View {
//        let name = Control.with(ref, { $0.name }) ?? "tool"
//        let args = Artifact.with(ref, { $0.content }) ?? ""
//
//        return EntryCard(icon: "wrench.and.screwdriver", label: "Tool Call") {
//            HStack(spacing: 12) {
//                Text(name)
//                    .font(.system(size: 16, weight: .medium, design: .monospaced))
//                    .foregroundStyle(Design.SheetEntry.accent)
//
//                HStack(spacing: 6) {
//                    Text("(").foregroundStyle(Design.SheetEntry.textTertiary)
//                    Text(args)
//                        .foregroundStyle(Design.SheetEntry.textSecondary)
//                        .lineLimit(1)
//                        .truncationMode(.tail)
//                    Text(")").foregroundStyle(Design.SheetEntry.textTertiary)
//                }
//                .font(.system(size: 15, design: .monospaced))
//
//                Spacer(minLength: 12)
//
//                HStack(spacing: 7) {
//                    Image(systemName: "play.fill").font(.system(size: 10))
//                    Text("RUN")
//                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
//                        .tracking(1)
//                }
//                .foregroundStyle(Design.SheetEntry.background)
//                .padding(.horizontal, 14)
//                .padding(.vertical, 8)
//                .background(Design.SheetEntry.accent)
//                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
//            }
//        }
//    }
//
//    private func service(_ ref: Reference) -> some View {
//        let name = Service.with(ref, { $0.name }) ?? "Service"
//        let subtitle = Service.with(ref, { $0.entries.compactMap(\.rendered).joined(separator: " ") }) ?? ""
//
//        return EntryCard(icon: "powerplug", label: "Service") {
//            HStack(spacing: 14) {
//                Text(String(name.prefix(2)).uppercased())
//                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
//                    .foregroundStyle(Design.SheetEntry.textSecondary)
//                    .frame(width: 44, height: 44)
//                    .background(Design.SheetEntry.cardHeader)
//                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 10, style: .continuous)
//                            .strokeBorder(Design.SheetEntry.stroke, lineWidth: 1)
//                    )
//
//                VStack(alignment: .leading, spacing: 3) {
//                    Text(name)
//                        .font(.system(size: 18))
//                        .foregroundStyle(Design.SheetEntry.textPrimary)
//                    if !subtitle.isEmpty {
//                        Text(subtitle)
//                            .font(.system(size: 14, design: .monospaced))
//                            .foregroundStyle(Design.SheetEntry.textTertiary)
//                            .lineLimit(1)
//                    }
//                }
//
//                Spacer(minLength: 12)
//
//                StatusPill(label: "Connected")
//            }
//        }
//    }
//
//    private func file(_ ref: Reference) -> some View {
//        let name = Artifact.with(ref, { $0.name }) ?? "file"
//        let meta = Artifact.with(ref, { $0.content }) ?? ""
//
//        return EntryCard(icon: "doc.text", label: "File") {
//            HStack(spacing: 14) {
//                Image(systemName: "doc.richtext")
//                    .font(.system(size: 26, weight: .regular))
//                    .foregroundStyle(Design.SheetEntry.textSecondary)
//
//                VStack(alignment: .leading, spacing: 3) {
//                    Text(name)
//                        .font(.system(size: 18))
//                        .foregroundStyle(Design.SheetEntry.textPrimary)
//                    if !meta.isEmpty {
//                        Text(meta)
//                            .font(.system(size: 14, design: .monospaced))
//                            .foregroundStyle(Design.SheetEntry.textTertiary)
//                            .lineLimit(1)
//                    }
//                }
//
//                Spacer(minLength: 12)
//
//                GhostButton(label: "Open")
//            }
//        }
//    }
//
//    private func link(_ ref: Reference) -> some View {
//        let name = Artifact.with(ref, { $0.name }) ?? "Link"
//        let url = Artifact.with(ref, { $0.content }) ?? ""
//
//        return EntryCard(icon: "link", label: "Link") {
//            HStack(spacing: 14) {
//                Image(systemName: "link")
//                    .font(.system(size: 22, weight: .regular))
//                    .foregroundStyle(Design.SheetEntry.textSecondary)
//
//                VStack(alignment: .leading, spacing: 3) {
//                    Text(name)
//                        .font(.system(size: 18))
//                        .foregroundStyle(Design.SheetEntry.textPrimary)
//                    if !url.isEmpty {
//                        Text(url)
//                            .font(.system(size: 14, design: .monospaced))
//                            .foregroundStyle(Design.SheetEntry.accent)
//                            .lineLimit(1)
//                            .truncationMode(.middle)
//                    }
//                }
//
//                Spacer(minLength: 12)
//
//                Image(systemName: "arrow.up.right.square")
//                    .font(.system(size: 18))
//                    .foregroundStyle(Design.SheetEntry.textSecondary)
//            }
//        }
//    }
//
//    private func image(_ ref: Reference) -> some View {
//        let name = Artifact.with(ref, { $0.name }) ?? "image"
//
//        return EntryCard(icon: "photo", label: "Image") {
//            HStack(spacing: 14) {
//                Image(systemName: "photo")
//                    .font(.system(size: 26))
//                    .foregroundStyle(Design.SheetEntry.textSecondary)
//                Text(name)
//                    .font(.system(size: 18))
//                    .foregroundStyle(Design.SheetEntry.textPrimary)
//                Spacer(minLength: 12)
//                GhostButton(label: "View")
//            }
//        }
//    }
//
//    private func sheet(_ ref: Reference) -> some View {
//        let name = Sheet.with(ref, { $0.name }) ?? "Sheet"
//
//        return EntryCard(icon: "doc.on.doc", label: "Sheet") {
//            HStack(spacing: 14) {
//                Image(systemName: "doc.on.doc")
//                    .font(.system(size: 22))
//                    .foregroundStyle(Design.SheetEntry.textSecondary)
//                Text(name)
//                    .font(.system(size: 18))
//                    .foregroundStyle(Design.SheetEntry.textPrimary)
//                Spacer(minLength: 12)
//                GhostButton(label: "Open")
//            }
//        }
//    }
//
//    private func text(_ text: String) -> some View {
//        var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
//        var looksLikeBlock: Bool { text.contains("\n") && (trimmed.contains("- ") || trimmed.hasPrefix("##")) }
//        var isHeading: Bool { !trimmed.contains("\n") && trimmed.hasPrefix("#") }
//        var isQuote: Bool { trimmed.hasPrefix(">") }
//        var quotePrefix: String { ">" }
//
//        var attributed: AttributedString {
//            (try? AttributedString(
//                markdown: trimmed,
//                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
//            )) ?? AttributedString(trimmed)
//        }
//
//        func stripped(_ prefix: String) -> String {
//            var s = trimmed
//            while s.hasPrefix(prefix) || s.hasPrefix(" ") {
//                if s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
//                else { s.removeFirst() }
//            }
//            return s
//        }
//
//        return VStack {
//            if looksLikeBlock {
//                Text(text)
//                    .font(.system(size: 15, design: .monospaced))
//                    .foregroundStyle(Design.SheetEntry.textPrimary)
//                    .lineSpacing(8)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(18)
//                    .background(Design.SheetEntry.codeBlockBg)
//                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12, style: .continuous)
//                            .strokeBorder(Design.SheetEntry.accent.opacity(0.45), lineWidth: 1)
//                    )
//            } else if isQuote {
//                HStack(spacing: 0) {
//                    Rectangle()
//                        .fill(Design.SheetEntry.accent)
//                        .frame(width: 3)
//                    Text(stripped(quotePrefix))
//                        .font(.system(size: 18, weight: .regular))
//                        .italic()
//                        .foregroundStyle(Design.SheetEntry.textSecondary)
//                        .lineSpacing(6)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .padding(.leading, 18)
//                }
//            } else if isHeading {
//                Text(stripped("#"))
//                    .font(.system(size: 30, weight: .semibold))
//                    .foregroundStyle(Design.SheetEntry.textPrimary)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.top, 8)
//            } else {
//                Text(attributed)
//                    .font(.system(size: 17))
//                    .foregroundStyle(Design.SheetEntry.textPrimary)
//                    .lineSpacing(6)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//            }
//        }
//    }
//
//    private func todo(title: String, complete: Bool) -> some View {
//        EntryCard(icon: "checkmark.circle", label: "Task") {
//            HStack(spacing: 14) {
//                Image(systemName: complete ? "checkmark.circle.fill" : "circle")
//                    .font(.system(size: 20, weight: .regular))
//                    .foregroundStyle(complete ? Design.SheetEntry.accent : Design.SheetEntry.textTertiary)
//
//                Text(title)
//                    .font(.system(size: 17))
//                    .foregroundStyle(complete ? Design.SheetEntry.textTertiary : Design.SheetEntry.textPrimary)
//                    .strikethrough(complete, color: Design.SheetEntry.textTertiary)
//
//                Spacer(minLength: 12)
//            }
//        }
//    }
//
//
//    var body: some View {
//        switch entry {
//        case .artifact(let ref):
//            switch Artifact.with(ref, { $0.entry }) {
//            case .app, .http, .script, .skill: link(ref)
//            case .exec, .file: file(ref)
//            case .image: image(ref)
//            default: link(ref)
//            }
//        case .control(let ref): control(ref)
//        case .service(let ref): service(ref)
//        case .sheet(let ref): sheet(ref)
//        case .text(_, let text): SheetTextView(text: text)
//        case .todo(_, let title, let complete): todo(title: title, complete: complete)
//        }
//    }
//}

//struct SheetView: View {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some View {
//        if let sheet = agency.session.sheet {
//            ScrollView {
//                let entries = Sheet.with(sheet, { $0.entries }) ?? []
//
//                VStack(alignment: .leading, spacing: 22) {
//                    ForEach(entries) { entry in
//                        SheetEntryView(entry: entry)
//                    }
//                }
//            }
//        }
//    }
//}
