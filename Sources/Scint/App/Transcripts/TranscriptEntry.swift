import SwiftUI
import ScintRuntime
import ScintComponents


private extension Record {
    func field(_ name: String) -> String? {
        guard case .collection(let fields) = value, let value = fields[name] else { return nil }
        let text = value.rendered.joined(separator: " ")
        return text.isEmpty ? nil : text
    }

    var arguments: [String: String] {
        guard case .collection(let fields) = value else { return [:] }
        switch fields["arguments"] {
            case .collection(let arguments)?:
                return arguments.compactMapValues { if case .string(let text) = $0 { text } else { nil } }
            case .string(let json)?:
                let object = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
                return object?.compactMapValues { $0 as? String } ?? [:]
            default:
                return [:]
        }
    }
}

struct InputEntry: View {
    var content: String

    var body: some View {
        TextBlock(content: content, hugs: true)
            .foregroundStyle(Style.Foreground.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Style.Shape.panel.fill(Style.Background.group))
            .overlay(
                Style.Shape.panel
                    .strokeBorder(
                        Style.Border.panel.opacity(0.6),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black, radius: 3, y: 2)
            .frame(maxWidth: 400, alignment: .trailing)
    }
}

struct OutputEntry: View {
    var content: String

    var body: some View {
        TextBlock(content: content)
    }
}

struct ToolEntry: View {
    var name: String?
    var detail: String?
    var status: String?
    var kind: Kind = .call
    var arguments: [String: String] = [:]

    enum Kind { case call, command, search }

    var failed: Bool { status == "failed" }

    var sentence: String? {
        guard let verb = arguments["verb"], let tool = name?.components(separatedBy: "__").last,
              ContextProvider.tools.contains(where: { $0.tool.name == tool })
        else { return nil }

        func named(_ link: String?) -> String? { link.flatMap { Reference.Link.reference(in: $0) }.map { Card.text(for: $0).name } }
        func noun(_ link: String?) -> String? {
            guard let kind = link.flatMap({ URL(string: $0) })?.host, !kind.isEmpty else { return nil }
            return ("aeiou".contains(kind.prefix(1)) ? "an " : "a ") + kind
        }

        let past = switch verb {
            case "new": "Created"
            case "read": "Read"
            case "write": "Wrote to"
            case "add": "Added"
            case "remove": "Removed"
            case "start": "Started"
            case "stop": "Stopped"
            default: verb.capitalized
        }
        let object = named(arguments["link"]) ?? arguments["name"] ?? noun(arguments["link"]) ?? named(arguments["space"]) ?? "your space"
        if verb == "add", arguments["link"] != nil, let space = named(arguments["space"]) { return "\(past) \(object) to \(space)" }
        return "\(past) \(object)"
    }

    var symbol: String {
        switch kind {
            case .command: "terminal"
            case .search: "globe"
            case .call: "wrench.and.screwdriver"
        }
    }

    var phrase: (one: String, many: String) {
        if let sentence { return (sentence, sentence) }
        switch kind {
            case .command: return ("Ran a command", "Ran commands")
            case .search: return ("Searched the web", "Searched the web")
            case .call: return ("Used \(name ?? "a tool")", "Used \(name ?? "tools")")
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Iconography.Icon(symbol: symbol, tint: failed ? .alert : .neutral, size: 12)
                .frame(width: Style.Dimension.icon)

            if let sentence { Text(sentence) }
            else if kind == .call { Text(name ?? "Called a tool") }
            else { Text(name ?? "").font(Typography.detail.monospaced()).truncationMode(.middle) }

            if sentence == nil, kind == .call, let detail {
                Text(detail)
                    .foregroundStyle(Style.Foreground.tertiary)
                    .truncationMode(.tail)
            }
        }
        .font(Typography.detail)
        .lineLimit(1)
        .foregroundStyle(failed ? Style.Tint.alert.bright : Style.Foreground.secondary)
    }
}

struct ReasoningEntry: View {
    var thoughts: [String]
    @State private var offset = 0

    var lines: [String] {
        thoughts
            .flatMap { $0.replacingOccurrences(of: "**", with: "").components(separatedBy: .newlines) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        let lines = lines
        let index = max(0, lines.count - 1 - offset)

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Iconography.Icon(symbol: "brain", tint: .neutral, size: 12, selected: false)
                .frame(width: Style.Dimension.icon)

            Text(lines.indices.contains(index) ? lines[index] : "")
                .italic()
                .foregroundStyle(Style.Foreground.tertiary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(index)
                .transition(.opacity)

            if lines.count > 1 {
                HStack(spacing: 4) {
                    Button { offset += 1 } label: { Image(systemName: "chevron.left") }
                        .disabled(index == 0)
                    Text("\(index + 1)/\(lines.count)")
                        .monospacedDigit()
                    Button { offset -= 1 } label: { Image(systemName: "chevron.right") }
                        .disabled(offset == 0)
                }
                .buttonStyle(.borderless)
                .font(Typography.footnote)
                .foregroundStyle(Style.Foreground.tertiary)
                .fixedSize()
            }
        }
        .font(Typography.detail)
        .animation(Style.Motion.disclosure, value: index)
    }
}

struct ActivityEntry: View {
    var thoughts: [String] = []
    var tools: [ToolEntry] = []
    @State private var expanded = false

    var summary: String {
        var phrases: [(one: String, many: String, count: Int)] = []
        for tool in tools {
            if let index = phrases.firstIndex(where: { $0.one == tool.phrase.one }) { phrases[index].count += 1 }
            else { phrases.append((tool.phrase.one, tool.phrase.many, 1)) }
        }
        return phrases.enumerated().map { index, phrase in
            let text = phrase.count > 1 ? phrase.many : phrase.one
            return index == 0 ? text : text.prefix(1).lowercased() + text.dropFirst()
        }
        .joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Style.Spacing.page) {
            if !thoughts.isEmpty { ReasoningEntry(thoughts: thoughts) }

            if let first = tools.first {
                VStack(alignment: .leading, spacing: 10) {
                    Button { withAnimation(Style.Motion.disclosure) { expanded.toggle() } } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Iconography.Icon(symbol: first.symbol, tint: tools.contains(where: \.failed) ? .alert : .neutral, size: 12)
                                .frame(width: Style.Dimension.icon)
                            Text(summary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(Typography.footnote)
                                .foregroundStyle(Style.Foreground.tertiary)
                                .rotationEffect(.degrees(expanded ? 90 : 0))
                        }
                        .font(Typography.detail)
                        .foregroundStyle(Style.Foreground.secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if expanded {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(tools.enumerated()), id: \.offset) { _, tool in tool }
                        }
                        .padding(.leading, Style.Dimension.icon + 8)
                        .transition(.opacity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NoticeEntry: View {
    var content: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Style.Border.hairline)
                .frame(height: Style.Border.width)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(Style.Tint.alert.bright)
                Text(content)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .font(Typography.detail)
            .foregroundStyle(Style.Foreground.secondary)
            .layoutPriority(1)
            Rectangle()
                .fill(Style.Border.hairline)
                .frame(height: Style.Border.width)
        }
    }
}

struct WorkingEntry: View {
    var context: Composition

    var body: some View {
        StatusDot(context.intent.forms.running, tint: Iconography.iconography(context.intent).tint, isActive: true, size: 6)
            .font(Typography.detail)
            .foregroundStyle(Style.Foreground.secondary)
            .padding(.leading, (Style.Dimension.icon - 6) / 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EventEntry: View {
    var cards: [Reference]
    var content: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(cards) { ref in
                Card(ref: ref, style: .group)
            }
            if let content { TextBlock(content: content) }
        }
    }
}

struct EntryControls<Content: View>: View {
    var created: Date
    var trailing: Bool = true
    @ViewBuilder var content: Content
    @State private var hovered = false

    var body: some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 4) {
            content
                .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
            HStack(spacing: 8) {
                Text(created, style: .time)
                    .font(Typography.footnote)
                    .foregroundStyle(Color(red: 0.19608, green: 0.2, blue: 0.2))
                Button { } label: {
                    Image(systemName: "document.on.document")
                        .foregroundStyle(Color(red: 0.19608, green: 0.2, blue: 0.2))
                }
                .buttonStyle(.accessoryBar)
                .tint(Color(red: 0.19608, green: 0.2, blue: 0.2))
                .foregroundStyle(
                    Color(red: 0.19608, green: 0.2, blue: 0.2),
                    Color(red: 0.19608, green: 0.2, blue: 0.2),
                    Color(red: 0.19608, green: 0.2, blue: 0.2),
                )
            }
            .frame(height: 20)
            .opacity(hovered ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
        .contentShape(Rectangle())
        .onHover { hovered in withAnimation(Style.Motion.disclosure) { self.hovered = hovered } }
        .padding(.bottom, -24)
    }
}

enum TranscriptEntry: View {
    case input(InputEntry, Date)
    case output(OutputEntry, Date)
    case activity(ActivityEntry)
    case notice(NoticeEntry)
    case event(EventEntry)

    init?(_ entry: Transcript.Entry) {
        switch entry {
            case .record(let record, let created):
                let input = record.value.rendered
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if record.origin.type == ScintRuntime.Document.self {
                    guard !input.isEmpty else { return nil }
                    self = .input(InputEntry(content: input), created)
                } else {
                    switch record.field("type") {
                        case "reasoning":
                            guard let text = record.field("text") else { return nil }
                            self = .activity(ActivityEntry(thoughts: [text]))

                        case "tool":
                            let arguments = record.field("arguments"), status = record.field("status")
                            let kind: ToolEntry.Kind = arguments != nil || record.field("server") != nil ? .call : status != nil ? .command : .search
                            self = .activity(ActivityEntry(tools: [ToolEntry(name: record.field("name"), detail: arguments, status: status, kind: kind, arguments: record.arguments)]))

                        case "error":
                            self = .notice(NoticeEntry(content: record.field("text") ?? "Something went wrong"))

                        case .some:
                            guard let text = record.field("text") else { return nil }
                            self = .output(OutputEntry(content: text), created)

                        case .none:
                            var cards: [Reference] = []
                            if record.origin.type == Command.self || record.origin.type == Artifact.self {
                                cards.append(record.origin)
                            }

                            if case .reference(let ref) = record.value {
                                cards.append(ref)
                                self = .event(EventEntry(cards: cards, content: nil))
                            } else {
                                self = .event(EventEntry(cards: cards, content: record.value.rendered.joined(separator: "\n")))
                            }
                    }
                }

            case .event(.failed(let value), _):
                guard case .collection(let fields) = value, let text = fields["text"]?.rendered.joined(separator: " ")
                else { self = .notice(NoticeEntry(content: "Stopped with an error")); return }
                self = .notice(NoticeEntry(content: text))

            case .event, .transcript, .space:
                return nil
        }
    }

    var body: some View {
        Group {
            switch self {
                case .input(let entry, let created): EntryControls(created: created) { entry }
                case .output(let entry, let created): EntryControls(created: created, trailing: false) { entry }
                case .activity(let entry): entry
                case .notice(let entry): entry
                case .event(let entry): entry
            }
        }
        .font(Typography.body)
        .foregroundStyle(Style.Foreground.primary)
        .lineSpacing(Typography.Prose.lineSpacing)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentShape(Rectangle())
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Style.Spacing.entry) {
            TranscriptEntry.notice(NoticeEntry(content: "Stopped with an error"))
            TranscriptEntry.input(InputEntry(content: "What tools do you have access to?"), .now)
            TranscriptEntry.activity(ActivityEntry(
                thoughts: [
                    "**Listing accessible tools excluding Scint MCP**",
                    "**Inspecting tool registry using openai-docs skill**"
                ],
                tools: [
                    ToolEntry(name: "document__read", status: "completed"),
                    ToolEntry(name: "/bin/zsh -lc \"sed -n '1,240p' SKILL.md\"", status: "completed", kind: .command),
                    ToolEntry(name: "rg -n Transcript Sources", status: "completed", kind: .command),
                    ToolEntry(name: "site:developers.openai.com Codex tools", kind: .search)
                ]
            ))
            TranscriptEntry.output(OutputEntry(content: "**Use any of these now:** Scint, local code/files, web research.\n\n1. **Scint — current `Engineering` space**\n   - Inspect the structure of a space.\n   - Read Scint documents as structured content.\n2. **Local code, files, and execution**"), .now)
        }
        .padding()
    }
    .frame(width: 680, height: 620)
    .background(Style.Background.canvas)
}
