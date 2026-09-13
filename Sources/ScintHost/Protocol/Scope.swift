import Foundation


enum Scope {
    static func closure(of origin: Reference) -> Reference? {
        Space.with(origin, { $0.closure })
    }

    static func members(of namespace: ToolNamespace, in origin: Reference) -> [Reference] {
        let candidates = spaces(in: origin).flatMap { space in
            switch namespace {
                case .content: materials(in: space) + transcripts(in: space)
                case .interfaces: interfaces(in: space)
                case .structures: structures(in: space)
            }
        }
        return Array(Set(candidates)).filter { permissions(for: $0, in: origin).contains(.read) }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }

    static func materials(in origin: Reference) -> [Reference] {
        contents(of: origin) { $0.materials }
    }

    static func transcripts(in origin: Reference) -> [Reference] {
        var found: Set<Reference> = []
        func visit(_ ref: Reference) {
            guard found.insert(ref).inserted else { return }
            for branch in Transcript.with(ref, { $0.branches }) ?? [] { visit(branch) }
        }
        for root in contents(of: origin, { $0.transcripts }) where root.descriptor.published { visit(root) }
        return Array(found)
    }

    static func interfaces(in origin: Reference) -> [Reference] {
        let configured = Space.with(origin, { $0.harness }) ?? nil
        return contents(of: origin) { $0.artifacts + $0.commands + $0.harnesses }
            + (configured.map { [$0] } ?? [])
    }

    static func structures(in origin: Reference) -> [Reference] {
        var found: [Reference] = [origin]
        if let closure = closure(of: origin) { found.append(closure) }
        found += Space.with(origin, { Array($0.bridges) }) ?? []
        return found
    }

    static func reachable(_ ref: Reference, in origin: Reference) -> Bool {
        ToolNamespace.of(ref).map { members(of: $0, in: origin).contains(ref) } ?? false
    }

    private static func contents(of origin: Reference, _ body: (Closure) -> [Reference]) -> [Reference] {
        guard let closure = closure(of: origin) else { return [] }
        return Closure.with(closure, body) ?? []
    }
}

extension Scope {
    enum Permission: String, CaseIterable, Sendable {
        case read, create, insert, update, delete, run, compose, dispatch, observe, evaluate, `import`
    }

    static func spaces(in origin: Reference) -> Set<Reference> {
        var found: Set<Reference> = []
        Runtime.shared.walk(from: origin) { _, ref, _ in found.insert(ref) }
        return found
    }

    static func all<T: Resolvable>(_ type: T.Type) -> [(Reference, T)] {
        Runtime.shared.store(for: Reference(type))?.all(as: type) ?? []
    }

    static func permissions(for ref: Reference, in origin: Reference) -> Set<Permission> {
        guard let descriptor = Catalog.shared.get(ref), Runtime.shared.store(for: ref)?.keys().contains(ref) == true else { return [] }
        let owned = spaces(in: origin)
        if ref.type == Space.self, owned.contains(ref) {
            var permissions: Set<Permission> = [.read, .create, .update, .compose, .dispatch, .observe, .evaluate]
            if ref != origin, Composer.shared.context(ref) == nil { permissions.insert(.delete) }
            return permissions
        }
        if ref.type == Closure.self, owned.contains(where: { closure(of: $0) == ref }) { return [.read] }
        if ref.type == Bridge.self, owned.contains(where: { Space.with($0, { $0.bridges.contains(ref) }) == true }) { return [.read] }
        if ref.type == Transcript.self, owned.contains(where: { transcripts(in: $0).contains(ref) }) { return [.read] }
        guard descriptor.published, !descriptor.tags.contains("input") else { return [] }
        let holders = Set(all(Space.self).compactMap { space, value in
            value.sections.contains(ref) || value.harness == ref ? space : nil
        })
        guard !holders.isDisjoint(with: owned) else {
            return ref.type is any Functional.Type || ref.type == Material.self ? [.import] : []
        }
        var permissions: Set<Permission> = [.read]
        let exclusive = holders.isSubset(of: owned)
        if ref.type == Material.self, exclusive { permissions.formUnion([.insert, .delete]) }
        if ref.type == Command.self || ref.type == Harness.self { permissions.insert(.run) }
        if ref.type is any Functional.Type, exclusive { permissions.insert(.delete) }
        return permissions
    }

    @MainActor
    static func require(_ ref: Reference, _ permission: Permission, for identity: ToolIdentity) throws {
        try identity.verify()
        guard permissions(for: ref, in: identity.space).contains(permission) else {
            throw ToolFailure("Reference is unavailable for \(permission.rawValue) in this context.")
        }
    }

    @MainActor
    static func resolve(_ arguments: Properties, _ key: String = "ref", permission: Permission,
                        for identity: ToolIdentity, fallback: Reference? = nil) throws -> Reference {
        try identity.verify()
        let ref: Reference
        if arguments[key] == nil, let fallback { ref = fallback }
        else {
            let text = try arguments.requireString(key)
            guard let url = URL(string: text), url.scheme == Reference.Link.scheme,
                  url.query == nil, url.fragment == nil, url.pathComponents.count == 2,
                  let found = Reference.Link.reference(in: url),
                  url.host == Reference.Link.host(for: found) else {
                throw ToolFailure("\(key) must be a valid scint://<kind>/<id> address.")
            }
            ref = found
        }
        try require(ref, permission, for: identity)
        return ref
    }
}
