import SwiftUI
import ScintRuntime
import ScintComponents
import ScintServer


struct EntryTool: View {
    var record: Record

    enum Kind { case call, command, search }

    var name: String? { if case .string(let name)? = record.fields["name"] { name } else { nil } }
    var detail: String? { record.fields["arguments"]?.stringRepresentation }

    var arguments: [String: String] {
        guard case .object(let arguments)? = record.fields["arguments"] else { return [:] }
        return arguments.compactMapValues(\.string)
    }

    var kind: Kind {
        switch name {
            case "shell": .command
            case "search": .search
            default: .call
        }
    }

    var sentence: String? {
        guard let verb = arguments["verb"], let tool = name,
              ToolHandler.tools.contains(where: { $0.tool.name == tool })
                else { return nil }

        func named(_ link: String?) -> String? { link.flatMap { Reference.Link.resolve(in: $0) }.map { Card.text(for: $0).name } }

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
            Iconography.Icon(symbol: symbol, tint: Style.Foreground.muted, sizing: 12)
                .frame(width: Style.Dimension.icon)

            if let sentence { Text(sentence) }
            else if kind == .call { Text(name ?? "Called a tool") }
            else { Text(arguments["command"] ?? arguments["query"] ?? "").font(Typography.detail.monospaced()).truncationMode(.middle) }

            if sentence == nil, kind == .call, let detail {
                Text(detail)
                    .foregroundStyle(Style.Foreground.muted)
                    .truncationMode(.tail)
            }
        }
        .font(Typography.detail)
        .lineLimit(1)
        .foregroundStyle(Style.Foreground.muted)
    }
}
