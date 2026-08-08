import Foundation


enum Parser {
    static func parse(_ supplied: [String: Value], for ref: Reference) throws -> [String: Value] {
        if let command = Command.with(ref, { $0 }) {
            return try parse(supplied, command: command)
        }
        if let harness = Harness.with(ref, { $0 }) {
            return try parse(supplied, harness: harness, input: nil)
        }
        throw ParsingError.invalid("No functional object found for \(ref.id).")
    }

    static func parse(_ origin: Reference, transcript: Reference, for harness: Reference) throws -> [String: Value] {
        guard let harness = Harness.with(harness, { $0 }) else {
            throw RuntimeError.context(.missing(harness))
        }
        guard let closureRef = Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure }),
              let closure = Closure.with(closureRef, { $0 })
        else { throw RuntimeError.context(.missing(origin)) }

        var supplied: [String: Value] = [:]
        for parameter in harness.parameters {
            switch parameter {
                case .argument(let name, _, _, _), .requirement(let name, _, _), .target(let name, _, _):
                    supplied[name] = closure.config[name]
                case .command:
                    break
            }
        }

        let inputs = Transcript.with(transcript) { transcript in
            transcript.entries.compactMap { entry -> Reference? in
                guard case .scene(let ref, _) = entry else { return nil }
                return ref
            }
        } ?? []
        let rendered = inputs.compactMap { ref -> String? in
            guard let value = Scene.with(ref, { $0.rendered }), !value.isEmpty else { return nil }
            return "# \(ref.descriptor.name)\n\(value)"
        }
        let artifacts = Transcript.with(transcript, { $0.output("artifacts") }).flatMap { $0 }?.references ?? []
        let renderedArtifacts = artifacts.compactMap { ref -> String? in
            guard let value = Artifact.with(ref, { $0.rendered }), !value.isEmpty else { return nil }
            return "# \(ref.descriptor.name)\n\(value)"
        }
        let context = (renderedArtifacts + rendered).joined(separator: "\n\n")
        let input = context.isEmpty ? nil : Value.string(context)
        return try parse(supplied, harness: harness, input: input)
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

    private static func parse(_ supplied: [String: Value], harness: Harness, input: Value?) throws -> [String: Value] {
        var parsed: [String: Value] = [:]
        var expected: Set<String> = []
        var input = input

        for parameter in harness.parameters {
            switch parameter {
                case .argument(let name, let type, let required, let defaultValue):
                    expected.insert(name)
                    if let value = supplied[name] {
                        parsed[name] = try type.construct(value, name: name)
                    } else if required, let value = input {
                        parsed[name] = try type.construct(value, name: name)
                        input = nil
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
