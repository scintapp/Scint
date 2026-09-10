import Foundation


enum Scope {
    static func closure(of origin: Reference) -> Reference? {
        Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure })
    }

    static func members(of namespace: ToolNamespace, in origin: Reference) -> [Reference] {
        switch namespace {
            case .content: return published(materials(in: origin) + transcripts(in: origin))
            case .interfaces: return published(interfaces(in: origin))
            case .structures: return structures(in: origin)
        }
    }

    static func materials(in origin: Reference) -> [Reference] {
        contents(of: origin) { $0.materials }
    }

    static func transcripts(in origin: Reference) -> [Reference] {
        contents(of: origin) { $0.transcripts }
    }

    static func interfaces(in origin: Reference) -> [Reference] {
        contents(of: origin) { $0.artifacts + $0.commands + $0.harnesses }
    }

    static func structures(in origin: Reference) -> [Reference] {
        var found: [Reference] = [origin]
        if let closure = closure(of: origin) { found.append(closure) }
        found += Space.with(origin, { Array($0.bridges) }) ?? Workspace.with(origin, { Array($0.bridges) }) ?? []
        return found
    }

    static func reachable(_ ref: Reference, in origin: Reference) -> Bool {
        ToolNamespace.of(ref).map { members(of: $0, in: origin).contains(ref) } ?? false
    }

    private static func contents(of origin: Reference, _ body: (Closure) -> [Reference]) -> [Reference] {
        guard let closure = closure(of: origin) else { return [] }
        return Closure.with(closure, body) ?? []
    }

    private static func published(_ refs: [Reference]) -> [Reference] {
        var seen: Set<Reference> = []
        return refs.filter { seen.insert($0).inserted }
            .filter { !$0.descriptor.tags.contains("input") && $0.descriptor.published }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }
}
