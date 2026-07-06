import AgencyRuntime
import LinkPresentation
import SwiftUI


struct SelectableEntry<Content: View>: View {
    @Environment(\.editorFocus) private var focus
    @State private var isHovered = false
    let id: UUID
    let isSelected: Bool
    let onFocusGained: () -> Void
    let onCommand: (Selector) -> Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.primary.opacity(isSelected ? 0.04 : (isHovered ? 0.025 : 0)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(
                        isSelected ? Design.Tint.active.opacity(0.18) : (isHovered ? Color.primary.opacity(0.07) : .clear),
                        lineWidth: isSelected ? 0.8 : 0.6
                    )
            }
            .onHover { isHovered = $0 }
            .overlay {
                EntryResponder(
                    id: id,
                    focus: focus,
                    onFocusGained: onFocusGained,
                    onCommand: onCommand
                )
            }

    }
}

struct TextContent: View {
    let title: String
    let detail: String?
    var design: Font.Design = .default
    var truncation: Text.TruncationMode = .tail

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Design.Foreground.primary)
                .lineLimit(1)
                .truncationMode(truncation)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 12.5, weight: .regular, design: design))
                    .foregroundStyle(Design.Foreground.caption)
                    .lineLimit(1)
                    .truncationMode(truncation)
            }
        }
    }
}

struct LinkBlock: View {
    @State var metadata: Metadata?
    let fallbackTitle: String
    var host: String { url.host(percentEncoded: false) ?? url.absoluteString }
    let url: URL

    struct Metadata {
        var title: String
        var detail: String
    }

    func load() async {
        guard metadata == nil else { return }
        let provider = LPMetadataProvider()
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return }
        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = metadata.url?.host(percentEncoded: false) ?? metadata.originalURL?.host(percentEncoded: false) ?? host
        self.metadata = .init(title: title?.isEmpty == false ? title! : fallbackTitle, detail: detail)
    }

    var body: some View {
        HStack(alignment: .center) {
            Iconography.icon(for: Artifact.Handle.http(url), size: 16)
                .frame(width: 22, height: 22)

            TextContent(
                title: metadata?.title ?? fallbackTitle,
                detail: metadata?.detail ?? host,
                design: .default,
                truncation: .middle
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 10)
        }
        .padding(.leading, 16)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Design.Tint.artifact.opacity(0.72))
                .frame(width: 4)
                .padding(.vertical, 8)
        }
        .task(id: url) { await load() }
    }
}

struct ArtifactBlock: View {
    let ref: Reference

    func link(_ ref: Reference) -> some View {
        let name = Artifact.with(ref, { $0.name }) ?? "Link"
        let handle = Artifact.with(ref, { $0.handle }) ?? .http(nil)
        guard let url = Artifact.with(ref, { $0.handle.url }) ?? nil else {
            return AnyView(
                HStack(alignment: .center) {
                    Iconography.icon(for: handle, size: 16)
                        .frame(width: 22, height: 22)
                    TextContent(
                        title: name,
                        detail: Artifact.with(ref, { $0.rendered }) ?? "",
                        design: .default,
                        truncation: .middle
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 10)
                }
                    .padding(.leading, 16)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Design.Tint.artifact.opacity(0.72))
                            .frame(width: 4)
                            .padding(.vertical, 8)
                    }
            )
        }
        return AnyView(LinkBlock(fallbackTitle: name, url: url))
    }

    func file(_ ref: Reference) -> some View {
        let name = Artifact.with(ref, { $0.name }) ?? "file"
        let meta = Artifact.with(ref, { $0.rendered }) ?? ""
        let handle = Artifact.with(ref, { $0.handle }) ?? .file(nil)

        return HStack(alignment: .center) {
            Iconography.icon(for: handle, size: 16)
                .frame(width: 22, height: 22)
            TextContent(title: name, detail: meta, design: .default)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 10)
        }
        .padding(.leading, 16)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Design.Tint.artifact.opacity(0.72))
                .frame(width: 4)
                .padding(.vertical, 8)
        }
    }

    var body: some View {
        switch Artifact.with(ref, { $0.handle }) {
            case .app, .script, .skill, .http: link(ref)
            case .exec, .file: file(ref)
            default: link(ref)
        }
    }
}

struct ContentBlock: View {
    let content: String

    var body: some View {
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
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(Design.Foreground.primary)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.primary.opacity(0.055))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                } else if isQuote {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Design.Tint.info.opacity(0.55))
                            .frame(width: 3)

                        Text(stripped(quotePrefix))
                            .font(.system(size: 15, weight: .regular))
                            .italic()
                            .foregroundStyle(Design.Foreground.caption)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 12)
                    }
                } else if isHeading {
                    Text(stripped("#"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Design.Foreground.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(attributed)
                        .font(.system(size: 15.5))
                        .foregroundStyle(Design.Foreground.primary)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

struct TaskBlock: View {
    let content: String
    let completed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(completed ? Design.Foreground.caption.opacity(0.28) : Color.clear)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Design.Foreground.caption.opacity(completed ? 0.42 : 0.34), lineWidth: 1.25)
                    }

                if completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Design.Foreground.primary.opacity(0.82))
                }
            }
            .frame(width: 18, height: 18)
            .padding(.top, 1.5)

            Text(content)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(completed ? Design.Foreground.caption : Design.Foreground.primary)
                .strikethrough(completed, color: Design.Foreground.caption)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 18)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SheetBlock: View {
    let id: UUID
    var block: Block
    let isSelected: Bool
    let onFocusGained: () -> Void
    let onCommand: (Selector) -> Bool

    func firstPreview(_ entries: [Block]) -> String {
        var snippets: [String] = []

        for entry in entries {
            switch entry {
                case .content(_, let text):
                    let lines = text
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

                    for line in lines where !line.isEmpty {
                        var isHeading = false
                        for level in 1...6 {
                            if line.hasPrefix(String(repeating: "#", count: level) + " ") {
                                isHeading = true
                                break
                            }
                        }
                        if isHeading { continue }

                        var snippet = line
                        for prefix in ["> ", "- [ ] ", "- [x] ", "- [X] ", "- "] where snippet.hasPrefix(prefix) {
                            snippet.removeFirst(prefix.count)
                            break
                        }

                        let trimmed = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { snippets.append(trimmed) }
                        if snippets.count == 2 { return snippets.joined(separator: "\n") }
                    }
                case .task(_, let text, let done):
                    snippets.append("[\(done ? "x" : " ")] \(text)")
                case .artifact(let ref):
                    snippets.append(Artifact.with(ref, { $0.name }) ?? "")
                case .command(let ref):
                    snippets.append(Command.with(ref, { $0.name }) ?? "")
                case .sheet(let ref):
                    snippets.append(Sheet.with(ref, { $0.name }) ?? "")
            }

            snippets = snippets
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if snippets.count >= 2 { return snippets.prefix(2).joined(separator: "\n") }
        }
        return snippets.prefix(2).joined(separator: "\n")
    }

    func command(_ ref: Reference) -> some View {
        let shape = Design.Shape.block
        let name = Command.with(ref, { $0.name }) ?? "tool"
        let description = Command.with(ref, { $0.description }) ?? ""
        let exec = Command.with(ref, { $0.artifact }) ?? ref
        let executable = Artifact.with(exec, { $0.handle.url?.lastPathComponent ?? $0.name }) ?? ""
        let facts = Command.with(ref, { commandFacts($0.parameters) }) ?? (artifacts: 0, args: [], properties: [])
        let args = facts.args.joined(separator: " ")

        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Design.Foreground.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(description.isEmpty ? executable : description)
                    .font(.system(size: 14, weight: .regular, design: description.isEmpty ? .monospaced : .default))
                    .foregroundStyle(Design.Foreground.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 7) {
                if facts.artifacts > 0 {
                    Badge("\(facts.artifacts) artifact\(facts.artifacts == 1 ? "" : "s")", tint: Design.Tint.command)
                }
                if !args.isEmpty {
                    Badge(args, tint: Design.Tint.command, monospaced: true)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.leading, 40)
        .padding(.trailing, 20)
        .padding(.vertical, 16)
        .contentShape(shape)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            ZStack(alignment: .leading) {
                shape.fill(Design.Background.block.opacity(0.62))
                shape.fill(
                    LinearGradient(
                        colors: [Design.Tint.command.opacity(0.105), Design.Tint.command.opacity(0.015), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Design.Tint.command.opacity(0.86))
                .frame(width: 4)
                .padding(.vertical, 16)
        }
        .overlay { shape.strokeBorder(Design.Tint.command.opacity(0.24), lineWidth: 0.85) }
    }

    func commandFacts(_ params: [Command.Parameter]) -> (artifacts: Int, args: [String], properties: [Properties]) {
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

    func sheet(_ ref: Reference) -> some View {
        let shape = Design.Shape.block
        let name = Sheet.with(ref, { $0.name }) ?? "Sheet"
        let description = Sheet.with(ref, { $0.description }) ?? ""
        let blocks = Sheet.with(ref, { $0.blocks }) ?? []
        let facts = sheetFacts(blocks)

        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Design.Foreground.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(description.isEmpty ? firstPreview(blocks) : description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Design.Foreground.caption)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 7) {
                ForEach(Array(facts.prefix(3)).indices, id: \.self) { index in
                    Badge(facts[index], tint: Design.Tint.sheet)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.leading, 40)
        .padding(.trailing, 20)
        .padding(.vertical, 16)
        .contentShape(shape)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            ZStack(alignment: .leading) {
                shape.fill(Design.Background.block.opacity(0.62))
                shape.fill(
                    LinearGradient(
                        colors: [Design.Tint.sheet.opacity(0.105), Design.Tint.sheet.opacity(0.015), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Design.Tint.sheet.opacity(0.86))
                .frame(width: 4)
                .padding(.vertical, 16)
        }
        .overlay { shape.strokeBorder(Design.Tint.sheet.opacity(0.24), lineWidth: 0.85) }
        .padding(.vertical, 8)
    }

    func sheetFacts(_ entries: [Block]) -> [String] {
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

    @ViewBuilder var content: some View {
        switch block {
        case .artifact(let ref): ArtifactBlock(ref: ref)
        case .command(let ref): command(ref)
        case .content(_, let content): ContentBlock(content: content)
        case .sheet(let ref): sheet(ref)
        case .task(_, let content, let completed): TaskBlock(content: content, completed: completed)
        }
    }

    var body: some View {
        SelectableEntry(
            id: id,
            isSelected: isSelected,
            onFocusGained: onFocusGained,
            onCommand: onCommand
        ) {
            content
        }
    }
}
