import SwiftUI
import ScintRuntime
import ScintComponents


private extension Record {
    func field(_ name: String) -> String? {
        guard case .collection(let fields) = value, let value = fields[name] else { return nil }
        let text = value.rendered.joined(separator: " ")
        return text.isEmpty ? nil : text
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
    var status: String?

    var operation: Operation? { name.flatMap(Operation.named) }
    var label: String { operation?.sentence ?? "Called a tool" }
    var symbol: String? { operation?.symbol }
    var visibleStatus: String? { status == "completed" ? nil : status?.capitalized }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Style.Spacing.label) {
            Iconography.Icon(.tool(symbol), size: Style.Dimension.icon)

            Text(label)

            Spacer(minLength: 0)

            if let visibleStatus {
                Badge(label: visibleStatus, tint: Style.Foreground.secondary)
                    .fixedSize()
            }
        }
        .foregroundStyle(Style.Foreground.secondary)
    }
}

struct ReasoningEntry: View {
    var content: String

    var body: some View {
        TextBlock(content: content, reasoning: true)
    }
}

struct EventEntry: View {
    var cards: [Reference]
    var content: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Style.Spacing.label) {
            ForEach(cards) { ref in
                Card(ref: ref, style: .group)
            }

            if let content {
                TextBlock(content: content)
            }
        }
    }
}

struct EntryControls<Content: View>: View {
    @ViewBuilder var content: Content
    var trailing: Bool = true

    var body: some View {

        VStack {
            content
                .frame(maxWidth: .infinity, alignment: .trailing)
            HStack(spacing: 8) {
                Text("11:42")
                    .font(.footnote)
                Button { } label: {
                    Image(systemName: "document.on.document")
                }
                .buttonStyle(.accessoryBar)
                .tint(.clear)
                .foregroundStyle(
                    Style.Foreground.primary,
                    Style.Foreground.tertiary,
                    Style.Foreground.primary,
                )
            }
            .frame(alignment: trailing ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
    }
}

enum TranscriptEntry: View {
    case input(InputEntry)
    case output(OutputEntry)
    case tool(ToolEntry)
    case reasoning(ReasoningEntry)
    case event(EventEntry)

    init(_ entry: Transcript.Entry) {
        switch entry {
            case .record(let record, _):
                let input = record.value.rendered
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if record.origin.type == ScintRuntime.Document.self, !input.isEmpty {
                    self = .input(InputEntry(content: input))
                } else {
                    switch record.field("type") {
                        case "reasoning":
                            self = .reasoning(ReasoningEntry(content: record.field("text") ?? ""))

                        case "tool":
                            self = .tool(ToolEntry(name: record.field("name"), status: record.field("status")))

                        case .some:
                            self = .output(OutputEntry(content: record.field("text") ?? ""))

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

            case .event, .transcript, .space:
                self = .event(EventEntry(cards: [], content: nil))
        }
    }

    var body: some View {
        Group {
            switch self {
                case .input(let entry): EntryControls { entry }
                case .output(let entry): EntryControls { entry }
                case .tool(let entry): EntryControls { entry }
                case .reasoning(let entry): EntryControls { entry }
                case .event(let entry): EntryControls { entry }
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
            TranscriptEntry.input(InputEntry(content: "Make the transcript entries easier to modify."))
            TranscriptEntry.reasoning(ReasoningEntry(content: "I’ll separate entry classification from each entry’s presentation."))
            TranscriptEntry.tool(ToolEntry(name: "document__read", status: "completed"))
            TranscriptEntry.output(OutputEntry(content: "Each transcript type now has its own focused SwiftUI view."))
            TranscriptEntry.event(EventEntry(cards: [], content: "Transcript updated"))
        }
        .padding()
    }
    .frame(width: 680, height: 520)
    .background(Style.Background.canvas)
}
