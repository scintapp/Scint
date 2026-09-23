import Foundation
import ScintRuntime


struct ToolError: Error {
    let message: String
}

struct Tool {
    let name: String
    let title: String
    let description: String
    let inputSchema: Property

    var definition: Property {
        [
            "name": .string(name),
            "title": .string(title),
            "description": .string(description),
            "inputSchema": inputSchema
        ]
    }
}

extension Property {
    static func link(_ description: String) -> Property {
        ["type": "string", "format": "uri", "description": .string("\(description) A scint:// link.")]
    }

    static func choice<Choice: RawRepresentable & CaseIterable>(_ type: Choice.Type, _ description: String) -> Property where Choice.RawValue == String {
        ["type": "string", "enum": .array(type.allCases.map { Property.string($0.rawValue) }), "description": .string(description)]
    }

    static func link(_ ref: Reference) -> Property {
        .string(Reference.Link.url(for: ref)?.absoluteString ?? ref.descriptorId.uuidString.lowercased())
    }

    static func data<Value: Codable>(_ value: Value) -> Property {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value), let property = try? JSONDecoder().decode(Property.self, from: data) else { return .null }
        return property.linked
    }

    var linked: Property {
        switch self {
            case .array(let values): return .array(values.map(\.linked))
            case .object(let fields):
                guard Set(fields.keys) == ["id", "typeId", "contextId", "descriptorId", "storageId"],
                      let data = try? JSONEncoder().encode(self),
                      let ref = try? JSONDecoder().decode(Reference.self, from: data)
                else { return .object(fields.mapValues(\.linked)) }
                return .link(ref)
            default: return self
        }
    }

    var resolved: Property {
        switch self {
            case .array(let values): return .array(values.map(\.resolved))
            case .object(let fields): return .object(fields.mapValues(\.resolved))
            case .string(let text): return Reference.Link.reference(in: text).map { Property.fromCodable($0) } ?? self
            default: return self
        }
    }
}

extension Dictionary where Key == String, Value == Property {
    func link(_ name: String) throws -> Reference? {
        guard let value = self[name] else { return nil }
        guard let text = value.string, let ref = Reference.Link.reference(in: text)
        else { throw ToolError(message: "\(name) must be a scint:// link.") }
        return ref
    }

    func required(_ name: String) throws -> Reference {
        guard let ref = try link(name) else { throw ToolError(message: "\(name) is required.") }
        return ref
    }

    func text(_ name: String) throws -> String {
        guard let text = self[name]?.string, !text.isEmpty else { throw ToolError(message: "\(name) is required.") }
        return text
    }

    func choice<Choice: RawRepresentable & CaseIterable>(_ name: String, _ type: Choice.Type) throws -> Choice where Choice.RawValue == String {
        guard let value = self[name]?.string, let choice = Choice(rawValue: value)
        else { throw ToolError(message: "\(name) must be one of: \(type.allCases.map(\.rawValue).joined(separator: ", ")).") }
        return choice
    }
}

@MainActor protocol ContextTool {
    static var tool: Tool { get }
    static func call(_ arguments: [String: Property], in space: Reference) async throws -> Property
}

enum ContentTool: ContextTool {
    enum Content: String, CaseIterable { case document, transcript }
    enum Verb: String, CaseIterable { case new, read, write }

    static let blockSchema: Property = [
        "type": "object",
        "description": "One block keyed by its kind, in the shape read returns: {\"text\": {\"text\": \"…\"}}, {\"task\": {\"text\": \"…\", \"done\": false, \"when\": {\"moment\": \"2026-09-30T09:00:00Z\", \"repeats\": \"never\"}}}, or {\"document\": \"scint://…\"}, and likewise artifact and command. A task's when is optional; repeats is never, hourly, daily, or weekly. Keep a block's id to replace it in place; leave the id out of a new block."
    ]

    static let tool = Tool(
        name: "content",
        title: "Content",
        description: "Documents and transcripts. new creates a document in a space. read resolves a document or transcript link to its data. write appends a block to a document, or replaces the block at index.",
        inputSchema: .schema([
            "verb": .choice(Verb.self, "What to do."),
            "subject": .choice(Content.self, "What the content is. Transcripts can only be read. Defaults to document."),
            "link": .link("The document or transcript to read or write."),
            "space": .link("The space a new document goes in. Defaults to your space."),
            "name": ["type": "string", "description": "The new document's name."],
            "blocks": ["type": "array", "items": blockSchema, "description": "The new document's blocks."],
            "block": blockSchema,
            "index": ["type": "integer", "minimum": .integer(0), "description": "The position of the block to replace. Leave it out to append."]
        ], required: ["verb"])
    )

    static func new(_ name: String, _ blocks: [Document.Block], in space: Reference) -> Reference {
        let document = Document.new(space, name: name)
        Document.update(document) { $0.insert(blocks, at: nil) }
        return document
    }

    static func with(_ content: Reference) -> (any Material)? {
        if let document = Document.with(content, { $0 }) { return document }
        return Transcript.with(content, { $0 })
    }

    static func update(_ document: Reference, with block: Document.Block, at index: Int?) -> Reference? {
        Document.update(document) { value in
            if let index { value.update(block, at: index) }
            else { value.insert(block, at: nil) }
            return document
        }
    }

    static func read(_ content: Reference) throws -> Property {
        guard let value = with(content) else { throw ToolError(message: "link must be a document or transcript link.") }
        return .data(value)
    }

    static func block(_ value: Property?) throws -> Document.Block {
        guard case .object(var fields)? = value?.resolved, fields.count == 1, let kind = fields.keys.first
        else { throw ToolError(message: "A block is one object keyed by its kind: text, task, document, artifact, or command.") }
        if case .object(var body)? = fields[kind] {
            if body["id"] == nil { body["id"] = .string(UUID().uuidString) }
            if kind == "task", body["done"] == nil { body["done"] = .bool(false) }
            fields[kind] = .object(body)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? JSONEncoder().encode(Property.object(fields)),
              let block = try? decoder.decode(Document.Block.self, from: data)
        else { throw ToolError(message: "That \(kind) block isn't in the shape read returns.") }
        return block
    }

    static func call(_ arguments: [String: Property], in space: Reference) async throws -> Property {
        let subject = try arguments["subject"] == nil ? Content.document : arguments.choice("subject", Content.self)

        switch try arguments.choice("verb", Verb.self) {
            case .new:
                guard subject == .document else { throw ToolError(message: "Only documents can be created.") }
                let target = try arguments.link("space") ?? space
                guard Space.with(target, { $0 }) != nil else { throw ToolError(message: "space must be a space link.") }
                let blocks = try (arguments["blocks"]?.array ?? []).map { try block($0) }
                return try read(new(arguments.text("name"), blocks, in: target))

            case .read:
                return try read(arguments.required("link"))

            case .write:
                guard subject == .document else { throw ToolError(message: "Transcripts can only be read.") }
                let document = try arguments.required("link")
                guard let blocks = Document.with(document, { $0.blocks }) else { throw ToolError(message: "link must be a document link.") }
                let written = try block(arguments["block"])
                let index = arguments["index"]?.int
                if let index, !blocks.indices.contains(index) {
                    throw ToolError(message: "index \(index) is out of range; the document has \(blocks.count) blocks.")
                }
                if index == nil, blocks.contains(where: { $0.id == written.id }) {
                    throw ToolError(message: "That block is already in the document; pass its index to replace it.")
                }
                guard update(document, with: written, at: index) != nil else { throw ToolError(message: "link must be a document link.") }
                return try read(document)
        }
    }
}

enum InterfaceTool: ContextTool {
    enum Method { case command, harness }
    enum Verb: String, CaseIterable { case read, add }

    static let tool = Tool(
        name: "interface",
        title: "Interface",
        description: "Commands, harnesses, and artifacts. read resolves an interface link to its data. add makes an interface available in a space.",
        inputSchema: .schema([
            "verb": .choice(Verb.self, "What to do."),
            "link": .link("The interface to read or add."),
            "space": .link("The space to add it to. Defaults to your space.")
        ], required: ["verb", "link"])
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
        let interface = try arguments.required("link")
        guard let value = with(interface) else { throw ToolError(message: "link must be an interface link.") }

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

enum StructureTool: ContextTool {
    enum Verb: String, CaseIterable { case new, read, add, remove }

    static let tool = Tool(
        name: "structure",
        title: "Structure",
        description: "Spaces. new creates a space. read returns a space's summary: its name, description, harness, child spaces, bridges, interfaces, and content, each with its link. add puts a document, transcript, interface, or space into a space, and a space moves under its new parent. remove deletes what the link points at.",
        inputSchema: .schema([
            "verb": .choice(Verb.self, "What to do."),
            "link": .link("What to read, add, or remove."),
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
            var fields: [String: Property] = ["name": .string(ref.descriptor.name), "link": .link(ref)]
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
        guard let value = with(content) else { throw ToolError(message: "link must be a space or bridge link.") }
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
                return try read(arguments.required("link"))

            case .add:
                let content = try arguments.required("link")
                let target = try arguments.link("space") ?? space
                guard update(content, in: target) != nil else { throw ToolError(message: "space must be a space link.") }
                return try read(target)

            case .remove:
                let content = try arguments.required("link")
                try await remove(content)
                return ["removed": .link(content)]
        }
    }
}

enum ComposeTool: ContextTool {
    enum Activity { case start, stop }
    enum Intent { case dispatch, evaluate, search }
    enum Verb: String, CaseIterable { case start, stop, read }

    static let tool = Tool(
        name: "compose",
        title: "Compose",
        description: "Runs spaces through their harness. start and stop a space's composition. read returns a composition's state, intent, harness, and transcript.",
        inputSchema: .schema([
            "verb": .choice(Verb.self, "What to do."),
            "space": .link("The space. Required to start or stop; read defaults to your space.")
        ], required: ["verb"])
    )

    static func compose(_ activity: Activity, for space: Reference) -> Composition? {
        switch activity {
            case .start: Runtime.shared.start(space)
            case .stop: Runtime.shared.stop(space)
        }
    }

    static func context(for space: Reference) -> Composition? {
        Runtime.shared.resolve(space)
    }

    static func read(_ composition: Composition?) throws -> Property {
        guard let composition else { throw ToolError(message: "That space has no composition. It needs a harness, and it has to be running to stop.") }
        return [
            "space": .link(composition.space),
            "state": .string(String(describing: composition.state)),
            "intent": .string(composition.intent.rawValue),
            "harness": .link(composition.harness),
            "transcript": .link(composition.transcript)
        ]
    }

    static func call(_ arguments: [String: Property], in space: Reference) async throws -> Property {
        let verb = try arguments.choice("verb", Verb.self)
        if verb == .read { return try read(context(for: arguments.link("space") ?? space)) }
        guard let target = try arguments.link("space") else { throw ToolError(message: "space is required to start or stop.") }
        return try read(compose(verb == .start ? .start : .stop, for: target))
    }
}

enum DispatchTool {
    static func dispatch(_ query: String) async throws -> SearchResults {
        fatalError("TODO")
    }
}

enum EvaluateTool {
    static func goal(_ query: String) async throws {
        fatalError("TODO")
    }

    static func planning(_ query: String) async throws {
        fatalError("TODO")
    }
}

enum SearchTool {
    enum Strategy { case research, locate, update }
    enum Target { case content, file, link }

    static func search(_ query: String) async throws -> SearchResults {
        fatalError("TODO")
    }
}

struct ContextProvider {
    static var content: ContentTool.Type { ContentTool.self }
    static var interface: InterfaceTool.Type { InterfaceTool.self }
    static var structure: StructureTool.Type { StructureTool.self }
    static var compose: ComposeTool.Type { ComposeTool.self }
    static var dispatch: DispatchTool.Type { DispatchTool.self }
    static var evaluate: EvaluateTool.Type { EvaluateTool.self }
    static var search: SearchTool.Type { SearchTool.self }
    static var context: [Composition] { Runtime.shared.resolve() }
    static var tools: [any ContextTool.Type] { [content, interface, structure, compose] }

    @MainActor static func call(_ name: String, _ arguments: [String: Property], context id: UUID) async throws -> Property? {
        guard let tool = tools.first(where: { $0.tool.name == name }) else { return nil }
        guard let space = context.first(where: { $0.space.contextId == id })?.space
        else { throw ToolError(message: "No running composition matches this context.") }
        return try await tool.call(arguments, in: space)
    }
}
