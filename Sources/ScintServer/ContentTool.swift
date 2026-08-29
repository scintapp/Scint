import Foundation


struct ContentTool: Sendable {
    enum Operation: String, Sendable, CaseIterable {
        case load, list, update

        var toolName: String { "Scint.content.\(rawValue)" }
    }

    let origin: Reference
    let operation: Operation

    static func handle(for ref: Reference) -> String { ref.handle }

    static func manifest(in origin: Reference) -> [(handle: String, ref: Reference)] {
        guard let closure = Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure })
        else { return [] }
        return (Closure.with(closure, { $0.materials }) ?? [])
            .filter { !$0.descriptor.tags.contains("input") && $0.descriptor.published }
            .map { (handle(for: $0), $0) }
    }

    static func all(in origin: Reference) -> [ContentTool] {
        guard !manifest(in: origin).isEmpty else { return [] }
        return Operation.allCases.map { ContentTool(origin: origin, operation: $0) }
    }

    static func find(_ name: String, in origin: Reference) -> ContentTool? {
        all(in: origin).first { $0.operation.toolName == name }
    }

    static func identifier(_ block: Material.Block) -> String {
        switch block {
            case .artifact(let ref), .command(let ref), .material(let ref): return ref.handle
            case .task(let id, _, _), .text(let id, _): return truncated(id.uuidString)
        }
    }

    static func kind(_ block: Material.Block) -> String {
        switch block {
            case .artifact: return "artifact"
            case .command: return "command"
            case .material: return "material"
            case .task: return "task"
            case .text: return "text"
        }
    }

    private static func truncated(_ value: String) -> String {
        String(value.lowercased().replacingOccurrences(of: "-", with: "").prefix(Reference.handleLength))
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
    }

    private var handleSchema: Property {
        .object([
            "type": .string("string"),
            "description": .string("The bracketed handle shown beside a document title, for example 9ce7157f.")
        ])
    }

    private var inputSchema: Property {
        switch operation {
            case .load:
                return .object([
                    "type": .string("object"),
                    "properties": .object(["handle": handleSchema]),
                    "required": .array([.string("handle")]),
                    "additionalProperties": .bool(false)
                ])

            case .list:
                return .object([
                    "type": .string("object"),
                    "properties": .object(["handle": handleSchema]),
                    "additionalProperties": .bool(false)
                ])

            case .update:
                return .object([
                    "type": .string("object"),
                    "properties": .object([
                        "handle": handleSchema,
                        "block": .object([
                            "type": .string("string"),
                            "description": .string("The bracketed block id returned by Scint.content.list.")
                        ]),
                        "done": .object([
                            "type": .string("boolean"),
                            "description": .string("New completion state. Tasks only.")
                        ]),
                        "text": .object([
                            "type": .string("string"),
                            "description": .string("Replacement text for a task or text block.")
                        ])
                    ]),
                    "required": .array([.string("handle"), .string("block")]),
                    "additionalProperties": .bool(false)
                ])
        }
    }

    var definition: Property {
        let title: String
        let description: String
        switch operation {
            case .load:
                title = "Load document"
                description = "Read the current body of a document in this space, using the bracketed handle shown beside its title."
            case .list:
                title = "List content"
                description = "List the documents in this space, or with a handle, the blocks inside one document with their ids, kinds, and task states."
            case .update:
                title = "Update block"
                description = "Change a task's completion state or replace the text of a task or text block, addressed by document handle and block id."
        }
        return .object([
            "name": .string(operation.toolName),
            "title": .string(title),
            "description": .string(description),
            "inputSchema": inputSchema
        ])
    }

    func call(_ arguments: Properties) -> ServerTool.Invocation {
        switch operation {
            case .load: return load(arguments)
            case .list: return list(arguments)
            case .update: return update(arguments)
        }
    }

    private func resolve(_ supplied: String) -> (ref: Reference?, message: String?) {
        let wanted = Self.normalized(supplied)
        let entries = Self.manifest(in: origin)
        let matches = entries.filter { $0.handle.hasPrefix(wanted) || wanted.hasPrefix($0.handle) }

        guard !matches.isEmpty else {
            let available = entries.map { "\($0.ref.descriptor.name) [\($0.handle)]" }.joined(separator: ", ")
            return (nil, available.isEmpty
                    ? "This space has no documents."
                    : "No document matches \(supplied). Available: \(available)")
        }
        guard matches.count == 1, let match = matches.first else {
            let ambiguous = matches.map { "[\($0.handle)]" }.joined(separator: ", ")
            return (nil, "\(supplied) matches more than one document: \(ambiguous)")
        }
        return (match.ref, nil)
    }

    private func load(_ arguments: Properties) -> ServerTool.Invocation {
        guard let supplied = arguments["handle"]?.string, !supplied.isEmpty else {
            return .init(text: "A document handle is required.", isError: true)
        }
        let resolved = resolve(supplied)
        guard let ref = resolved.ref else { return .init(text: resolved.message ?? "", isError: true) }

        let body = Runtime.shared.rendered(ref).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return .init(text: "\(ref.descriptor.name) is empty.", isError: false) }
        return .init(text: "# \(ref.descriptor.name)\n\n\(body)", isError: false)
    }

    private func list(_ arguments: Properties) -> ServerTool.Invocation {
        guard let supplied = arguments["handle"]?.string, !supplied.isEmpty else {
            let entries = Self.manifest(in: origin)
            guard !entries.isEmpty else { return .init(text: "This space has no documents.", isError: false) }
            let lines = entries.map { entry -> String in
                let description = entry.ref.descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
                return description.isEmpty
                    ? "[\(entry.handle)] \(entry.ref.descriptor.name)"
                    : "[\(entry.handle)] \(entry.ref.descriptor.name) — \(description)"
            }
            return .init(text: lines.joined(separator: "\n"), isError: false)
        }

        let resolved = resolve(supplied)
        guard let ref = resolved.ref else { return .init(text: resolved.message ?? "", isError: true) }

        let blocks = Material.with(ref, { $0.blocks }) ?? []
        guard !blocks.isEmpty else { return .init(text: "\(ref.descriptor.name) is empty.", isError: false) }

        let lines = blocks.map { block -> String in
            let id = Self.identifier(block)
            switch block {
                case .task(_, let text, let done):
                    return "[\(id)] task \(done ? "[x]" : "[ ]") \(text)"
                case .text(_, let text):
                    return "[\(id)] text \(Self.summary(text))"
                case .artifact(let ref), .command(let ref), .material(let ref):
                    return "[\(id)] \(Self.kind(block)) \(ref.descriptor.name)"
            }
        }
        return .init(text: "# \(ref.descriptor.name)\n\n\(lines.joined(separator: "\n"))", isError: false)
    }

    private static func summary(_ text: String) -> String {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return flat.count > 80 ? "\(flat.prefix(80))…" : flat
    }

    private func update(_ arguments: Properties) -> ServerTool.Invocation {
        guard let supplied = arguments["handle"]?.string, !supplied.isEmpty else {
            return .init(text: "A document handle is required.", isError: true)
        }
        guard let identifier = arguments["block"]?.string, !identifier.isEmpty else {
            return .init(text: "A block id is required.", isError: true)
        }
        let resolved = resolve(supplied)
        guard let ref = resolved.ref else { return .init(text: resolved.message ?? "", isError: true) }

        let done = arguments["done"]?.bool
        let text = arguments["text"]?.string
        guard done != nil || text != nil else {
            return .init(text: "Supply done, text, or both.", isError: true)
        }

        let blocks = Material.with(ref, { $0.blocks }) ?? []
        let wanted = Self.normalized(identifier)
        let matches = blocks.indices.filter {
            let id = Self.identifier(blocks[$0])
            return id.hasPrefix(wanted) || wanted.hasPrefix(id)
        }
        guard !matches.isEmpty else {
            return .init(text: "No block in \(ref.descriptor.name) matches \(identifier).", isError: true)
        }
        guard matches.count == 1, let index = matches.first else {
            let ambiguous = matches.map { "[\(Self.identifier(blocks[$0]))]" }.joined(separator: ", ")
            return .init(text: "\(identifier) matches more than one block: \(ambiguous)", isError: true)
        }

        let replacement: Material.Block
        switch blocks[index] {
            case .task(let id, let existing, let complete):
                replacement = .task(id, text ?? existing, done ?? complete)

            case .text(let id, let existing):
                guard done == nil else {
                    return .init(text: "A text block has no completion state.", isError: true)
                }
                replacement = .text(id, text ?? existing)

            default:
                return .init(text: "A \(Self.kind(blocks[index])) block cannot be edited this way.", isError: true)
        }

        Material.update(ref) { $0.update(replacement, at: index) }
        return .init(text: "Updated [\(Self.identifier(replacement))] in \(ref.descriptor.name).", isError: false)
    }
}
