import Foundation


struct CatalogTool: Tool {
    let origin: Reference
    let namespace: ToolNamespace
    let action: Operation

    enum Operation: String, Sendable, CaseIterable {
        case list, search, describe, update
    }

    var operation: String { action.rawValue }

    var title: String {
        switch action {
            case .list: "List \(namespace.rawValue)"
            case .search: "Search \(namespace.rawValue)"
            case .describe: "Describe \(noun)"
            case .update: "Rename \(noun)"
        }
    }

    var summary: String {
        switch action {
            case .list:
                "Every \(noun) in this space, with its address and a one-line summary."
            case .search:
                "Find a \(noun) anywhere in the library, including ones not in this space. "
                    + "Results outside it are marked; bring one in with scint.structures.add."
            case .describe:
                "What one \(noun) is: its name, description, tags, kind, and what it holds."
            case .update:
                "Change what a \(noun) is called, how it is described, or how it is tagged. "
                    + "This edits the label, not the contents."
        }
    }

    var parameters: [ToolParameter] {
        switch action {
            case .list: []
            case .search: [.string("query", "What to look for. Matches names, descriptions, and tags.")]
            case .describe: [.reference(noun, "The \(noun) to describe.")]
            case .update:
                [
                    .reference(noun, "The \(noun) to change."),
                    .string("name", "New name.", required: false),
                    .string("description", "New description.", required: false),
                    .string("tags", "New tags, comma separated. Replaces the existing set.", required: false),
                ]
        }
    }

    private var noun: String {
        switch namespace {
            case .content: "document"
            case .interfaces: "interface"
            case .structures: "structure"
        }
    }

    @MainActor
    static func all(_ namespace: ToolNamespace, in origin: Reference) -> [CatalogTool] {
        guard !Scope.members(of: namespace, in: origin).isEmpty else { return [] }
        return Operation.allCases.map { CatalogTool(origin: origin, namespace: namespace, action: $0) }
    }

    func call(_ arguments: Properties) async -> ToolResult {
        await MainActor.run {
            switch action {
                case .list: list()
                case .search: search(arguments)
                case .describe: describe(arguments)
                case .update: update(arguments)
            }
        }
    }

    @MainActor
    private func list() -> ToolResult {
        let members = Scope.members(of: namespace, in: origin)
        guard !members.isEmpty else { return .ok("This space has no \(noun)s.") }
        return .ok(members.map { Self.line($0) }.joined(separator: "\n"))
    }

    /// Searches the whole library, not just this space.
    ///
    /// Finding out that something exists is not the same as being able to read it — every other
    /// tool still checks reachability. What this buys is the ability to name something outside the
    /// space in order to bring it in, which is otherwise unreachable by construction.
    @MainActor
    private func search(_ arguments: Properties) -> ToolResult {
        guard let query = arguments["query"]?.string, !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure("A query is required.")
        }

        let inScope = Set(Scope.members(of: namespace, in: origin))
        let found = Runtime.shared.search(query, limit: 40).all
            .map(\.ref)
            .filter { ToolNamespace.of($0) == namespace }

        guard !found.isEmpty else { return .ok("Nothing matches \(query).") }

        return .ok(
            found.map { ref in
                inScope.contains(ref) ? Self.line(ref) : "\(Self.line(ref))\n  [not in this space]"
            }.joined(separator: "\n")
        )
    }

    @MainActor
    private func describe(_ arguments: Properties) -> ToolResult {
        guard let ref = resolve(arguments) else {
            return .failure("An address for a \(noun) in this space is required. Use scint.\(namespace.rawValue).list.")
        }
        return .ok(Self.detail(ref))
    }

    @MainActor
    private func update(_ arguments: Properties) -> ToolResult {
        guard let ref = resolve(arguments) else {
            return .failure("An address for a \(noun) in this space is required.")
        }

        let name = arguments["name"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = arguments["description"]?.string
        let tags = arguments["tags"]?.string

        guard name != nil || description != nil || tags != nil else {
            return .failure("Supply a name, a description, or tags.")
        }

        Catalog.shared.update(ref) { descriptor in
            if let name, !name.isEmpty { descriptor.name = name }
            if let description { descriptor.description = description }
            if let tags {
                descriptor.tags = Set(
                    tags.split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                )
            }
        }

        return .ok(Self.detail(ref))
    }

    /// The object an argument names, when it is one this space can reach.
    @MainActor
    func resolve(_ arguments: Properties, _ key: String? = nil) -> Reference? {
        guard let supplied = arguments[key ?? noun]?.string, !supplied.isEmpty,
              let ref = Reference.Link.reference(in: supplied) ?? Reference.Link.resolve(supplied),
              Scope.reachable(ref, in: origin)
        else { return nil }
        return ref
    }

    // MARK: - Rendering

    /// One line: what it is, where it is, and enough to decide whether to look closer.
    @MainActor
    static func line(_ ref: Reference) -> String {
        let address = Reference.Link.url(for: ref)?.absoluteString ?? ref.id.uuidString
        let description = ref.descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let head = "\(ref.descriptor.name)  \(kind(ref))  \(address)"
        return description.isEmpty ? head : "\(head)\n  \(description)"
    }

    @MainActor
    static func detail(_ ref: Reference) -> String {
        let descriptor = ref.descriptor
        var lines = [
            descriptor.name,
            "kind: \(kind(ref))",
            "address: \(Reference.Link.url(for: ref)?.absoluteString ?? ref.id.uuidString)",
        ]
        if !descriptor.description.isEmpty { lines.append("description: \(descriptor.description)") }
        if !descriptor.tags.isEmpty { lines.append("tags: \(descriptor.tags.sorted().joined(separator: ", "))") }
        lines.append("updated: \(descriptor.updated.formatted(.iso8601))")
        lines += contents(ref)
        return lines.joined(separator: "\n")
    }

    static func kind(_ ref: Reference) -> String {
        ref.type.map { String(describing: $0).lowercased() } ?? "unresolved"
    }

    /// What this particular kind of object holds, which is the part that differs.
    @MainActor
    private static func contents(_ ref: Reference) -> [String] {
        if let blocks = Material.with(ref, { $0.blocks.count }) {
            return ["blocks: \(blocks)"]
        }
        if let transcript = Transcript.with(ref, { ($0.entries.count, $0.active, $0.started) }) {
            var lines = ["entries: \(transcript.0)", "active: \(transcript.1)"]
            if let started = transcript.2 { lines.append("started: \(started.formatted(.iso8601))") }
            return lines
        }
        if let handler = Artifact.with(ref, { $0.handler }) {
            return ["handler: \(handler.type)", "target: \(handler.url?.absoluteString ?? "none")"]
        }
        // A command or harness reports its full schema, not a list of names.
        //
        // `scint.interfaces.call` takes arguments as a free-form object, so this is the only place
        // a caller learns their shape — a summary would leave it guessing at types.
        if ref.type is Command.Type || ref.type is Harness.Type {
            let schema = InterfaceRunner(interface: ref, origin: ref).inputSchema
            guard let data = try? JSONEncoder().encode(schema),
                  let json = String(data: data, encoding: .utf8)
            else { return [] }
            return ["arguments:", json]
        }
        if Space.with(ref, { $0 }) != nil || Workspace.with(ref, { $0 }) != nil {
            var lines = ToolNamespace.allCases.map { namespace in
                "\(namespace.rawValue): \(Scope.members(of: namespace, in: ref).count)"
            }
            let harness = Space.with(ref, { $0.harness }) ?? Workspace.with(ref, { $0.harness }) ?? nil
            lines.append("harness: \(harness?.descriptor.name ?? "none")")
            lines.append("state: \(Runtime.shared.compose(ref).map { "\($0.state)" } ?? "inactive")")
            return lines
        }
        return []
    }
}
