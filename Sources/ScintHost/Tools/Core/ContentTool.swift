import Foundation
import ScintRuntime


enum ContentTool: Tool {
    enum Content: String, CaseIterable { case document, transcript }
    enum Verb: String, CaseIterable { case new, read, write }

    static let blockSchema: Property = [
        "type": "object",
        "description": "One block keyed by its kind, in the shape read returns: {\"text\": {\"text\": \"…\"}}, {\"task\": {\"text\": \"…\", \"done\": false, \"when\": {\"moment\": \"2026-09-30T09:00:00Z\", \"repeats\": \"never\"}}}, or {\"document\": \"scint://…\"}, and likewise artifact and command. A task's when is optional; repeats is never, hourly, daily, or weekly. Keep a block's id to replace it in place; leave the id out of a new block."
    ]

    static let method = Method(
        name: "content",
        title: "Content",
        description: "Documents and transcripts. new creates a document in a space. read resolves a document or transcript link to its data. write appends a block to a document, or replaces the block at index.",
        schema: .schema([
            "verb": .choice(Verb.self, "What to do."),
            "subject": .choice(Content.self, "What the content is. Transcripts can only be read. Defaults to document."),
            "ref": .link("The document or transcript to read or write."),
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
        guard let value = with(content) else { throw ToolError(message: "ref must be a document or transcript link.") }
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
                return try read(arguments.required("ref"))

            case .write:
                guard subject == .document else { throw ToolError(message: "Transcripts can only be read.") }
                let document = try arguments.required("ref")
                guard let blocks = Document.with(document, { $0.blocks }) else { throw ToolError(message: "ref must be a document link.") }
                let written = try block(arguments["block"])
                let index = arguments["index"]?.int
                if let index, !blocks.indices.contains(index) {
                    throw ToolError(message: "index \(index) is out of range; the document has \(blocks.count) blocks.")
                }
                if index == nil, blocks.contains(where: { $0.id == written.id }) {
                    throw ToolError(message: "That block is already in the document; pass its index to replace it.")
                }
                guard update(document, with: written, at: index) != nil else { throw ToolError(message: "ref must be a document link.") }
                return try read(document)
        }
    }
}
