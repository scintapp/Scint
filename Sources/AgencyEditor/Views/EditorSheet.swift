import AgencyRuntime
@preconcurrency import LinkPresentation
import SwiftUI


struct SelectableEntry<Content: View>: View {
    @Environment(\.editorFocus) private var focus
    let id: UUID
    let entry: Entry
    let isSelected: Bool
    let onFocusGained: () -> Void
    let onCommand: (Selector) -> Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : .clear)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1)
                EntryResponder(
                    id: id,
                    focus: focus,
                    onFocusGained: onFocusGained,
                    onCommand: onCommand
                )
            }

    }
}

struct EntryGlyph: View {
    let icon: String
    var tint: Color = .secondary
    var contained: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        Image(systemName: icon)
            .font(.system(size: 11))
            .foregroundStyle(tint)
            .frame(width: 21, height: 21, alignment: .center)
            .background {
                if contained { shape.fill(tint.opacity(0.15)) }
            }
            .overlay {
                if contained { shape.strokeBorder(tint.opacity(0.28), lineWidth: 1) }
            }
    }
}

struct EntryTextBlock: View {
    let title: String
    let detail: String?
    var design: Font.Design = .default
    var truncation: Text.TruncationMode = .tail

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .frame(height: detail == nil || detail == "" ? 28 : 14, alignment: .center)
                .font(.system(size: TypeScale.cardTitle, weight: .medium))
                .foregroundStyle(Design.SheetEntry.textPrimary)
                .lineLimit(1)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .frame(height: 14, alignment: .center)
                    .font(.system(size: TypeScale.cardMeta, design: design))
                    .foregroundStyle(Design.SheetEntry.textTertiary)
                    .lineLimit(1)
                    .truncationMode(truncation)
            }
        }
    }
}

struct EntryChip: View {
    let label: String
    var tint: Color = Design.SheetEntry.textTertiary
    var design: Font.Design = .default

    var body: some View {
        Text(label)
            .font(.system(size: 11, design: design))
            .foregroundStyle(tint.opacity(0.9))
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(tint.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(tint.opacity(0.16), lineWidth: 1))
    }
}

private struct LinkMetadata {
    var title: String
    var detail: String
}

struct LinkMetadataPreview: View {
    let url: URL
    let fallbackTitle: String

    @State private var metadata: LinkMetadata?

    private var host: String {
        url.host(percentEncoded: false) ?? url.absoluteString
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            EntryGlyph(icon: "bookmark", tint: Design.Tint.artifact, contained: true)
            
            EntryTextBlock(
                title: metadata?.title ?? fallbackTitle,
                detail: metadata?.detail ?? host,
                design: .default,
                truncation: .middle
            )

            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: 28, alignment: .leading)
        .task(id: url) { await load() }
    }

    private func load() async {
        guard metadata == nil else { return }
        let provider = LPMetadataProvider()
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return }
        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = metadata.url?.host(percentEncoded: false) ?? metadata.originalURL?.host(percentEncoded: false) ?? host
        self.metadata = .init(title: title?.isEmpty == false ? title! : fallbackTitle, detail: detail)
    }
}


struct EditorSheet: View {
    var entry: Sheet.Entry

    private func componentCard<Badges: View>(
        icon: String,
        tint: Color,
        title: String,
        detail: String?,
        action: GhostButton,
        @ViewBuilder badges: @escaping () -> Badges
    ) -> some View {
        EntryCard {
            HStack(alignment: .center, spacing: 8) {
                EntryGlyph(icon: icon, tint: tint, contained: true)

                HStack(alignment: .center) {
                    EntryTextBlock(title: title, detail: detail)
                        .frame(alignment: .leading)

                    Spacer()

                    HStack(alignment: .center) {
                        badges()
                        action
                    }
                    .frame(alignment: .trailing)
                }
            }
        }
    }


    private func componentCard(
        icon: String,
        tint: Color,
        title: String,
        detail: String?,
        action: GhostButton
    ) -> some View {
        EntryCard {
            HStack(alignment: .top, spacing: 8) {
                EntryGlyph(icon: icon, tint: tint, contained: true)
                EntryTextBlock(title: title, detail: detail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                action
            }
        }
    }

    private func firstPreview(_ entries: [Sheet.Entry]) -> String {
        entries.compactMap {
            switch $0 {
            case .content(_, let text): return text.trimmingCharacters(in: .whitespacesAndNewlines)
            case .task(_, let text, let done): return "[\(done ? "x" : " ")] \(text)"
            case .artifact(let ref): return Artifact.with(ref, { $0.name })
            case .control(let ref): return Command.with(ref, { $0.name })
            case .service(let ref): return Harness.with(ref, { $0.name })
            case .sheet(let ref): return Sheet.with(ref, { $0.name })
            }
        }
        .first(where: { !$0.isEmpty }) ?? ""
    }

    private func sheetFacts(_ entries: [Sheet.Entry]) -> [String] {
        let texts = entries.filter { if case .content = $0 { true } else { false } }.count
        let tasks = entries.filter { if case .task = $0 { true } else { false } }.count
        let done = entries.filter { if case .task(_, _, true) = $0 { true } else { false } }.count
        let artifacts = entries.filter { if case .artifact = $0 { true } else { false } }.count
        let interfaces = entries.filter {
            if case .control = $0 { true }
            else if case .service = $0 { true }
            else { false }
        }.count

        return [
            texts == 0 ? nil : "\(texts) note\(texts == 1 ? "" : "s")",
            tasks == 0 ? nil : "\(done)/\(tasks) tasks",
            artifacts == 0 ? nil : "\(artifacts) artifact\(artifacts == 1 ? "" : "s")",
            interfaces == 0 ? nil : "\(interfaces) interface\(interfaces == 1 ? "" : "s")"
        ].compactMap(\.self)
    }

    private func commandFacts(_ params: [Command.Parameter]) -> (artifacts: Int, arguments: [String]) {
        var artifacts = 0
        var arguments: [String] = []
        for param in params {
            switch param {
            case .artifact: artifacts += 1
            case .argument(let value): arguments.append(value)
            }
        }
        return (artifacts, arguments)
    }

    private func serviceFacts(_ params: [Harness.Parameter]) -> [String] {
        var controls = 0
        var artifacts = 0
        var arguments = 0
        for param in params {
            switch param {
            case .command: controls += 1
            case .artifact: artifacts += 1
            case .argument: arguments += 1
            }
        }
        return [
            controls == 0 ? nil : "\(controls) control\(controls == 1 ? "" : "s")",
            artifacts == 0 ? nil : "\(artifacts) artifact\(artifacts == 1 ? "" : "s")",
            arguments == 0 ? nil : "\(arguments) arg\(arguments == 1 ? "" : "s")"
        ].compactMap(\.self)
    }

    private func control(_ ref: Reference) -> some View {
        let name = Command.with(ref, { $0.name }) ?? "tool"
        let description = Command.with(ref, { $0.description }) ?? ""
        let exec = Command.with(ref, { $0.exec }) ?? ref
        let executable = Artifact.with(exec, { $0.kind.url?.lastPathComponent ?? $0.name }) ?? ""
        let facts = Command.with(ref, { commandFacts($0.parameters) }) ?? (
            artifacts: 0,
            arguments: []
        )
        let args = facts.arguments.joined(separator: " ")

        return componentCard(
            icon: Design.Component.icon(for: ref),
            tint: Design.Tint.control,
            title: name,
            detail: description.isEmpty ? executable : description,
            action: GhostButton(label: "Run", icon: "play.fill")
        ) {
            if facts.artifacts > 0 {
                EntryChip(label: "\(facts.artifacts) artifact\(facts.artifacts == 1 ? "" : "s")", tint: Design.Tint.control)
            }
            if !args.isEmpty {
                EntryChip(label: args, tint: Design.Tint.control, design: .monospaced)
            }
        }
    }

    private func service(_ ref: Reference) -> some View {
        let name = Harness.with(ref, { $0.name }) ?? "Harness"
        let description = Harness.with(ref, { $0.description }) ?? ""
        let main = Harness.with(ref, { $0.command }) ?? ref
        let mainName = Command.with(main, { $0.name }) ?? "Command"
        let facts = Harness.with(ref, { serviceFacts($0.parameters) }) ?? []

        return componentCard(
            icon: Design.Component.icon(for: ref),
            tint: Design.Tint.service,
            title: name,
            detail: description.isEmpty ? "Main: \(mainName)" : description,
            action: GhostButton(label: "Start", icon: "play.fill")
        ) {
            ForEach(Array(facts.prefix(3)).indices, id: \.self) { index in
                EntryChip(label: facts[index], tint: Design.Tint.service)
            }
        }
    }

    private func file(_ ref: Reference) -> some View {
        let name = Artifact.with(ref, { $0.name }) ?? "file"
        let meta = Artifact.with(ref, { $0.content }) ?? ""
        let isDirectory = Artifact.with(ref, { $0.kind.isDirectory }) ?? false
        let icon = isDirectory ? "folder" : "doc"

        return HStack(spacing: 8) {
            EntryGlyph(icon: icon, tint: Design.Tint.artifact, contained: true)
            EntryTextBlock(title: name, detail: meta, design: .default)
            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func link(_ ref: Reference) -> some View {
        let name = Artifact.with(ref, { $0.name }) ?? "Link"
        let url = Artifact.with(ref, { $0.content }) ?? ""

        return EntryCard {
            HStack(spacing: 10) {
                EntryGlyph(icon: Design.Component.icon(for: ref))
                EntryTextBlock(title: name, detail: url, design: .default, truncation: .middle)
                Spacer(minLength: 10)
                GhostButton(label: "Open", icon: "arrow.up.right")
            }
        }
    }

    private func webLink(_ ref: Reference) -> some View {
        let name = Artifact.with(ref, { $0.name }) ?? "Link"
        guard let url = Artifact.with(ref, { $0.kind.url }) ?? nil else { return AnyView(link(ref)) }
        return AnyView(LinkMetadataPreview(url: url, fallbackTitle: name))
    }

    private func image(_ ref: Reference) -> some View {
        let name = Artifact.with(ref, { $0.name }) ?? "image"

        return EntryCard {
            HStack(spacing: 8) {
                EntryGlyph(icon: Design.Component.icon(for: ref))
                EntryTextBlock(title: name, detail: nil)
                Spacer(minLength: 10)
                GhostButton(label: "View")
            }
        }
    }

    private func sheet(_ ref: Reference) -> some View {
        let name = Sheet.with(ref, { $0.name }) ?? "Sheet"
        let description = Sheet.with(ref, { $0.description }) ?? ""
        let entries = Sheet.with(ref, { $0.entries }) ?? []
        let facts = sheetFacts(entries)

        return componentCard(
            icon: Design.Component.icon(for: ref),
            tint: Design.Tint.sheet,
            title: name,
            detail: description.isEmpty ? firstPreview(entries) : description,
            action: GhostButton(label: "Open")
        ) {
            ForEach(Array(facts.prefix(3)).indices, id: \.self) { index in
                EntryChip(label: facts[index], tint: Design.Tint.sheet)
            }
        }
    }

    private func text(_ content: String) -> some View {
        var trimmed: String { content.trimmingCharacters(in: .whitespacesAndNewlines) }
        var looksLikeBlock: Bool { content.contains("\n") && (trimmed.contains("- ") || trimmed.hasPrefix("##")) }
        var isHeading: Bool { !trimmed.contains("\n") && trimmed.hasPrefix("#") }
        var isQuote: Bool { trimmed.hasPrefix(">") }
        var quotePrefix: String { ">" }

        var attributed: AttributedString {
            (try? AttributedString(
                markdown: trimmed,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )) ?? AttributedString(trimmed)
        }

        func stripped(_ prefix: String) -> String {
            var s = trimmed
            while s.hasPrefix(prefix) || s.hasPrefix(" ") {
                if s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
                else { s.removeFirst() }
            }
            return s
        }

        return VStack {
            if looksLikeBlock {
                Text(content)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Design.SheetEntry.textPrimary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Design.SheetEntry.codeBlockBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Design.SheetEntry.stroke, lineWidth: 1)
                    )
            } else if isQuote {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Design.SheetEntry.accent)
                        .frame(width: 3)
                    
                    Text(stripped(quotePrefix))
                        .font(.system(size: 13, weight: .regular))
                        .italic()
                        .foregroundStyle(Design.SheetEntry.textSecondary)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                }
            } else if isHeading {
                Text(stripped("#"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Design.SheetEntry.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(attributed)
                    .font(.system(size: 13))
                    .foregroundStyle(Design.SheetEntry.textPrimary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func todo(_ content: String, _ completed: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            EntryGlyph(icon: completed ? "checkmark.app" : "app", tint: Design.Tint.task, contained: true)

            Text(content)
                .font(.system(size: TypeScale.cardTitle, weight: .medium))
                .foregroundStyle(completed ? Design.SheetEntry.textTertiary : Design.SheetEntry.textPrimary)
                .strikethrough(completed, color: Design.SheetEntry.textTertiary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        switch entry {
        case .artifact(let ref):
            switch Artifact.with(ref, { $0.kind }) {
            case .http: webLink(ref)
            case .app, .script, .skill: link(ref)
            case .exec, .file: file(ref)
            case .image: image(ref)
            default: link(ref)
            }
        case .control(let ref): control(ref)
        case .service(let ref): service(ref)
        case .sheet(let ref): sheet(ref)
        case .content(_, let content): text(content)
        case .task(_, let content, let completed): todo(content, completed)
        }
    }
}
