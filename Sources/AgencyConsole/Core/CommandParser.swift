import Foundation

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
