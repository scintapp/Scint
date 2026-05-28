import Foundation


struct CommandRenderer {
    func render(_ documentation: CommandDocumentation) -> String {
        var lines: [String] = [documentation.title]

        if !documentation.intro.isEmpty {
            lines.append("")
            lines.append(contentsOf: documentation.intro)
        }

        lines.append("")
        lines.append("USAGE")
        lines.append("  \(documentation.usage)")

        for block in documentation.blocks {
            lines.append("")

            switch block {
            case .list(let title, let entries):
                lines.append(title)
                lines.append(contentsOf: render(entries: entries))
            case .examples(let examples):
                lines.append("EXAMPLES")
                lines.append(contentsOf: examples.map { "  $ \($0)" })
            }
        }

        return lines.joined(separator: "\n")
    }

    func renderSearch(scope: CommandDocumentation, query: String, results: [DocumentationSearchResult]) -> String {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = [
            "\(scope.title) / SEARCH",
            "",
            "Matches for \"\(trimmedQuery)\""
        ]

        if results.isEmpty {
            lines.append("")
            lines.append("  No matches.")
            return lines.joined(separator: "\n")
        }

        for result in results {
            lines.append("")
            lines.append(result.title)
            for match in result.matches.prefix(3) {
                lines.append("  \(match)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func render(entries: [DocumentationEntry]) -> [String] {
        let width = entries.map { $0.term.count }.max() ?? 0

        return entries.map { entry in
            let padding = String(repeating: " ", count: max(1, width - entry.term.count + 2))
            return "  \(entry.term)\(padding)\(entry.description)"
        }
    }
}

struct CommandParser {
    let registry: CommandRegistry

    func parse(arguments: [String]) throws -> ParsedCommand {
        let (path, consumed) = try registry.resolvePath(from: arguments)
        let remainder = Array(arguments.dropFirst(consumed))
        let (positionals, options) = try parseRemainder(remainder)
        return ParsedCommand(path: path, positionals: positionals, options: options)
    }

    private func parseRemainder(_ arguments: [String]) throws -> ([String], CommandOptions) {
        var positionals: [String] = []
        var storage: [String: [String?]] = [:]
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]

            if argument.hasPrefix("--") {
                let stripped = String(argument.dropFirst(2))

                if let separatorIndex = stripped.firstIndex(of: "=") {
                    let name = String(stripped[..<separatorIndex])
                    let value = String(stripped[stripped.index(after: separatorIndex)...])
                    storage[name, default: []].append(value)
                } else if index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") {
                    storage[stripped, default: []].append(arguments[index + 1])
                    index += 1
                } else {
                    storage[stripped, default: []].append(nil)
                }
            } else { positionals.append(argument) }

            index += 1
        }

        return (positionals, CommandOptions(storage: storage))
    }
}
