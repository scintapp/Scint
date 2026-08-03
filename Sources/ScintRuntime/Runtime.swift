import Foundation


public final class Runtime: @unchecked Sendable {
    public static let shared = Runtime()
    public var workspace: Reference { Workspaces.shared.workspace }
    public var workspaces: [Reference] { Workspaces.shared.store(for: self.workspace)?.keys() ?? [] }
    let registry: Registry = .init()
    let settings: Settings = .init(name: "Scint")
    let services: Services = .init()

    func store(for ref: Reference) -> Store? {
        switch ref.type {
            case is any Structural.Type: return Workspaces.shared.store(for: ref)
            case is any Malleable.Type, is any Functional.Type: return Library.shared.store(for: ref)?.store(for: ref)
            default: return nil
        }
    }

    public func load() async throws {
        try await Workspaces.shared.load()
        try await Library.shared.load()
    }

    public func save() async throws {
        try await Workspaces.shared.save()
        try await Library.shared.save()
    }

    public func save(for ref: Reference) async {
        switch ref.type {
            case is any Structural.Type: await Workspaces.shared.save(ref)
            case is any Malleable.Type, is any Functional.Type: await Library.shared.save(ref)
            default: break
        }
    }
}

extension Runtime {
    public func get(_ ref: Reference) -> Descriptor {
        guard let descriptor = Catalog.shared.get(ref)
        else { fatalError(RuntimeError.Registry.missingDescriptor(ref).description) }
        return descriptor
    }

    public func set(_ ref: Reference, _ value: Descriptor) {
        Catalog.shared.set(ref, value)
    }

    public func all<T: Resolvable>(as type: T.Type) -> [(Reference, T)] {
        store(for: Reference(T.self))?.all(as: type) ?? []
    }
}

extension Runtime {
    public func compose(_ signal: Signal) -> Composition? { Composer.shared.compose(signal) }

    public func eval(_ origin: Reference) -> Composition? { compose(.eval(origin)) }

    public func context(for ref: Reference) -> Composition? { Composer.shared.resolve(ref) }

    public func context() -> [Composition] { Composer.shared.resolve() }

    public func transcripts(for ref: Reference) -> [Reference] {
        Runtime.shared.all(as: Transcript.self)
            .filter { $0.1.owner == ref }
            .map { $0.0 }
    }
}

extension Runtime {
    public func context(from origin: Reference) -> Set<Reference> {
        var context: Set<Reference> = [origin]
        var pending: [Reference] = []
        var visited: Set<Reference> = []

        func include(_ closure: Reference) {
            context.insert(closure)
            Closure.with(closure) {
                context.insert($0.input)
                context.formUnion($0.content)
                context.formUnion($0.interfaces)
            }
        }

        if let workspace = Workspace.with(origin, { $0 }) {
            include(workspace.closure)
            pending.append(contentsOf: workspace.spaces)
        } else if origin.type == Space.self {
            pending.append(origin)
        }

        while let ref = pending.popLast() {
            guard visited.insert(ref).inserted, let space = Space.with(ref, { $0 }) else { continue }
            context.insert(ref)
            include(space.closure)
            pending.append(contentsOf: space.spaces)
            for (route, target, _) in adjacent(from: ref) {
                context.insert(route.ref)
                pending.append(target)
            }
        }
        return context
    }

    public func search(_ text: String = "", limit: Int = 20) -> SearchResults {
        let search = SearchRequest(text)
        let results = Catalog.shared.values().compactMap { SearchResult(descriptor: $0, search: search) }

        return SearchResults(
            query: text,
            text: search.text,
            filters: search.filters,
            all: Query.rank(results, limit: limit)
        )
    }

    public func walk(from root: Reference, path: [Reference] = [], _ visit: ([Reference], Reference, Space) -> Void) {
        func dfs(_ ref: Reference, _ path: [Reference]) {
            guard !seen.contains(ref) else { return }
            seen.insert(ref)
            guard let children = Space.with(ref, { space in
                visit(path, ref, space)
                return space.spaces
            }) else { return }
            let nextPath = path + [ref]
            for child in children { dfs(child, nextPath) }
        }
        var seen = Set<Reference>()
        dfs(root, path)
    }

    public func climb(from root: Reference, path: [Reference] = [], _ visit: ([Reference], Reference, Space) -> Void) {
        var currentPath = path
        var cursor: Reference? = root

        while let current = cursor, let space = Space.with(current, { $0 }) {
            visit(currentPath, current, space)
            currentPath.append(current)
            cursor = space.space
        }
    }

    public func cross(from root: Reference, path: [Reference] = [],_ visit: ([Reference], Reference, Route, Reference, Space) -> Void) {
        var seen = Set<Reference>()
        func dfs(_ current: Reference, _ path: [Reference]) {
            guard seen.insert(current).inserted else { return }
            for (edge, target, space) in adjacent(from: current) {
                visit(path, current, edge, target, space)
                dfs(target, path + [current])
            }
        }
        dfs(root, path)
    }

    public func adjacent(from source: Reference) -> [(Route, Reference, Space)] {
        let refs = Space.with(source, { $0.routes }) ?? []

        return refs.compactMap { edge in
            guard let route = Route.with(edge, { $0 }) else { return nil }
            let target: Reference? = if route.origin == source { route.target }
            else if route.target == source { route.origin }
            else { nil }
            guard let target else { return nil }
            guard let space = Space.with(target, { $0 }) else { return nil }
            return (route, target, space)
        }
    }
}

// What the fuck is this bullshit?
extension Runtime {
    public enum Callback: Sendable {
        case open(Reference)
        case eval(Reference)
        case dispatch(command: Reference, pid: Int32, error: String?)
        case run(artifact: Reference, pid: Int32, error: String?)
        case search(SearchResults)
    }

    public func handle(_ url: URL) throws -> Callback {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "Scint",
              let action = components.host?.lowercased()
        else { throw CallbackError.invalidURL }

        let query = (components.queryItems ?? []).reduce(into: [String: String]()) { values, item in
            values[item.name] = item.value
        }

        switch action {
            case "open":
                guard let value = query["descriptor"] else { throw CallbackError.missing("descriptor") }
                return .open(try reference(for: value))

            case "trigger":
                guard let value = query["descriptor"] else { throw CallbackError.missing("descriptor") }
                let ref = try reference(for: value)
                guard ref.type == Space.self || ref.type == Workspace.self else { throw CallbackError.invalidTrigger(ref) }
                _ = eval(ref)
                return .eval(ref)

            case "dispatch":
                guard let value = query["command"] else { throw CallbackError.missing("command") }
                let command = try reference(for: value)
                guard command.type == Command.self else { throw CallbackError.invalidCommand(command) }
                guard let value = query["arguments"] else { throw CallbackError.missing("arguments") }
                guard let properties = Properties.load(value) else { throw CallbackError.invalidArguments }
                var values = properties.mergedObject.compactMapValues(Value.init)
                if let value = query["target"] {
                    let target = try reference(for: value)
                    let bound = try Command.with(command) { try Parser.parse([.reference(target)], parameters: $0.parameters) } ?? [:]
                    values.merge(bound) { _, target in target }
                }
                guard let result = try Command.with(command, { command in
                    command.dispatch(try Parser.parse(values, parameters: command.parameters))
                }) ?? nil
                else { throw CallbackError.dispatchFailed(command) }
                return .dispatch(command: command, pid: result.pid, error: result.error)

            case "run":
                guard let value = query["artifact"] else { throw CallbackError.missing("artifact") }
                let artifact = try reference(for: value)
                guard artifact.type == Artifact.self,
                      let executable = Artifact.with(artifact, { $0.handler.executable }) ?? nil
                else { throw CallbackError.invalidArtifact(artifact) }
                let environment = try query["target"].map { try reference(for: $0) }
                    .map { ["Scint_TARGET": $0.descriptorId.uuidString.lowercased()] } ?? [:]
                guard let result = services.start(executable, environment: environment) else { throw CallbackError.runFailed(artifact) }
                return .run(artifact: artifact, pid: result.pid, error: result.error)

            case "search":
                guard let query = query["query"] else { throw CallbackError.missing("query") }
                return .search(search(query))

            default:
                throw CallbackError.invalidURL
        }
    }

    private func reference(for descriptor: String) throws -> Reference {
        guard let descriptor = UUID(uuidString: descriptor) else { throw CallbackError.invalidDescriptor(descriptor) }
        guard let reference = Catalog.shared.reference(for: descriptor) else { throw CallbackError.notFound(descriptor) }
        return reference
    }

}
