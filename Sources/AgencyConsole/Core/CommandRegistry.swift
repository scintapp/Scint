import Foundation


struct CommandRegistry {
    private let commandsByPath: [String: AgencyCommand]
    private let documentedPaths: Set<String>

    init(addons: [CommandAddon]) {
        let commands = addons.flatMap(\.commands)
        self.commandsByPath = Dictionary(uniqueKeysWithValues: commands.map { (Self.key(for: $0.path), $0) })
        self.documentedPaths = Set(commands.map { Self.key(for: $0.path) })
    }

    func command(for path: CommandPath) -> AgencyCommand? { commandsByPath[Self.key(for: path)] }

    func hasExactPath(_ path: CommandPath) -> Bool { documentedPaths.contains(Self.key(for: path)) }

    func hasPathPrefix(_ path: CommandPath) -> Bool {
        let candidate = Self.key(for: path)
        return documentedPaths.contains(where: { key in
            key == candidate || key.hasPrefix(candidate + "/")
        })
    }

    func resolvePath(from arguments: [String]) throws -> (path: CommandPath, consumed: Int) {
        guard !arguments.isEmpty else {
            return ([], 0)
        }

        if arguments[0].hasPrefix("--") {
            return ([], 0)
        }

        var current: CommandPath = []
        var bestPath: CommandPath?
        var bestConsumed = 0

        for (index, argument) in arguments.enumerated() {
            if argument.hasPrefix("--") {
                break
            }

            let candidate = current + [argument]
            guard hasPathPrefix(candidate) else {
                break
            }

            current = candidate
            if hasExactPath(candidate) {
                bestPath = candidate
                bestConsumed = index + 1
            }
        }

        if let bestPath {
            return (bestPath, bestConsumed)
        }

        throw CommandError.unknownCommand(arguments[0])
    }

    func descendants(of path: CommandPath) -> [AgencyCommand] {
        let prefix = Self.key(for: path)

        return commandsByPath.values
            .filter { command in
                let key = Self.key(for: command.path)
                return path.isEmpty || key == prefix || key.hasPrefix(prefix + "/")
            }
            .sorted { lhs, rhs in
                let left = lhs.path.joined(separator: " ")
                let right = rhs.path.joined(separator: " ")
                return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
            }
    }

    func searchDocumentation(scope path: CommandPath, query: String) -> [DocumentationSearchResult] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }

        return descendants(of: path).compactMap { command in
            let matches = command.documentation.searchableLines.filter { $0.lowercased().contains(needle) }
            guard !matches.isEmpty else { return nil }
            return DocumentationSearchResult(title: command.documentation.title, path: command.path, matches: matches)
        }
    }

    private static func key(for path: CommandPath) -> String { path.joined(separator: "/") }
}
