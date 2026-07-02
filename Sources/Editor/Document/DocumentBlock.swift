import AgencyRuntime
import LinkPresentation
import SwiftUI


struct SelectableEntry<Content: View>: View {
    @Environment(\.editorFocus) private var focus
    let id: UUID
    let block: Block
    let isSelected: Bool
    let onFocusGained: () -> Void
    let onCommand: (Selector) -> Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
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
    let icon: Iconography.Icon
    var contained: Bool = false

    init(icon: Iconography.Icon, contained: Bool = false) {
        self.icon = icon
        self.contained = contained
    }

    init(icon: String, tint: Color = .secondary, contained: Bool = false) {
        self.icon = Iconography.Icon(symbol: icon, tint: tint, size: 17)
        self.contained = contained
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        Image(systemName: icon.symbol)
            .font(.system(size: 11))
            .foregroundStyle(icon.tint)
            .frame(width: 21, height: 21, alignment: .center)
            .background { if contained { shape.fill(icon.tint.opacity(0.15)) } }
            .overlay { if contained { shape.strokeBorder(icon.tint.opacity(0.28), lineWidth: 1) } }
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
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Design.Foreground.base)
                .lineLimit(1)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .frame(height: 14, alignment: .center)
                    .font(.system(size: 13))
                    .foregroundStyle(Design.Foreground.caption)
                    .lineLimit(1)
                    .truncationMode(truncation)
            }
        }
    }
}

struct EntryBadge: View {
    let label: String
    var tint: Color = Design.Tint.active
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
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(tint.opacity(0.17), lineWidth: 1))
    }
}

struct LinkMetadata {
    var title: String
    var detail: String
}

struct LinkMetadataPreview: View {
    @State private var metadata: LinkMetadata?
    let fallbackTitle: String
    var host: String { url.host(percentEncoded: false) ?? url.absoluteString }
    let url: URL

    private func load() async {
        guard metadata == nil else { return }
        let provider = LPMetadataProvider()
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return }
        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = metadata.url?.host(percentEncoded: false) ?? metadata.originalURL?.host(percentEncoded: false) ?? host
        self.metadata = .init(title: title?.isEmpty == false ? title! : fallbackTitle, detail: detail)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            EntryGlyph(icon: Iconography.Icon(symbol: "bookmark", tint: Design.Tint.artifact, size: 17), contained: true)

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
}

struct DocumentBlock: View {
    var block: Sheet.Block
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    func card<Badges: View>(ref: Reference, tint: Color, title: String, detail: String?, @ViewBuilder badges: @escaping () -> Badges) -> some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 8) {
                Iconography.icon(for: ref, size: 17)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 21, height: 21, alignment: .center)

                HStack(alignment: .center) {
                    EntryTextBlock(title: title, detail: detail)
                        .frame(alignment: .leading)
                    Spacer()
                    HStack(alignment: .center) {
                        badges()
                    }
                    .frame(alignment: .trailing)
                }
            }
        }
        .contentShape(shape)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background { shape.fill(Design.Background.block) }
        .overlay { shape.stroke(lineWidth: 1).fill(Design.Border.block) }
    }

    func card(ref: Reference, tint: Color, title: String, detail: String?) -> some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 8) {
                Iconography.icon(for: ref, size: 17)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 21, height: 21, alignment: .center)
                EntryTextBlock(title: title, detail: detail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(shape)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background { shape.fill(Design.Background.block) }
        .overlay { shape.stroke(lineWidth: 1).fill(Design.Border.block) }
    }

    private func firstPreview(_ entries: [Sheet.Block]) -> String {
        entries.compactMap {
            switch $0 {
                case .content(_, let text): return text.trimmingCharacters(in: .whitespacesAndNewlines)
                case .task(_, let text, let done): return "[\(done ? "x" : " ")] \(text)"
                case .artifact(let ref): return Artifact.with(ref, { $0.name }) ?? ""
                case .command(let ref): return Command.with(ref, { $0.name }) ?? ""
                case .sheet(let ref): return Sheet.with(ref, { $0.name })
            }
        }
        .first(where: { !$0.isEmpty }) ?? ""
    }

    private func command(_ ref: Reference) -> some View {
        let name = Command.with(ref, { $0.name }) ?? "tool"
        let description = Command.with(ref, { $0.description }) ?? ""
        let exec = Command.with(ref, { $0.artifact }) ?? ref
        let executable = Artifact.with(exec, { $0.handle.url?.lastPathComponent ?? $0.name }) ?? ""
        let facts = Command.with(ref, { commandFacts($0.parameters) }) ?? (artifacts: 0, args: [], properties: [])
        let args = facts.args.joined(separator: " ")

        return card(
            ref: ref,
            tint: Design.Tint.command,
            title: name,
            detail: description.isEmpty ? executable : description
        ) {
            if facts.artifacts > 0 {
                EntryBadge(label: "\(facts.artifacts) artifact\(facts.artifacts == 1 ? "" : "s")", tint: Design.Tint.command)
            }
            if !args.isEmpty {
                EntryBadge(label: args, tint: Design.Tint.command, design: .monospaced)
            }
        }
    }

    private func commandFacts(_ params: [Command.Parameter]) -> (artifacts: Int, args: [String], properties: [Properties]) {
        var artifacts = 0
        var arguments: [String] = []
        var properties: [Properties] = []
        for param in params {
            switch param {
                case .artifact: artifacts += 1
                case .argument(let value): arguments.append(value)
                case .properties(let props): properties.append(props)
                case .requirement: break
            }
        }
        return (artifacts, arguments, properties)
    }

    private func content(_ content: String) -> some View {
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
                    .foregroundStyle(Design.Foreground.base)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Design.Background.block)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Design.Border.block, lineWidth: 1)
                    )
            } else if isQuote {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Design.Background.block)
                        .frame(width: 3)

                    Text(stripped(quotePrefix))
                        .font(.system(size: 13, weight: .regular))
                        .italic()
                        .foregroundStyle(Design.Foreground.caption)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                }
            } else if isHeading {
                Text(stripped("#"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Design.Foreground.base)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(attributed)
                    .font(.system(size: 13))
                    .foregroundStyle(Design.Foreground.base)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func harness(_ ref: Reference) -> some View {
        let name = Harness.with(ref, { $0.name }) ?? "Harness"
        let description = Harness.with(ref, { $0.description }) ?? ""
        let main = Harness.with(ref, { $0.command }) ?? ref
        let mainName = Command.with(main, { $0.name }) ?? "Command"
        let facts = Harness.with(ref, { harnessFacts($0.parameters) }) ?? []

        return card(
            ref: ref,
            tint: Design.Tint.harness,
            title: name,
            detail: description.isEmpty ? "Main: \(mainName)" : description
        ) {
            ForEach(Array(facts.prefix(3)).indices, id: \.self) { index in
                EntryBadge(label: facts[index], tint: Design.Tint.harness)
            }
        }
    }

    private func harnessFacts(_ params: [Harness.Parameter]) -> [String] {
        var commands = 0
        var artifacts = 0
        var arguments = 0
        var properties = 0
        var sheets = 0
        var spaces = 0
        var transcripts = 0
        var workspaces = 0
        var requirements = 0

        func count(_ param: Harness.Parameter, required: Bool = false) {
            if required { requirements += 1 }
            switch param {
                case .argument:
                    arguments += 1
                case .properties: properties += 1
                case .content(let ref):
                    switch ref.type {
                        case is Sheet.Type: sheets += 1
                        case is Artifact.Type: artifacts += 1
                        case is Transcript.Type: transcripts += 1
                        default: break
                    }
                case .interface(let ref):
                    switch ref.type {
                        case is Command.Type: commands += 1
                        case is Artifact.Type: artifacts += 1
                        case is Harness.Type: commands += 1
                        default: break
                    }
                case .structure(let ref):
                    switch ref.type {
                        case is Space.Type: spaces += 1
                        case is Workspace.Type: workspaces += 1
                        default: break
                    }
                case .requirement(let nested):
                    count(nested, required: true)
            }
        }

        for param in params { count(param) }

        return [
            commands == 0 ? nil : "\(commands) command\(commands == 1 ? "" : "s")",
            artifacts == 0 ? nil : "\(artifacts) artifact\(artifacts == 1 ? "" : "s")",
            arguments == 0 ? nil : "\(arguments) arg\(arguments == 1 ? "" : "s")",
            properties == 0 ? nil : "\(properties) prop\(properties == 1 ? "" : "s")",
            sheets == 0 ? nil : "\(sheets) sheet\(sheets == 1 ? "" : "s")",
            spaces == 0 ? nil : "\(spaces) space\(spaces == 1 ? "" : "s")",
            transcripts == 0 ? nil : "\(transcripts) transcript\(transcripts == 1 ? "" : "s")",
            workspaces == 0 ? nil : "\(workspaces) workspace\(workspaces == 1 ? "" : "s")",
            requirements == 0 ? nil : "\(requirements) req\(requirements == 1 ? "" : "s")"
        ].compactMap(\.self)
    }

    private func file(_ ref: Reference) -> some View {
        let name = Artifact.with(ref, { $0.name }) ?? "file"
        let meta = Artifact.with(ref, { $0.rendered }) ?? ""
        let isDirectory = Artifact.with(ref, { $0.handle.directory }) ?? false
        let icon = isDirectory ? "folder" : "doc"

        return HStack(spacing: 8) {
            EntryGlyph(icon: Iconography.Icon(symbol: icon, tint: Design.Tint.artifact), contained: true)
            EntryTextBlock(title: name, detail: meta, design: .default)
            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func link(_ ref: Reference) -> some View {
        let name = Artifact.with(ref, { $0.name }) ?? "Link"
        guard let url = Artifact.with(ref, { $0.handle.url }) ?? nil else {
            return AnyView(
                VStack(alignment: .leading) {
                    HStack(spacing: 10) {
                        Iconography.icon(for: ref, size: 17)
                        EntryTextBlock(
                            title: name,
                            detail: Artifact.with(ref, { $0.rendered }) ?? "",
                            design: .default,
                            truncation: .middle
                        )
                        Spacer(minLength: 10)
                    }
                }
                .contentShape(shape)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background { shape.fill(Design.Background.block) }
                .overlay { shape.stroke(lineWidth: 1).fill(Design.Border.block) }
            )
        }
        return AnyView(LinkMetadataPreview(fallbackTitle: name, url: url))
    }

    private func image(_ ref: Reference) -> some View {
        let name = Artifact.with(ref, { $0.name }) ?? "image"

        return VStack(alignment: .leading) {
            HStack(spacing: 8) {
                Iconography.icon(for: ref, size: 17)
                EntryTextBlock(title: name, detail: nil)
                Spacer(minLength: 10)
            }
        }
        .contentShape(shape)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background { shape.fill(Design.Background.block) }
        .overlay { shape.stroke(lineWidth: 1).fill(Design.Border.block) }
    }

    private func sheet(_ ref: Reference) -> some View {
        let name = Sheet.with(ref, { $0.name }) ?? "Sheet"
        let description = Sheet.with(ref, { $0.description }) ?? ""
        let blocks = Sheet.with(ref, { $0.blocks }) ?? []
        let facts = sheetFacts(blocks)

        return card(
            ref: ref,
            tint: Design.Tint.sheet,
            title: name,
            detail: description.isEmpty ? firstPreview(blocks) : description
        ) {
            ForEach(Array(facts.prefix(3)).indices, id: \.self) { index in
                EntryBadge(label: facts[index], tint: Design.Tint.sheet)
            }
        }
    }

    private func sheetFacts(_ entries: [Sheet.Block]) -> [String] {
        let texts = entries.filter { if case .content = $0 { true } else { false } }.count
        let tasks = entries.filter { if case .task = $0 { true } else { false } }.count
        let done = entries.filter { if case .task(_, _, true) = $0 { true } else { false } }.count
        let artifacts = entries.filter { if case .artifact = $0 { true } else { false } }.count
        let interfaces = entries.filter { if case .command = $0 { true } else { false } }.count

        return [
            texts == 0 ? nil : "\(texts) note\(texts == 1 ? "" : "s")",
            tasks == 0 ? nil : "\(done)/\(tasks) tasks",
            artifacts == 0 ? nil : "\(artifacts) artifact\(artifacts == 1 ? "" : "s")",
            interfaces == 0 ? nil : "\(interfaces) interface\(interfaces == 1 ? "" : "s")"
        ].compactMap(\.self)
    }

    private func task(_ content: String, _ completed: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            EntryGlyph(icon: Iconography.icon(for: .task(UUID(), content, completed), size: 17), contained: true)

            Text(content)
                .foregroundStyle(completed ? Design.Foreground.caption : Design.Foreground.base)
                .strikethrough(completed, color: Design.Foreground.caption)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        switch block {
            case .artifact(let ref):
                switch Artifact.with(ref, { $0.handle }) {
                    case .app, .script, .skill, .http: link(ref)
                    case .exec, .file: file(ref)
                    case .image: image(ref)
                    default: link(ref)
                }
            case .command(let ref): command(ref)
            case .content(_, let text): content(text)
            case .sheet(let ref): sheet(ref)
            case .task(_, let text, let completed): task(text, completed)
        }
    }
}
