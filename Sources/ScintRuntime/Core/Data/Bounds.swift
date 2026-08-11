import Foundation


final class Content: Bounding {
    let materials = Store()
    let transcripts = Store()
    var stores: [Store] { [materials, transcripts] }
    
    func store(for ref: Reference?) -> Store? {
        switch ref?.type {
            case is Material.Type: return materials
            case is Transcript.Type: return transcripts
            default: return nil
        }
    }
    
    func reset() {
        for ref in stores.flatMap({ $0.keys() }) { Catalog.shared.delete(ref) }
        stores.forEach { $0.reset() }
    }
}

final class Interfaces: Bounding {
    let artifacts = Store()
    let controls = Store()
    let services = Store()
    var stores: [Store] { [artifacts, controls, services] }

    func store(for ref: Reference?) -> Store? {
        switch ref?.type {
            case is Artifact.Type: return artifacts
            case is Command.Type: return controls
            case is Harness.Type: return services
            default: return nil
        }
    }

    func reset() {
        for ref in stores.flatMap({ $0.keys() }) { Catalog.shared.delete(ref) }
        stores.forEach { $0.reset() }
    }
}

final class Structures: Bounding {
    let closures = Store()
    let bridges = Store()
    let spaces = Store()
    let workspaces = Store()
    var stores: [Store] { [bridges, closures, spaces, workspaces] }

    func store(for ref: Reference?) -> Store? {
        switch ref?.type {
            case is Space.Type: return spaces
            case is Closure.Type: return closures
            case is Bridge.Type: return bridges
            case is Workspace.Type: return workspaces
            default: return nil
        }
    }

    func workspace(for ref: Reference) -> Reference? {
        var current: Reference? = ref
        var visited: Set<Reference> = []

        while let ref = current, visited.insert(ref).inserted {
            switch ref.type {
                case is Workspace.Type:
                    return workspaces.with(ref, as: Workspace.self, { $0.ref })
                case is Space.Type:
                    current = spaces.with(ref, as: Space.self, { $0.space }) ?? nil
                case is Closure.Type:
                    current = closures.with(ref, as: Closure.self, { $0.origin })
                case is Bridge.Type:
                    current = bridges.with(ref, as: Bridge.self, { $0.origin }) ?? nil
                default:
                    return nil
            }
        }
        return nil
    }

    func encode(_ workspace: Workspace) throws -> StorableCollection {
        func records(_ refs: Set<Reference>) throws -> [StorableObject] {
            try refs.sorted { $0.storageId.uuidString < $1.storageId.uuidString }.map { ref in
                guard let record = try record(for: ref) else { throw RuntimeError.persistence(.encodingFailed(ref)) }
                return record
            }
        }

        var spaceRefs: Set<Reference> = []
        var bridges: Set<Reference> = []
        var closures: Set<Reference> = [workspace.closure]
        var pending = Array(workspace.spaces)

        while let ref = pending.popLast() {
            guard spaceRefs.insert(ref).inserted else { continue }
            guard let space = spaces.with(ref, as: Space.self, { $0 })
            else { throw RuntimeError.persistence(.encodingFailed(ref)) }
            bridges.formUnion(space.bridges)
            closures.insert(space.closure)
            pending.append(contentsOf: space.spaces)
        }

        guard let record = try record(for: workspace.ref)
        else { throw RuntimeError.persistence(.encodingFailed(workspace.ref)) }
        return StorableCollection(
            bridges: try records(bridges),
            closures: try records(closures),
            spaces: try records(spaceRefs),
            workspaces: [record]
        )
    }

    func decode(_ stored: StorableCollection) throws -> [(any Resolvable, Descriptor)] {
        guard !stored.workspaces.isEmpty, stored.workspaces.allSatisfy({ $0.value is Workspace })
        else { throw RuntimeError.persistence(.decodingFailed(URL(fileURLWithPath: "workspaces"))) }
        return stored.workspaces.map { ($0.value, $0.descriptor) } +
            stored.bridges.map { ($0.value, $0.descriptor) } +
            stored.closures.map { ($0.value, $0.descriptor) } +
            stored.spaces.map { ($0.value, $0.descriptor) }
    }

    func reset() {
        for ref in stores.flatMap({ $0.keys() }) { Catalog.shared.delete(ref) }
        stores.forEach { $0.reset() }
    }
}
