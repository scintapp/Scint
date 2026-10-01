import SwiftUI
import ScintRuntime
import ScintComponents
import ScintServer


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
                return arguments.compactMapValues { if case .property(.string(let text)) = $0 { text } else { nil } }
            case .property(.string(let json))?:
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
            .padding(.vertical, 14)
            .background(Style.Shape.message.fill(Style.Background.bubble))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .frame(minWidth: 0, alignment: .trailing)
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
              ToolHandler.tools.contains(where: { $0.tool.name == tool })
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
        let object = named(arguments["ref"]) ?? arguments["name"] ?? noun(arguments["ref"]) ?? named(arguments["space"]) ?? "your space"
        if verb == "add", arguments["ref"] != nil, let space = named(arguments["space"]) { return "\(past) \(object) to \(space)" }
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
            Iconography.Icon(symbol: symbol, tint: failed ? Style.Tint.alert.bright : Style.Tint.neutral.bright, sizing: 12)
                .frame(width: Style.Dimension.icon)

            if let sentence { Text(sentence) }
            else if kind == .call { Text(name ?? "Called a tool") }
            else { Text(name ?? "").font(Typography.detail.monospaced()).truncationMode(.middle) }

            if sentence == nil, kind == .call, let detail {
                Text(detail)
                    .foregroundStyle(Style.Foreground.subtle)
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
            Iconography.Icon(symbol: "brain", tint: Style.Tint.neutral.bright, sizing: 12, selected: false)
                .frame(width: Style.Dimension.icon)

            Text(lines.indices.contains(index) ? lines[index] : "")
                .italic()
                .foregroundStyle(Style.Foreground.subtle)
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
                .foregroundStyle(Style.Foreground.subtle)
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
                            Iconography.Icon(symbol: first.symbol, tint: tools.contains(where: \.failed) ? Style.Tint.alert.bright : Style.Tint.neutral.bright, sizing: 12)
                                .frame(width: Style.Dimension.icon)
                            Text(summary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(Typography.footnote)
                                .foregroundStyle(Style.Foreground.subtle)
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
    var context: Context

    var body: some View {
        StatusDot(context.intent.forms.running, tint: Iconography.tint(for: context.intent), isActive: true, size: 6)
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
    var frame: CGFloat = 14
    @ViewBuilder var content: Content

    @State private var hovered = false

    var timestamp: some View {
        Text(created, style: .time)
            .font(Typography.footnote)
            .foregroundStyle(Style.Foreground.faint)
    }

    var buttons: some View {
        Image(systemName: "document.on.document")
            .font(.system(size: 11))
            .tint(Style.Foreground.faint)
            .foregroundStyle(Style.Foreground.faint, Style.Foreground.faint, Style.Foreground.faint)
    }

    var body: some View {
        VStack(alignment: trailing ? .trailing : .leading) {
            Color.clear.frame(height: frame)

            content
                .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)

            HStack(spacing: 8) {
                if trailing {
                    timestamp
                    buttons
                } else {
                    buttons
                    timestamp
                }
            }
            .frame(maxHeight: frame, alignment: .center)
            .padding(.horizontal, 8)
            .opacity(hovered ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
        .contentShape(Rectangle())
        .onHover { hovered in withAnimation(Style.Motion.disclosure) { self.hovered = hovered } }
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

                if record.origin.type == ScintRuntime.Space.self {
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

            case .event(.fail(let branch), _):
                guard let text = Transcript.with(branch, { $0.records.last?.value.rendered.joined(separator: " ") }) ?? nil, !text.isEmpty
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
