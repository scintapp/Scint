import Foundation

struct Renderer {
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
            lines.append("  No matches. Either the docs are quiet or the query is cursed.")
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
