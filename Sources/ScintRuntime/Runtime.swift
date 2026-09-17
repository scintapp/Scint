import Foundation


final class Runtime: @unchecked Sendable {
    static let shared = Runtime()
    var spaces: [Reference] { Workspaces.shared.spaces }
    let registry: Registry = Registry()
    let services: Services = .init()
    let settings: Settings = .init()

    func store(for ref: Reference) -> Store? {
        switch ref.type {
            case is any Structural.Type:  Workspaces.shared.store(for: ref)?.store(for: ref)
            case is any Malleable.Type, is any Functional.Type: Library.shared.store(for: ref)?.store(for: ref)
            default: nil
        }
    }

    func load() async throws {
        try await Workspaces.shared.load()
        try await Library.shared.load()
        let composables = all(as: Space.self).map { $0.0 }
        Composer.shared.load(composables)
    }

    func save(_ ref: Reference? = nil) async {
        if let ref {
            switch ref.type {
                case is any Structural.Type: await Workspaces.shared.save(ref)
                case is any Malleable.Type, is any Functional.Type: await Library.shared.save(ref)
                default: break
            }
        } else {
            do {
                try await Workspaces.shared.save()
                try await Library.shared.save()
            } catch {
                RuntimeError.fatal()
            }
        }
    }
}

extension Runtime {
    func get(_ ref: Reference) -> Descriptor {
        guard let descriptor = Catalog.shared.get(ref) as Descriptor?
        else { fatalError(RuntimeError.Catalog.missingDescriptor(ref).description) }
        return descriptor
    }

    func set(_ ref: Reference, _ value: Descriptor) {
        Catalog.shared.set(ref, value)
    }

    func all<T: Resolvable>(as type: T.Type) -> [(Reference, T)] {
        guard let results = store(for: Reference(T.self))?.all(as: type), !results.isEmpty
        else { return [] }
        return results.filter { $0.0.descriptor.published == true }
    }
}

extension Runtime {
    func compose(_ ref: Reference) -> Composition? { Composer.shared.compose(ref) }
    func resolve(_ ref: Reference) -> Composition? { Composer.shared.resolve(ref) }
    func resolve() -> [Composition] { Composer.shared.resolve() }

    func start(_ ref: Reference) -> Composition? {
        guard Composer.shared.compose(ref) != nil else { return nil }
        Automation.start(ref)
        return Composer.shared.transmit(.composed(ref))
    }

    func stop(_ ref: Reference) -> Composition? {
        Automation.stop(ref)
        guard Composer.shared.context(ref) != nil else { return nil }
        return Composer.shared.transmit(.stopped(ref, nil))
    }
}

extension Runtime {
    func search(_ text: String = "", filters: [String] = [], limit: Int = 20) -> SearchResults {
        let search = Search(text, filters: filters)
        let results = Catalog.shared.values().compactMap { SearchResult(descriptor: $0, search: search) }

        return SearchResults(
            query: text,
            filters: search.filters,
            all: Search.Query.rank(results, limit: limit)
        )
    }
    func walk(from root: Reference, path: [Reference] = [], _ visit: ([Reference], Reference, Space) -> Void) {
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

    func climb(from root: Reference, path: [Reference] = [], _ visit: ([Reference], Reference, Space) -> Void) {
        var currentPath = path
        var cursor: Reference? = root

        while let current = cursor, let space = Space.with(current, { $0 }) {
            visit(currentPath, current, space)
            currentPath.append(current)
            cursor = space.space
        }
    }

    func cross(from root: Reference, path: [Reference] = [],_ visit: ([Reference], Reference, Bridge, Reference, Space) -> Void) {
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

    func adjacent(from source: Reference) -> [(Bridge, Reference, Space)] {
        let refs = Space.with(source, { $0.bridges }) ?? []

        return refs.compactMap { edge in
            guard let route = Bridge.with(edge, { $0 }) else { return nil }
            let target: Reference? = if route.origin == source { route.target }
            else if route.target == source { route.origin }
            else { nil }
            guard let target else { return nil }
            guard let space = Space.with(target, { $0 }) else { return nil }
            return (route, target, space)
        }
    }
}
