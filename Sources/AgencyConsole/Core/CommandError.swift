import Foundation

enum CommandError: Error {
    case unknownCommand(String)
    case unsupportedArguments(String)
    case missingValue(flag: String)
    case invalidValue(flag: String, value: String, expected: String)
    case missingArgument(String)
    case notFound(String)
    case execution(String)

    var rendered: String {
        switch self {
        case .unknownCommand(let name):
            return """
            Unknown command: \(name)
            Run `agency --help` to see what this beast can actually do.
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
        }
    }
}
