import Foundation
import ScintRuntime


enum StructureTool: Tool {
    enum Verb: String, CaseIterable { case new, read, add, remove }

    static let method = Method(
        name: "structure",
        title: "Structure",
        description: "Spaces. new creates a space. read returns a space's summary: its name, description, harness, child spaces, bridges, interfaces, and content, each with its ref. add puts a document, transcript, interface, or space into a space, and a space moves under its new parent. remove deletes what ref points at.",
        schema: .schema([
            "verb": .choice(Verb.self, "What to do."),
            "ref": .link("What to read, add, or remove."),
            "space": .link("The parent of a new space, or the space to add to. Defaults to your space."),
            "name": ["type": "string", "description": "The new space's name."]
        ], required: ["verb"])
    )

    static func new(_ name: String, in parent: Reference) -> Reference {
        Space.new(parent, name: name)
    }

    static func with(_ content: Reference) -> (any Structural)? {
        if let space = Space.with(content, { $0 }) { return space }
        return Bridge.with(content, { $0 })
    }

    static func update(_ content: Reference, in space: Reference) -> Reference? {
        Space.with(space) {
            $0.add(content)
            return content
        }
    }

    static func remove(_ content: Reference) async throws {
        await Runtime.shared.remove(content)
    }

    static func summary(_ space: Space) -> Property {
        func fields(_ ref: Reference) -> [String: Property] {
            var fields: [String: Property] = ["name": .string(ref.descriptor.name), "ref": .link(ref)]
            let description = ref.descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if !description.isEmpty { fields["description"] = .string(description) }
            return fields
        }
        func entries(_ refs: [Reference]) -> Property {
            .array(refs.sorted { $0.descriptor.name < $1.descriptor.name }.map { Property.object(fields($0)) })
        }

        var summary = fields(space.ref)
        summary["harness"] = space.harness.map { Property.object(fields($0)) } ?? .null
        summary["spaces"] = entries(Array(space.spaces))
        summary["bridges"] = entries(Array(space.bridges))
        summary["interfaces"] = entries(space.harnesses + space.commands + space.artifacts)
        summary["content"] = entries(space.documents.filter(\.descriptor.published))
        return .object(summary)
    }

    static func read(_ content: Reference) throws -> Property {
        guard let value = with(content) else { throw ToolError(message: "ref must be a space or bridge link.") }
        if let space = value as? Space { return summary(space) }
        return .data(value)
    }

    static func call(_ arguments: [String: Property], in space: Reference) async throws -> Property {
        switch try arguments.choice("verb", Verb.self) {
            case .new:
                let parent = try arguments.link("space") ?? space
                guard Space.with(parent, { $0 }) != nil else { throw ToolError(message: "space must be a space link.") }
                return try read(new(arguments.text("name"), in: parent))

            case .read:
                return try read(arguments.required("ref"))

            case .add:
                let content = try arguments.required("ref")
                let target = try arguments.link("space") ?? space
                guard update(content, in: target) != nil else { throw ToolError(message: "space must be a space link.") }
                return try read(target)

            case .remove:
                let content = try arguments.required("ref")
                try await remove(content)
                return ["removed": .link(content)]
        }
    }
}
