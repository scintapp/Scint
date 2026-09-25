import Foundation
import ScintRuntime


enum InterfaceTool: Tool {
    enum Interface { case command, harness }
    enum Verb: String, CaseIterable { case read, add }

    static let method = Method(
        name: "interface",
        title: "Interface",
        description: "Commands, harnesses, and artifacts. read resolves an interface link to its data. add makes an interface available in a space.",
        schema: .schema([
            "verb": .choice(Verb.self, "What to do."),
            "ref": .link("The interface to read or add."),
            "space": .link("The space to add it to. Defaults to your space.")
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
        }
    }
}
