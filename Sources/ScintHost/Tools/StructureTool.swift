import Foundation


/// Reading and arranging the shape of a space.
///
/// Structures are the `Structural` family: the space itself, its closure, the spaces beneath it,
/// the bridges out of it. Renaming one is `scint.structures.update`, because a descriptor is a
/// descriptor whatever it labels — what is structural is *what a space holds and where it sits*.
///
/// `add` and `remove` are one pair rather than two because the runtime already sorts members by
/// family: `Space.add` routes `Functional` to interfaces and `Malleable` to content, and a space
/// given a space becomes its parent. The protocol does the dispatch, so the tool doesn't need to
/// ask the caller which kind of thing they are holding.
struct StructureTool: Tool {
    let origin: Reference
    let action: Operation

    enum Operation: String, Sendable, CaseIterable {
        case read, create, add, remove, start, stop
    }

    var namespace: ToolNamespace { .structures }
    var operation: String { action.rawValue }

    var title: String {
        switch action {
            case .read: "Read structure"
            case .create: "Create space"
            case .add: "Add to space"
            case .remove: "Remove from space"
            case .start: "Start space"
            case .stop: "Stop space"
        }
    }

    var summary: String {
        switch action {
            case .read:
                "What a space holds and what it connects to, as addresses."
            case .create:
                "A new space beneath this one. It starts empty and inert — it holds nothing and "
                    + "runs nothing until given content and a harness."
            case .add:
                "Put something in a space. A document or interface is *added* — it can belong to "
                    + "more than one space, so this does not remove it from anywhere; a space "
                    + "becomes a child of it, leaving wherever it was before; a harness is also "
                    + "set as the one the space runs under, which is what makes it composable. "
                    + "The member may come from outside this space — find one with "
                    + "scint.interfaces.search."
            case .remove:
                "Take something out of a space. What is removed still exists — only the "
                    + "relationship ends. Removing the harness a space runs under leaves it "
                    + "holding no harness, and no longer composable."
            case .start:
                "Bring a space to life. It composes under its harness and begins working from "
                    + "what it holds. A space needs a harness before it can start."
            case .stop:
                "Stand a space down. It keeps everything it holds and can be started again."
        }
    }

    var parameters: [ToolParameter] {
        switch action {
            case .read:
                [.reference("structure", "The space to read. Defaults to the current one.", required: false)]
            case .create:
                [
                    .string("name", "What to call it."),
                    .reference("parent", "The space it sits in. Defaults to the current one.", required: false),
                ]
            case .add, .remove:
                [
                    .reference("member", "The document, interface, or space to move."),
                    .reference("structure", "The space it goes in. Defaults to the current one.", required: false),
                ]
            case .start, .stop:
                [.reference("structure", "The space. Defaults to the current one.", required: false)]
        }
    }

    @MainActor
    static func all(in origin: Reference) -> [StructureTool] {
        Operation.allCases.map { StructureTool(origin: origin, action: $0) }
    }

    func call(_ arguments: Properties) async -> ToolResult {
        await MainActor.run {
            switch action {
                case .read: read(arguments)
                case .create: create(arguments)
                case .add: add(arguments)
                case .remove: remove(arguments)
                case .start: start(arguments)
                case .stop: stop(arguments)
            }
        }
    }

    // MARK: - Operations

    @MainActor
    private func read(_ arguments: Properties) -> ToolResult {
        guard let ref = structure(arguments, "structure") else {
            return .failure("No structure in this space matches that address.")
        }

        var sections: [String] = [CatalogTool.detail(ref)]
        for namespace in ToolNamespace.allCases {
            let members = Scope.members(of: namespace, in: ref)
            guard !members.isEmpty else { continue }
            sections.append(
                "\n## \(namespace.rawValue)\n" + members.map { CatalogTool.line($0) }.joined(separator: "\n")
            )
        }
        return .ok(sections.joined(separator: "\n"))
    }

    @MainActor
    private func create(_ arguments: Properties) -> ToolResult {
        guard let name = arguments["name"]?.string, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure("A name is required.")
        }
        guard let parent = structure(arguments, "parent") else {
            return .failure("No parent space matches that address.")
        }
        guard parent.type == Space.self || parent.type == Workspace.self else {
            return .failure("\(parent.descriptor.name) is a \(CatalogTool.kind(parent)) and cannot hold a space.")
        }

        let ref = Space.new(parent, name: name)
        return .ok("Created \(name) at \(ReferenceURL.url(for: ref)?.absoluteString ?? ref.id.uuidString).")
    }

    @MainActor
    private func add(_ arguments: Properties) -> ToolResult {
        guard let member = address(arguments, "member") else {
            return .failure("An address for the thing to add is required.")
        }
        guard let structure = structure(arguments, "structure") else {
            return .failure("No space matches that address.")
        }
        guard member != structure else { return .failure("A space cannot contain itself.") }

        if member.type is Space.Type {
            Space.update(member) { $0.attach(to: structure) }
            return .ok("\(member.descriptor.name) is now inside \(structure.descriptor.name).")
        }

        Space.with(structure, { $0.add(member) })

        // `Space.add` files a harness under the closure's interfaces, which holds it but does not
        // arm the space — `composable` reads `harness != nil`, a separate field nothing else
        // touches. Adding one used to report success for something that hadn't happened.
        guard member.type is Harness.Type, structure.type == Space.self else {
            return .ok("\(member.descriptor.name) is now in \(structure.descriptor.name).")
        }

        Space.update(structure) { $0.harness = member }
        return .ok(
            "\(structure.descriptor.name) now runs under \(member.descriptor.name) and is composable."
        )
    }

    @MainActor
    private func remove(_ arguments: Properties) -> ToolResult {
        guard let member = address(arguments, "member") else {
            return .failure("An address for the thing to remove is required.")
        }
        guard let structure = structure(arguments, "structure") else {
            return .failure("No space matches that address.")
        }

        if member.type is Space.Type {
            Space.update(member) { $0.detach(from: structure) }
            return .ok("\(member.descriptor.name) is no longer inside \(structure.descriptor.name).")
        }

        Space.with(structure, { $0.remove(member) })

        guard Space.with(structure, { $0.harness }) == member else {
            return .ok("\(member.descriptor.name) is no longer in \(structure.descriptor.name).")
        }

        Space.update(structure) { $0.harness = nil }
        return .ok(
            "\(structure.descriptor.name) no longer runs under \(member.descriptor.name) and is not composable."
        )
    }

    @MainActor
    private func start(_ arguments: Properties) -> ToolResult {
        guard let ref = structure(arguments, "structure") else {
            return .failure("No space matches that address.")
        }
        guard ref.type == Space.self || ref.type == Workspace.self else {
            return .failure("\(ref.descriptor.name) is a \(CatalogTool.kind(ref)). Only a space can be started.")
        }
        guard let harness = Space.with(ref, { $0.harness }) ?? Workspace.with(ref, { $0.harness }) else {
            return .failure(
                "\(ref.descriptor.name) has no harness and cannot start. Find one with "
                    + "scint.interfaces.search, then add it with scint.structures.add."
            )
        }

        guard let composition = Runtime.shared.start(ref) else {
            return .failure("\(ref.descriptor.name) could not be composed under \(harness.descriptor.name).")
        }
        return .ok("\(ref.descriptor.name) is \(Self.describe(composition.state)) under \(harness.descriptor.name).")
    }

    @MainActor
    private func stop(_ arguments: Properties) -> ToolResult {
        guard let ref = structure(arguments, "structure") else {
            return .failure("No space matches that address.")
        }
        guard let composition = Runtime.shared.stop(ref) else {
            return .failure("\(ref.descriptor.name) is not running.")
        }
        return .ok("\(ref.descriptor.name) is \(Self.describe(composition.state)).")
    }

    private static func describe(_ state: Composition.State) -> String {
        switch state {
            case .inactive: "inactive"
            case .active: "active"
            case .working: "working"
        }
    }

    // MARK: - Resolution

    /// A space named by an argument, defaulting to the one being worked in.
    @MainActor
    private func structure(_ arguments: Properties, _ key: String) -> Reference? {
        guard arguments[key]?.string?.isEmpty == false else { return origin }
        return resolve(arguments, key)
    }

    /// Any object the address names, in this space or not. Bringing something in is the one
    /// operation that has to reach past the boundary — the space it goes into is still checked.
    @MainActor
    private func address(_ arguments: Properties, _ key: String) -> Reference? {
        guard let supplied = arguments[key]?.string, !supplied.isEmpty else { return nil }
        return ReferenceURL.reference(in: supplied) ?? ReferenceURL.resolve(supplied)
    }

    @MainActor
    private func resolve(_ arguments: Properties, _ key: String) -> Reference? {
        guard let supplied = arguments[key]?.string, !supplied.isEmpty,
              let ref = ReferenceURL.reference(in: supplied) ?? ReferenceURL.resolve(supplied),
              ref == origin || Scope.reachable(ref, in: origin)
        else { return nil }
        return ref
    }
}
