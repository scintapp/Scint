import Foundation

struct CommandRunner {
    let registry: CommandRegistry
    private let renderer = Renderer()

    func run(arguments: [String]) async throws -> String {
        if arguments.isEmpty {
            return try renderDocumentation(for: [])
        }

        let parser = CommandParser(registry: registry)
        let parsed = try parser.parse(arguments: arguments)
        let command = try resolveCommand(parsed.path)

        if parsed.options.has("help") {
            return renderer.render(command.documentation)
        }

        if let query = parsed.options.value(for: "search"), command.handler == nil {
            return renderSearchResults(for: command.documentation, path: parsed.path, query: query)
        }

        if let handler = command.handler {
            return try await handler(CommandContext(registry: registry, command: command, invocation: parsed))
        }

        guard parsed.positionals.isEmpty, parsed.options.isEmpty else {
            let name = parsed.path.joined(separator: " ")
            throw CommandError.unsupportedArguments("`agency \(name)` does not accept those arguments yet.")
        }

        return renderer.render(command.documentation)
    }

    private func resolveCommand(_ path: CommandPath) throws -> AgencyCommand {
        guard let command = registry.command(for: path) else {
            throw CommandError.unknownCommand(path.joined(separator: " "))
        }

        return command
    }

    private func renderDocumentation(for path: CommandPath) throws -> String {
        renderer.render(try resolveCommand(path).documentation)
    }

    private func renderSearchResults(for documentation: CommandDocumentation, path: CommandPath, query: String) -> String {
        let results = registry.searchDocumentation(scope: path, query: query)
        return renderer.renderSearch(scope: documentation, query: query, results: results)
    }
}
