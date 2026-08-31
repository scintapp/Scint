import Foundation


/// What is reachable from the space a session is working in.
///
/// A space and a workspace hold their contents the same way — through a closure — but they are
/// different types, so every tool was rediscovering that with its own
/// `Space.with(…) ?? Workspace.with(…)`. It is written once here.
@MainActor enum Scope {
    static func closure(of origin: Reference) -> Reference? {
        Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure })
    }

    /// The objects of one family, anywhere at or beneath `origin`.
    ///
    /// Transitive, because a space an agent made is still its garden. Reading only the origin's
    /// own closure made `structures.add` a one-way trapdoor: move a document into a child space
    /// and it fell out of reach of every content tool, with nothing to say why.
    static func members(of namespace: ToolNamespace, in origin: Reference) -> [Reference] {
        switch namespace {
            case .content:
                return published(descendants(of: origin).flatMap { materials(in: $0) + transcripts(in: $0) })
            case .interfaces:
                return published(descendants(of: origin).flatMap { interfaces(in: $0) })
            case .structures:
                return descendants(of: origin).flatMap { structures(in: $0) }
        }
    }

    /// `origin` and every space beneath it, breadth-first and cycle-safe.
    static func descendants(of origin: Reference) -> [Reference] {
        var found: [Reference] = []
        var queue: [Reference] = [origin]
        var seen: Set<Reference> = []

        while !queue.isEmpty {
            let next = queue.removeFirst()
            guard seen.insert(next).inserted else { continue }
            found.append(next)
            queue += Space.with(next, { Array($0.spaces) }) ?? Workspace.with(next, { Array($0.spaces) }) ?? []
        }
        return found
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

    /// One space: itself, its closure, and what it connects to. A space is the agent's
    /// environment, so it is a member of its own structure rather than something outside it.
    static func structures(in origin: Reference) -> [Reference] {
        var found: [Reference] = [origin]
        if let closure = closure(of: origin) { found.append(closure) }
        found += Space.with(origin, { Array($0.bridges) }) ?? Workspace.with(origin, { Array($0.bridges) }) ?? []
        return found
    }

    /// True when this object is one the session is allowed to work with. The input material is
    /// the composer's, not the agent's.
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
