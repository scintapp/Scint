
import LinkPresentationimport SwiftUI


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
        let shape = Design.Shape.block

        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 99, style: .continuous)
                .fill(Design.Tint.artifact.opacity(0.76))
                .frame(width: 3)

            Iconography.icon(for: Artifact.Handler.bookmark(url), size: 18)
                .frame(width: 28, height: 28)

            TextContent(
                title: metadata?.title ?? fallbackTitle,
                detail: metadata?.detail ?? host,
                design: .default,
                truncation: .middle
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 10)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64, alignment: .leading)
        .background(Design.Background.block.opacity(0.28))
        .clipShape(shape)
        .overlay { shape.strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75) }
        .task(id: url) { await load() }
    }
}

struct ArtifactBlock: View {
    let ref: Reference

    func file(_ ref: Reference) -> some View {
        let name = Artifact.with(ref, { $0.name }) ?? "file"
        let meta = Artifact.with(ref, { $0.rendered }) ?? ""
        let handle = Artifact.with(ref, { $0.handler }) ?? .file(nil)

        let shape = Design.Shape.block

        return HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 99, style: .continuous)
                .fill(Design.Tint.artifact.opacity(0.76))
                .frame(width: 3)

            Iconography.icon(for: handle, size: 18)
                .frame(width: 28, height: 28)
            TextContent(title: name, detail: meta, design: .default)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 10)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64, alignment: .leading)
        .background(Design.Background.block.opacity(0.28))
        .clipShape(shape)
        .overlay { shape.strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75) }
    }

    func link(_ ref: Reference) -> some View {
        let name = Artifact.with(ref, { $0.name }) ?? "Link"
        let handle = Artifact.with(ref, { $0.handler }) ?? .bookmark(nil)
        guard let url = Artifact.with(ref, { $0.handler.url }) ?? nil else {
            let shape = Design.Shape.block

            return AnyView(
                HStack(alignment: .center, spacing: 12) {
                    RoundedRectangle(cornerRadius: 99, style: .continuous)
                        .fill(Design.Tint.artifact.opacity(0.76))
                        .frame(width: 3)

                    Iconography.icon(for: handle, size: 18)
                        .frame(width: 28, height: 28)
                    TextContent(
                        title: name,
                        detail: Artifact.with(ref, { $0.rendered }) ?? "",
                        design: .default,
                        truncation: .middle
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 10)
                }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 42, alignment: .leading)
                    .background(Design.Background.block.opacity(0.28))
                    .clipShape(shape)
                    .overlay { shape.strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75) }
            )
        }
        return AnyView(LinkBlock(fallbackTitle: name, url: url))
    }

    var body: some View {
        switch Artifact.with(ref, { $0.handler }) {
            case .app, .script, .skill, .bookmark: link(ref)
            case .directory, .executable, .file: file(ref)
            default: link(ref)
        }
    }
}

struct TextBlock: View {
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
        .padding(.leading, 8)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SheetBlock: View {
    @Environment(\.editorFocus) private var focus
    @State private var isHovered = false
    let block: Sheet.Block
    let selection: NSRange?
    let isEditing: Bool
    let isSelected: Bool
    let onTextChange: (String, NSRange) -> Void
    let onSelectionChange: (NSRange) -> Void
    let onCaretRectChange: (CGRect) -> Void
    let onViewportRectChange: (CGRect) -> Void
    let onFocusGained: () -> Void
    let onEdit: () -> Void
    let onCommand: (Selector, NSRange, Int) -> Bool

    func firstPreview(_ entries: [Sheet.Block]) -> String {
        var snippets: [String] = []

        for entry in entries {
            switch entry {
                case .text(_, let text):
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
        let executable = Artifact.with(exec, { $0.handler.url?.lastPathComponent ?? $0.name }) ?? ""
        let facts = Command.with(ref, { commandFacts($0.parameters) })!
        let args = facts.args.joined(separator: " ")

        return HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 99, style: .continuous)
                .fill(Design.Tint.command.opacity(0.76))
                .frame(width: 3)

            Iconography.Icon(symbol: Iconography.Custom.dispatch.rawValue, tint: Design.Tint.command, sizing: 18)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Design.Foreground.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(description.isEmpty ? executable : description)
                    .font(.system(size: 12, weight: .medium, design: description.isEmpty ? .monospaced : .default))
                    .foregroundStyle(Design.Foreground.disabled)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 6) {
                if facts.artifacts > 0 {
                    Badge("\(facts.artifacts) artifact\(facts.artifacts == 1 ? "" : "s")", tint: Design.Tint.command, style: .neutral)
                }
                if !args.isEmpty {
                    Badge(args, tint: Design.Tint.command, style: .neutral, monospaced: true)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .contentShape(shape)
        .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64, alignment: .topLeading)
        .background(Design.Background.block.opacity(0.28))
        .clipShape(shape)
        .overlay { shape.strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75) }
    }

    func commandFacts(_ params: [Command.Parameter]) -> (artifacts: Int, args: [String]) {
        var artifacts = 0
        var arguments: [String] = []
        for param in params {
            switch param {
                case .argument(let name, _, _, _): arguments.append("<\(name)>")
                case .fixed(.reference(let ref)) where ref.type is Artifact.Type: artifacts += 1
                case .fixed(let value): arguments.append(contentsOf: value.rendered)
                case .requirement: break
            }
        }
        return (artifacts, arguments)
    }

    func sheet(_ ref: Reference) -> some View {
        let shape = Design.Shape.block
        let name = Sheet.with(ref, { $0.name }) ?? "Sheet"
        let description = Sheet.with(ref, { $0.description }) ?? ""
        let blocks = Sheet.with(ref, { $0.blocks }) ?? []
        let facts = sheetFacts(blocks)

        return HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 99, style: .continuous)
                .fill(Design.Tint.sheet.opacity(0.76))
                .frame(width: 3)

            Iconography.Icon(symbol: "text.alignleft", tint: Design.Tint.sheet, sizing: 18)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Design.Foreground.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(description.isEmpty ? firstPreview(blocks) : description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Design.Foreground.disabled)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 6) {
                ForEach(Array(facts.prefix(3)).indices, id: \.self) { index in
                    Badge(facts[index], tint: Design.Tint.sheet, style: .neutral)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .contentShape(shape)
        .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64, alignment: .topLeading)
        .background(Design.Background.block.opacity(0.28))
        .clipShape(shape)
        .overlay { shape.strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.75) }
    }

    func sheetFacts(_ entries: [Sheet.Block]) -> [String] {
        let texts = entries.filter { if case .text = $0 { true } else { false } }.count
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
        case .text(_, let content): TextBlock(content: content)
        case .sheet(let ref): sheet(ref)
        case .task(_, let content, let completed): TaskBlock(content: content, completed: completed)
        }
    }

    @ViewBuilder var body: some View {
        switch block {
            case .text(_, let text):
                EditorInput(
                    id: block.id,
                    text: text,
                    selection: selection,
                    isEditing: isEditing,
                    onTextChange: onTextChange,
                    onSelectionChange: onSelectionChange,
                    onCaretRectChange: onCaretRectChange,
                    onViewportRectChange: onViewportRectChange,
                    onFocusGained: onFocusGained,
                    onCommand: onCommand
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            default:
                content
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
                            id: block.id,
                            focus: focus,
                            onFocusGained: onFocusGained,
                            onEdit: onEdit,
                            onCommand: { onCommand($0, NSRange(location: 0, length: 0), 0) }
                        )
                    }
        }
    }
}
