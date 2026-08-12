import Foundation


enum Parser {
    static func parse(_ supplied: [String: Value], for ref: Reference) throws -> [String: Value] {
        if let command = Command.with(ref, { $0 }) {
            return try parse(supplied, command: command)
        }
        if let harness = Harness.with(ref, { $0 }) {
            return try parse(supplied, harness: harness)
        }
        throw ParsingError.invalid("No functional object found for \(ref.id).")
    }

    static func parse(_ origin: Reference, for harnessRef: Reference, prompt: String) throws -> [String] {
        guard let harness = Harness.with(harnessRef, { $0 }) else {
            throw RuntimeError.context(.missing(harnessRef))
        }
        guard let structure = Space.with(origin, { (config: $0.config, rendered: $0.rendered) })
                ?? Workspace.with(origin, { (config: $0.config, rendered: $0.rendered) })
        else { throw RuntimeError.context(.missing(origin)) }
        guard let command = Command.with(harness.command, { $0 }) else {
            throw RuntimeError.context(.missing(harness.command))
        }

        var harnessSupplied: [String: Value] = [:]
        for parameter in harness.parameters {
            switch parameter {
                case .argument(let name, _, _, _), .requirement(let name, _, _), .target(let name, _, _):
                    harnessSupplied[name] = name == "prompt" ? .string(prompt) : structure.config[name]
                case .command:
                    break
            }
        }

        var commandSupplied: [String: Value] = [:]
        for parameter in command.parameters {
            guard case .argument(let name, _, _, _) = parameter else { continue }
            commandSupplied[name] = structure.config[name]
        }

        let commandValues = try parse(commandSupplied, command: command)
        let harnessValues = try parse(harnessSupplied, harness: harness)
        return command.rendered(with: commandValues) + harness.rendered(with: harnessValues)
    }

    private static func parse(_ supplied: [String: Value], command: Command) throws -> [String: Value] {
        var parsed: [String: Value] = [:]
        var expected: Set<String> = []

        for parameter in command.parameters {
            guard case .argument(let name, let type, let required, let defaultValue) = parameter else { continue }
            expected.insert(name)
            if let value = supplied[name] {
                parsed[name] = try type.construct(value, name: name)
            } else if let defaultValue {
                parsed[name] = try type.construct(defaultValue, name: name)
            } else if required {
                throw ParsingError.missingArgument(name)
            }
        }

        let unexpected = supplied.keys.filter { !expected.contains($0) }.sorted()
        guard unexpected.isEmpty else { throw ParsingError.unexpectedArguments(unexpected) }
        return parsed
    }

    private static func parse(_ supplied: [String: Value], harness: Harness) throws -> [String: Value] {
        var parsed: [String: Value] = [:]
        var expected: Set<String> = []

        for parameter in harness.parameters {
            switch parameter {
                case .argument(let name, let type, let required, let defaultValue):
                    expected.insert(name)
                    if let value = supplied[name] {
                        parsed[name] = try type.construct(value, name: name)
                    } else if let defaultValue {
                        parsed[name] = try type.construct(defaultValue, name: name)
                    } else if required {
                        throw ParsingError.missingArgument(name)
                    }

                case .requirement(let name, let type, let value):
                    expected.insert(name)
                    parsed[name] = try type.construct(supplied[name] ?? value, name: name)

                case .target(let name, let type, let defaultValue):
                    expected.insert(name)
                    if let value = supplied[name] {
                        parsed[name] = try type.construct(value, name: name)
                    } else if let defaultValue {
                        parsed[name] = try type.construct(defaultValue, name: name)
                    }

                case .command:
                    break
            }
        }

        let unexpected = supplied.keys.filter { !expected.contains($0) }.sorted()
        guard unexpected.isEmpty else { throw ParsingError.unexpectedArguments(unexpected) }
        return parsed
    }
}
