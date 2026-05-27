import Foundation

typealias CommandPath = [String]
typealias CommandHandler = (CommandContext) async throws -> String

protocol CommandAddon { var commands: [AgencyCommand] { get } }

struct AgencyCommand {
    let path: CommandPath
    let documentation: CommandDocumentation
    let handler: CommandHandler?
}

struct CommandDocumentation {
    let path: CommandPath
    let title: String
    let intro: [String]
    let usage: String
    let blocks: [DocumentationBlock]
}

enum DocumentationBlock {
    case list(title: String, entries: [DocumentationEntry])
    case examples([String])
}

struct DocumentationEntry {
    let term: String
    let description: String
}

struct ParsedCommand {
    let path: CommandPath
    let positionals: [String]
    let options: CommandOptions
}

struct CommandContext {
    let registry: CommandRegistry
    let command: AgencyCommand
    let invocation: ParsedCommand
}

struct DocumentationSearchResult {
    let title: String
    let path: CommandPath
    let matches: [String]
}

struct CommandOptions {
    private let storage: [String: [String?]]
    init(storage: [String: [String?]] = [:]) { self.storage = storage }
    var isEmpty: Bool { storage.isEmpty }
    func has(_ name: String) -> Bool { storage[name] != nil }
    func value(for name: String) -> String? { storage[name]?.last ?? nil }
    func values(for name: String) -> [String] { (storage[name] ?? []).compactMap { $0 } }
}

extension CommandDocumentation {
    var searchableLines: [String] {
        var lines = [title]
        lines.append(contentsOf: intro)
        lines.append(usage)

        for block in blocks {
            switch block {
            case .list(let title, let entries):
                lines.append(title)
                lines.append(contentsOf: entries.map { "\($0.term) \($0.description)" })
            case .examples(let examples):
                lines.append(contentsOf: examples)
            }
        }
        return lines
    }
}
