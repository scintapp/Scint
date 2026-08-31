import Foundation


/// Reading and changing the content of a space.
///
/// Content is the `Malleable` family: materials, which are written, and transcripts, which are
/// recorded. `read` serves both because both render; only a material can be written to, and
/// saying so is more useful than hiding transcripts from a verb that would work on them.
///
/// Listing and describing are `CatalogTool`'s — they are the same work for every family, so they
/// are not repeated here.
struct ContentTool: Tool {
    let origin: Reference
    let action: Operation

    enum Operation: String, Sendable, CaseIterable {
        case read, write, create
    }

    var namespace: ToolNamespace { .content }
    var operation: String { action.rawValue }

    var title: String {
        switch action {
            case .read: "Read document"
            case .write: "Write block"
            case .create: "Create document"
        }
    }

    var summary: String {
        switch action {
            case .read:
                "The full body of a document or transcript, with the addresses it references."
            case .write:
                "Replace the text of a block, or set a task's completion state. Documents only."
            case .create:
                "Add a document to this space, optionally with a starting body."
        }
    }

    var parameters: [ToolParameter] {
        switch action {
            case .read:
                [.reference("document", "The document or transcript to read.")]
            case .write:
                [
                    .reference("document", "The document holding the block."),
                    .reference("block", "The block to change, as returned by scint.content.read."),
                    .string("text", "Replacement text.", required: false),
                    .boolean("done", "New completion state. Tasks only."),
                ]
            case .create:
                [
                    .string("name", "What to call it."),
                    .string("text", "Starting body. Markdown, one block per line.", required: false),
                    .reference("structure", "The space to create it in. Defaults to the current one.", required: false),
                ]
        }
    }

    static func all(in origin: Reference) -> [ContentTool] {
        Operation.allCases.map { ContentTool(origin: origin, action: $0) }
    }

    func call(_ arguments: Properties) async -> ToolResult {
        await MainActor.run {
            switch action {
                case .read: read(arguments)
                case .write: write(arguments)
                case .create: create(arguments)
            }
        }
    }

    // MARK: - Resolution

    private enum Resolved {
        case document(Reference)
        case failed(ToolResult)

        var reference: Reference? {
            guard case .document(let ref) = self else { return nil }
            return ref
        }
    }

    /// The space to build into: the one named, or the session's own.
    @MainActor
    private func structure(_ arguments: Properties) -> Resolved {
        guard arguments["structure"]?.string?.isEmpty == false else { return .document(origin) }
        guard let ref = document(arguments, "structure").reference,
              ref.type == Space.self || ref.type == Workspace.self
        else { return .failed(.failure("No space in reach matches that address.")) }
        return .document(ref)
    }

    @MainActor
    private func document(_ arguments: Properties, _ key: String = "document") -> Resolved {
        guard let supplied = arguments[key]?.string, !supplied.isEmpty else {
            return .failed(.failure("A \(key) address is required."))
        }
        guard let ref = ReferenceURL.reference(in: supplied) ?? ReferenceURL.resolve(supplied),
              Scope.reachable(ref, in: origin)
        else {
            return .failed(.failure("No content in this space matches \(supplied). Use scint.content.list."))
        }
        return .document(ref)
    }

    // MARK: - Operations

    @MainActor
    private func read(_ arguments: Properties) -> ToolResult {
        guard case .document(let ref) = document(arguments) else {
            guard case .failed(let result) = document(arguments) else { return .failure("Unreachable.") }
            return result
        }

        if let blocks = Material.with(ref, { $0.blocks }) {
            guard !blocks.isEmpty else { return .ok("\(ref.descriptor.name) is empty.") }
            return .ok("# \(ref.descriptor.name)\n\n\(blocks.map { Self.describe($0) }.joined(separator: "\n"))")
        }

        if let rendered = Transcript.with(ref, { $0.rendered }) {
            let body = rendered.trimmingCharacters(in: .whitespacesAndNewlines)
            return .ok(body.isEmpty ? "\(ref.descriptor.name) is empty." : "# \(ref.descriptor.name)\n\n\(body)")
        }

        return .ok(Renderer.reference(ref))
    }

    @MainActor
    private func write(_ arguments: Properties) -> ToolResult {
        guard case .document(let ref) = document(arguments) else {
            guard case .failed(let result) = document(arguments) else { return .failure("Unreachable.") }
            return result
        }
        guard let blocks = Material.with(ref, { $0.blocks }) else {
            return .failure("\(ref.descriptor.name) is a \(CatalogTool.kind(ref)) and is recorded, not written.")
        }
        guard let identifier = arguments["block"]?.string, !identifier.isEmpty else {
            return .failure("A block address is required. Use scint.content.read to see them.")
        }

        let done = arguments["done"]?.bool
        let text = arguments["text"]?.string
        guard done != nil || text != nil else { return .failure("Supply text, done, or both.") }

        guard let index = blocks.firstIndex(where: { Self.address($0) == Self.normalized(identifier) }) else {
            return .failure("No block in \(ref.descriptor.name) matches \(identifier).")
        }

        let replacement: Material.Block
        switch blocks[index] {
            case .task(let id, let existing, let complete):
                replacement = .task(id, text ?? existing, done ?? complete)
            case .text(let id, let existing):
                guard done == nil else { return .failure("A text block has no completion state.") }
                replacement = .text(id, text ?? existing)
            case .artifact, .command, .material:
                return .failure("A reference block cannot be written to.")
        }

        Material.update(ref) { $0.update(replacement, at: index) }
        return .ok("Updated \(Self.address(replacement)) in \(ref.descriptor.name).")
    }

    @MainActor
    private func create(_ arguments: Properties) -> ToolResult {
        guard let name = arguments["name"]?.string, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure("A name is required.")
        }

        // Without a target this always built into the session's own space, so making a document
        // somewhere else meant creating it here, adding it there, and removing it from here —
        // three calls and a stray membership to clean up, for something that is one call.
        let target: Reference
        switch structure(arguments) {
            case .failed(let result): return result
            case .document(let found): target = found
        }

        let ref = Material.new(target, name: name)

        if let text = arguments["text"]?.string, !text.isEmpty {
            Material.update(ref) { material in
                for line in text.components(separatedBy: "\n") {
                    material.insert(.text(UUID(), line), at: nil)
                }
            }
        }

        let address = ReferenceURL.url(for: ref)?.absoluteString ?? ref.id.uuidString
        return .ok("Created \(name) in \(target.descriptor.name) at \(address).")
    }

    // MARK: - Addressing

    /// A block's address. References carry their own; text and tasks are named by their own id in
    /// the same shape, so a caller never has to tell them apart.
    static func address(_ block: Material.Block) -> String {
        switch block {
            case .artifact(let ref), .command(let ref), .material(let ref):
                return ReferenceURL.url(for: ref)?.absoluteString ?? ref.id.uuidString.lowercased()
            case .task(let id, _, _), .text(let id, _):
                return "\(ReferenceURL.scheme)://block/\(id.uuidString.lowercased())"
        }
    }

    static func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "[] ")).lowercased()
        guard let id = UUID(uuidString: trimmed) else { return trimmed }
        return "\(ReferenceURL.scheme)://block/\(id.uuidString.lowercased())"
    }

    @MainActor
    static func describe(_ block: Material.Block) -> String {
        let address = address(block)
        switch block {
            case .task(_, let text, let done):
                return "\(address)  task \(done ? "[x]" : "[ ]") \(text)"
            case .text(_, let text):
                return "\(address)  \(text)"
            case .artifact(let ref), .command(let ref), .material(let ref):
                return "\(address)  \(ref.descriptor.name)"
        }
    }
}
