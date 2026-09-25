import Foundation
import ScintRuntime


enum InterfaceTool: Tool {
    enum Interface { case command, harness }
    enum Verb: String, CaseIterable { case read, add, run }

    static let method = Method(
        name: "interface",
        title: "Interface",
        description: "Commands, harnesses, and artifacts. read resolves an interface link to its data. add makes an interface available in a space. run starts a command with arguments.",
        schema: .schema([
            "verb": .choice(Verb.self, "What to do."),
            "ref": .link("The interface to read, add, or run."),
            "space": .link("The space to add it to. Defaults to your space."),
            "arguments": ["type": "object", "description": "The command's arguments by parameter name, for run. Links become references."]
        ], required: ["verb", "ref"])
    )

    static func with(_ content: Reference) -> (any Functional)? {
        if let command = Command.with(content, { $0 }) { return command }
        if let harness = Harness.with(content, { $0 }) { return harness }
        return Artifact.with(content, { $0 })
    }

    static func update(_ content: Reference, in space: Reference) -> Reference? {
        Space.with(space) {
            $0.add(content)
            return content
        }
    }

    static func call(_ arguments: [String: Property], in space: Reference) async throws -> Property {
        let interface = try arguments.required("ref")
        guard let value = with(interface) else { throw ToolError(message: "ref must be an interface link.") }

        switch try arguments.choice("verb", Verb.self) {
            case .read:
                return .data(value)

            case .add:
                let target = try arguments.link("space") ?? space
                guard update(interface, in: target) != nil else { throw ToolError(message: "space must be a space link.") }
                return try StructureTool.read(target)

            case .run:
                func argument(_ property: Property) -> Value? {
                    switch property {
                        case .bool(let value): .bool(value)
                        case .integer(let value): .integer(value)
                        case .decimal(let value): .decimal(Decimal(value))
                        case .string(let text): Reference.Link.reference(in: text).map { .reference($0) } ?? .string(text)
                        case .array(let values): .sequence(values.compactMap(argument))
                        case .object(let fields): .collection(fields.compactMapValues(argument))
                        case .null: nil
                    }
                }
                let values = (arguments["arguments"]?.object ?? [:]).compactMapValues(argument)
                guard try Command.with(interface, { try $0.run(values) }) != nil
                else { throw ToolError(message: "ref must be a command link to run.") }
                return .data(value)
        }
    }
}
