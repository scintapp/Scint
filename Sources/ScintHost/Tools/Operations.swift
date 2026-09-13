import Foundation


/// Every tool Scint exposes.
///
/// One enum, layered by what it acts on, terminating in a runtime call. No dispatcher, no schema
/// validator, no second vocabulary to keep in step: the case is the name, the case is the schema,
/// and the case body is the call. Adding a tool means adding a case and handling it in `run`, which
/// the compiler insists on.
enum Op: Sendable {
    case space(SpaceAction)
    case material(MaterialAction)
    case interface(InterfaceAction)
    case library(LibraryAction)

    enum SpaceAction: String, CaseIterable, Sendable { case read, create, add, start, stop }
    enum MaterialAction: String, CaseIterable, Sendable { case create, read, append }
    enum InterfaceAction: String, CaseIterable, Sendable { case describe, run }
    enum LibraryAction: String, CaseIterable, Sendable { case search }

    static let all: [Op] =
        SpaceAction.allCases.map(Op.space)
        + MaterialAction.allCases.map(Op.material)
        + InterfaceAction.allCases.map(Op.interface)
        + LibraryAction.allCases.map(Op.library)

    var group: String {
        switch self {
            case .space: "space"
            case .material: "material"
            case .interface: "interface"
            case .library: "library"
        }
    }

    var action: String {
        switch self {
            case .space(let action): action.rawValue
            case .material(let action): action.rawValue
            case .interface(let action): action.rawValue
            case .library(let action): action.rawValue
        }
    }

    var name: String { Tools.name(group, action) }

    /// Reads a recorded tool name back into the operation it names. Codex writes
    /// `scint.space.read`; Claude prefixes the server and flattens the dots, as
    /// `mcp__scint__scint_space_read`.
    static func named(_ recorded: String) -> Op? {
        let canonical = (recorded.components(separatedBy: "__").last ?? recorded)
            .replacingOccurrences(of: "_", with: ".")
        return all.first { $0.name == canonical }
    }

    /// Past tense, because a transcript is a record of what already happened.
    var sentence: String {
        let verb = switch action {
            case "read": "Read"
            case "create": "Created"
            case "add": "Added to"
            case "append": "Appended to"
            case "start": "Started"
            case "stop": "Stopped"
            case "describe": "Described"
            case "run": "Ran"
            case "search": "Searched"
            default: "Used"
        }
        return "\(verb) \(group)"
    }

    var symbol: String {
        switch self {
            case .space(.read): "square.stack"
            case .space(.create): "plus.square"
            case .space(.add): "tray.and.arrow.down"
            case .space(.start): "play"
            case .space(.stop): "stop"
            case .material(.create): "doc.badge.plus"
            case .material(.read): "book"
            case .material(.append): "pencil"
            case .interface(.describe): "info.circle"
            case .interface(.run): "switch.2"
            case .library(.search): "magnifyingglass"
        }
    }

    var title: String {
        switch self {
            case .space(.read): "Read space"
            case .space(.create): "Create space"
            case .space(.add): "Add to space"
            case .space(.start): "Start space"
            case .space(.stop): "Stop space"
            case .material(.create): "Create document"
            case .material(.read): "Read document"
            case .material(.append): "Append to document"
            case .interface(.describe): "Describe interface"
            case .interface(.run): "Run interface"
            case .library(.search): "Search library"
        }
    }

    var summary: String {
        switch self {
            case .space(.read):
                "What a space holds — its documents, interfaces, and child spaces, as addresses."
            case .space(.create):
                "A new space beneath this one. It starts empty and runs nothing until given a harness."
            case .space(.add):
                "Put a document, interface, or space into a space. Adding a harness is what makes a space runnable."
            case .space(.start):
                "Bring a space to life under its harness."
            case .space(.stop):
                "Stand a space down. It keeps everything it holds."
            case .material(.create):
                "Add a document to a space, optionally with a starting body."
            case .material(.read):
                "The full body of a document, or the thread of a transcript."
            case .material(.append):
                "Add a paragraph to the end of a document."
            case .interface(.describe):
                "What a command or harness takes, as a JSON Schema for its arguments."
            case .interface(.run):
                "Run a command or harness and return its output. Describe it first for the argument shape."
            case .library(.search):
                "Find something by name, description, or tag — including things outside this space."
        }
    }

    var schema: Property {
        switch self {
            case .space(.read):
                .schema(["space": .address("The space to read. Defaults to the current one.")])
            case .space(.create):
                .schema([
                    "name": ["type": "string", "description": "What to call it."],
                    "parent": .address("The space it sits in. Defaults to the current one.")
                ], required: ["name"])
            case .space(.add):
                .schema([
                    "member": .address("The document, interface, or space to add."),
                    "space": .address("The space it goes in. Defaults to the current one.")
                ], required: ["member"])
            case .space(.start), .space(.stop):
                .schema(["space": .address("The space. Defaults to the current one.")])
            case .material(.create):
                .schema([
                    "name": ["type": "string", "description": "What to call it."],
                    "text": ["type": "string", "description": "Starting body. One paragraph per line."],
                    "space": .address("The space to create it in. Defaults to the current one.")
                ], required: ["name"])
            case .material(.read):
                .schema(["document": .address("The document or transcript to read.")], required: ["document"])
            case .material(.append):
                .schema([
                    "document": .address("The document to add to."),
                    "text": ["type": "string", "description": "The paragraph to append."]
                ], required: ["document", "text"])
            case .interface(.describe):
                .schema(["interface": .address("The command or harness to describe.")], required: ["interface"])
            case .interface(.run):
                .schema([
                    "interface": .address("The command or harness to run."),
                    "arguments": ["type": "object", "description": "Its arguments, shaped as describe reports."]
                ], required: ["interface"])
            case .library(.search):
                .schema([
                    "query": ["type": "string", "description": "Matches names, descriptions, and tags."]
                ], required: ["query"])
        }
    }

    // MARK: - The runtime calls

    @MainActor
    func run(_ arguments: Supplied) async throws -> ToolResult {
        switch self {
            case .space(.read):
                return .ok(Render.space(try arguments.reference("space", or: arguments.space)))

            case .space(.create):
                let parent = try arguments.reference("parent", or: arguments.space)
                guard parent.type == Space.self else { throw ToolFailure("parent must be a space.") }
                let created = Space.new(parent, name: try arguments.string("name"))
                return .ok("Created \(Render.address(created)) in \(parent.descriptor.name).")

            case .space(.add):
                let member = try arguments.reference("member")
                let space = try arguments.reference("space", or: arguments.space)
                guard member != space else { throw ToolFailure("A space cannot contain itself.") }
                if member.type == Space.self { Space.update(member) { $0.attach(to: space) } }
                else { Space.with(space) { $0.add(member) } }
                return .ok("\(member.descriptor.name) is now in \(space.descriptor.name).")

            case .space(.start):
                let space = try arguments.reference("space", or: arguments.space)
                guard let composition = Runtime.shared.start(space) else {
                    throw ToolFailure("\(space.descriptor.name) has no harness, so it cannot start.")
                }
                return .ok("\(space.descriptor.name) is \(composition.state).")

            case .space(.stop):
                let space = try arguments.reference("space", or: arguments.space)
                guard let composition = Runtime.shared.stop(space) else {
                    throw ToolFailure("\(space.descriptor.name) is not running.")
                }
                return .ok("\(space.descriptor.name) is \(composition.state).")

            case .material(.create):
                let space = try arguments.reference("space", or: arguments.space)
                guard space.type == Space.self else { throw ToolFailure("space must be a space.") }
                let created = Material.new(space, name: try arguments.string("name"))
                if let text = arguments.text("text") {
                    Material.update(created) { document in
                        for line in text.components(separatedBy: "\n") {
                            document.insert(.text(UUID(), line), at: nil)
                        }
                    }
                }
                return .ok("Created \(Render.address(created)) in \(space.descriptor.name).")

            case .material(.read):
                return .ok(try Render.body(try arguments.reference("document")))

            case .material(.append):
                let document = try arguments.reference("document")
                let text = try arguments.string("text")
                guard Material.update(document, { $0.insert(.text(UUID(), text), at: nil) }) != nil
                else { throw ToolFailure("\(document.descriptor.name) is not a document.") }
                return .ok("Appended to \(document.descriptor.name).")

            case .interface(.describe):
                let interface = try arguments.reference("interface")
                let runner = InterfaceRunner(interface: interface, origin: arguments.space, identity: arguments.identity)
                guard let encoded = try? JSONEncoder().encode(runner.inputSchema),
                      let json = String(data: encoded, encoding: .utf8)
                else { throw ToolFailure("\(interface.descriptor.name) has no argument schema.") }
                return .ok("\(Render.line(interface))\n\narguments:\n\(json)")

            case .interface(.run):
                let interface = try arguments.reference("interface")
                guard interface.type == Command.self || interface.type == Harness.self else {
                    throw ToolFailure("\(interface.descriptor.name) is not runnable. Read it instead.")
                }
                let supplied = arguments.properties["arguments"]?.properties ?? .object([String: Property]())
                return await InterfaceRunner(
                    interface: interface, origin: arguments.space, identity: arguments.identity
                ).call(supplied)

            case .library(.search):
                let query = try arguments.string("query")
                let found = Runtime.shared.search(query, limit: 40).all.map(\.ref)
                guard !found.isEmpty else { return .ok("Nothing matches \(query).") }
                return .ok(found.map { ref in
                    arguments.holds(ref) ? Render.line(ref) : "\(Render.line(ref))\n  [not in this space]"
                }.joined(separator: "\n"))
        }
    }
}

struct ToolFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

// MARK: - Arguments

/// Typed reads over what the caller supplied, so each runtime call states what it needs and fails
/// in one place when it isn't there. Named apart from the runtime's `Arguments`, which marshals
/// declared values into argv — a different direction entirely.
struct Supplied: Sendable {
    let properties: Properties
    let space: Reference
    let identity: ToolIdentity

    func text(_ key: String) -> String? {
        guard let value = properties[key]?.string, !value.trimmingCharacters(in: .whitespaces).isEmpty
        else { return nil }
        return value
    }

    func string(_ key: String) throws -> String {
        guard let value = text(key) else { throw ToolFailure("\(key) is required.") }
        return value
    }

    @MainActor
    func reference(_ key: String) throws -> Reference {
        guard let supplied = text(key) else { throw ToolFailure("\(key) is required.") }
        guard let ref = Reference.Link.reference(in: supplied) else {
            throw ToolFailure("\(key) must be a scint://<kind>/<id> address.")
        }
        guard holds(ref) else { throw ToolFailure("\(key) is not reachable from this space.") }
        return ref
    }

    @MainActor
    func reference(_ key: String, or fallback: Reference) throws -> Reference {
        properties[key] == nil ? fallback : try reference(key)
    }

    /// The whole access rule: anything this space holds, and anything in the cluster beneath it.
    @MainActor
    func holds(_ ref: Reference) -> Bool {
        if ref == space { return true }
        var spaces: Set<Reference> = []
        Runtime.shared.walk(from: space) { _, candidate, _ in spaces.insert(candidate) }
        if spaces.contains(ref) { return true }
        return spaces.contains { candidate in
            guard let closure = Space.with(candidate, { $0.closure }) else { return false }
            if closure == ref { return true }
            return Closure.with(closure) { $0.content.contains(ref) || $0.interfaces.contains(ref) } ?? false
        }
    }
}

// MARK: - Rendering

@MainActor
enum Render {
    static func address(_ ref: Reference) -> String {
        Reference.Link.url(for: ref)?.absoluteString ?? ref.id.uuidString.lowercased()
    }

    static func kind(_ ref: Reference) -> String {
        ref.type.map { String(describing: $0).lowercased() } ?? "unresolved"
    }

    static func line(_ ref: Reference) -> String {
        let description = ref.descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let head = "\(ref.descriptor.name)  \(kind(ref))  \(address(ref))"
        return description.isEmpty ? head : "\(head)\n  \(description)"
    }

    static func space(_ ref: Reference) -> String {
        var sections = [line(ref)]

        func section(_ heading: String, _ refs: [Reference]) {
            let visible = refs
                .filter { $0.descriptor.published && !$0.descriptor.tags.contains("input") }
                .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
            guard !visible.isEmpty else { return }
            sections.append("\n## \(heading)\n" + visible.map(line).joined(separator: "\n"))
        }

        if let closure = Space.with(ref, { $0.closure }) {
            Closure.with(closure) { held in
                section("documents", held.materials + held.transcripts)
                section("interfaces", held.artifacts + held.commands + held.harnesses)
            }
        }
        section("spaces", Array(Space.with(ref, { $0.spaces }) ?? []))

        return sections.joined(separator: "\n")
    }

    static func body(_ ref: Reference) throws -> String {
        if let blocks = Material.with(ref, { $0.blocks }) {
            guard !blocks.isEmpty else { return "\(ref.descriptor.name) is empty." }
            return "# \(ref.descriptor.name)\n\n" + blocks.map(block).joined(separator: "\n")
        }
        if let rendered = Transcript.with(ref, { $0.rendered }) {
            return "# \(ref.descriptor.name)\n\n\(rendered)"
        }
        throw ToolFailure("\(ref.descriptor.name) is a \(kind(ref)), which has no body.")
    }

    private static func block(_ block: Material.Block) -> String {
        switch block {
            case .task(_, let text, let done): "task \(done ? "[x]" : "[ ]") \(text)"
            case .text(_, let text): text
            case .artifact(let ref), .command(let ref), .material(let ref):
                "\(address(ref))  \(ref.descriptor.name)"
        }
    }
}

// MARK: - MCP binding

/// One `Op`, bound to the space that will run it, presented as an MCP tool.
private struct Binding: Tool {
    let op: Op
    let identity: ToolIdentity

    var name: String { op.name }
    var title: String { op.title }
    var summary: String { op.summary }
    var inputSchema: Property { op.schema }
    var subject: Reference? { identity.space }

    func call(_ arguments: Properties) async -> ToolResult {
        let supplied = Supplied(properties: arguments, space: identity.space, identity: identity)
        do { return try await op.run(supplied) }
        catch { return .failure(String(describing: error)) }
    }
}

extension Tools {
    @MainActor
    static func all(in identity: ToolIdentity) -> [any Tool] {
        Op.all.map { Binding(op: $0, identity: identity) }
    }
}
