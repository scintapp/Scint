import Foundation


typealias CommandPath = [String]
typealias CommandHandler = (CommandContext) async throws -> String

protocol CommandAddon { var commands: [AgencyCommand] { get } }

enum CommandError: Error {
    case unknownCommand(String)
    case unsupportedArguments(String)
    case missingValue(flag: String)
    case invalidValue(flag: String, value: String, expected: String)
    case missingArgument(String)
    case notFound(String)
    case execution(String)
    case processExited(Int32)

    var rendered: String {
        switch self {
        case .unknownCommand(let name):
            return """
            Unknown command: \(name)
            Run `agency --help` to see available commands.
            """
        case .unsupportedArguments(let message):
            return message
        case .missingValue(let flag):
            return "Missing value for `--\(flag)`."
        case .invalidValue(let flag, let value, let expected):
            return "Invalid value for `--\(flag)`: `\(value)`. Expected \(expected)."
        case .missingArgument(let message):
            return message
        case .notFound(let message):
            return message
        case .execution(let message):
            return message
        case .processExited:
            return ""
        }
    }

    var exitCode: Int32 {
        switch self {
        case .processExited(let status): return status
        default: return EXIT_FAILURE
        }
    }
}

enum DocumentationBlock {
    case list(title: String, entries: [DocumentationEntry])
    case examples([String])
}

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
    let command: AgencyCommand
    let invocation: ParsedCommand
    let registry: CommandRegistry
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
