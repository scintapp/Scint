import AgencyRuntime
import SwiftUI


private struct ComposerStreamIcon: View {
    let symbol: String

    var body: some View {
        Iconography.Icon(symbol: symbol, tint: Design.Tint.inactive, sizing: 13, selected: false)
            .frame(width: 18, height: 18)
    }
}

private struct ComposerStreamItem: Identifiable {
    enum Kind {
        case status(symbol: String, title: String)
        case message(text: String, tint: Color)
    }

    let id: String
    let kind: Kind
    private static func commandTitle(from text: String) -> String {
        let first = text
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first, !first.isEmpty else { return "Ran command" }
        return "Ran \(first)"
    }

    @MainActor static func items(for process: AgencyRuntime.Process?) -> [Self] {
        guard let process else { return [] }
        return streamItems(in: process.transcript, prefix: process.transcript.id.uuidString)
    }

    @MainActor private static func streamItems(in transcript: Reference, prefix: String) -> [Self] {
        guard let entries = Transcript.with(transcript, { $0.entries }) else { return [] }
        return entries.flatMap { entry -> [Self] in
            switch entry {
                case .event(let event, let id, _):
                    return items(for: event, id: "\(prefix)-event-\(id.uuidString)")
                case .sheet(let ref, _):
                    let text = Sheet.with(ref, { $0.rendered.trimmingCharacters(in: .whitespacesAndNewlines) }) ?? ""
                    guard !text.isEmpty else { return [] }
                    return [.init(id: "\(prefix)-sheet-\(ref.id.uuidString)", kind: .message(text: text, tint: Design.Tint.request))]
                case .transcript(let ref, _, _):
                    return streamItems(in: ref, prefix: "\(prefix)-transcript-\(ref.id.uuidString)")
            }
        }
    }

    @MainActor private static func items(for event: RuntimeEvent, id: String) -> [Self] {
        if let response = event.response {
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            switch response.kind {
                case .command:
                    return [
                        .init(id: "\(id)-status", kind: .status(symbol: "terminal", title: commandTitle(from: text))),
                        .init(id: "\(id)-output", kind: .message(text: text, tint: Design.Tint.command))
                    ].filter { item in
                        if case .message(let value, _) = item.kind { return !value.isEmpty }
                        return true
                    }
                case .reasoning:
                    guard !text.isEmpty else { return [.init(id: id, kind: status(for: event))] }
                    return [.init(id: id, kind: .message(text: text, tint: Design.Tint.info))]
                default:
                    guard !text.isEmpty else { return [.init(id: id, kind: status(for: event))] }
                    return [.init(id: id, kind: .message(text: text, tint: Design.Tint.active))]
            }
        }

        return [.init(id: id, kind: status(for: event))]
    }

    @MainActor private static func status(for event: RuntimeEvent) -> Kind {
        switch event {
            case .request:
                return .status(symbol: "arrow.up.message", title: "Requested")
            case .composing:
                return .status(symbol: Iconography.Custom.compose.rawValue, title: "Composing")
            case .dispatching:
                return .status(symbol: Iconography.Custom.dispatch.rawValue, title: "Dispatching")
            case .observing:
                return .status(symbol: Iconography.Custom.observe.rawValue, title: "Observing")
            case .processing:
                return .status(symbol: Iconography.Custom.execute.rawValue, title: "Processing")
            case .traversing:
                return .status(symbol: Iconography.Custom.traverse.rawValue, title: "Traversing")
            case .updated:
                return .status(symbol: "arrow.triangle.2.circlepath", title: "Updated")
            case .blocked:
                return .status(symbol: Iconography.Custom.blocked.rawValue, title: "Blocked")
            case .completed:
                return .status(symbol: Iconography.Custom.completed.rawValue, title: "Completed")
            case .failed:
                return .status(symbol: Iconography.Custom.failed.rawValue, title: "Failed")
            case .properties:
                return .status(symbol: "curlybraces", title: "Received event")
        }
    }
}

private struct ComposerStreamRow: View {
    let item: ComposerStreamItem

    var body: some View {
        switch item.kind {
            case .status(let symbol, let title):
                HStack(spacing: 10) {
                    ComposerStreamIcon(symbol: symbol)
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Design.Foreground.quaternary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)

            case .message(let text, let tint):
                Text(Self.attributed(text))
                    .font(.system(size: 15.5, weight: .regular))
                    .foregroundStyle(Design.Foreground.primary)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 2)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(tint.opacity(0.48))
                            .frame(width: 2)
                            .padding(.vertical, 3)
                            .offset(x: -14)
                    }
        }
    }

    private static func attributed(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

struct Composer: Surface {
    @Environment(AgencyModel.self) var agency

    private var space: Reference { agency.session.selected.space ?? agency.session.workspace }
    private var process: AgencyRuntime.Process? { agency.context(space) }
    private var items: [ComposerStreamItem] { ComposerStreamItem.items(for: process) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(items) { item in
                        ComposerStreamRow(item: item)
                    }
                }
                .frame(maxWidth: 710, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 130)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            
            ComposerInput()
                .frame(maxWidth: 710, alignment: .bottom)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
    }
}
