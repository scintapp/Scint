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
    var stores: [Store] { [bridges, closures, spaces] }

    func store(for ref: Reference?) -> Store? {
        switch ref?.type {
            case is Space.Type: return spaces
            case is Closure.Type: return closures
            case is Bridge.Type: return bridges
            default: return nil
        }
    }

    func encode(_ space: Space) throws -> StorableStructure {
        guard space.space == nil else { throw RuntimeError.persistence(.encodingFailed(space.ref)) }

        func records(_ refs: Set<Reference>) throws -> [StorableObject] {
            try refs.sorted { $0.storageId.uuidString < $1.storageId.uuidString }.map { ref in
                guard let record = try record(for: ref) else { throw RuntimeError.persistence(.encodingFailed(ref)) }
                return record
            }
        }

        var spaceRefs: Set<Reference> = []
        var bridges: Set<Reference> = []
        var closures: Set<Reference> = []
        var pending = [space.ref]

        while let ref = pending.popLast() {
            guard spaceRefs.insert(ref).inserted else { continue }
            guard let space = spaces.with(ref, as: Space.self, { $0 })
            else { throw RuntimeError.persistence(.encodingFailed(ref)) }
            bridges.formUnion(space.bridges)
            closures.insert(space.closure)
            pending.append(contentsOf: space.spaces)
        }

        return StorableStructure(
            bridges: try records(bridges),
            closures: try records(closures),
            spaces: try records(spaceRefs)
        )
    }

    func decode(_ stored: StorableStructure) -> [(any Resolvable, Descriptor)] {
        stored.bridges.map { ($0.value, $0.descriptor) } +
            stored.closures.map { ($0.value, $0.descriptor) } +
            stored.spaces.map { ($0.value, $0.descriptor) }
    }

    func reset() {
        for ref in stores.flatMap({ $0.keys() }) { Catalog.shared.delete(ref) }
        stores.forEach { $0.reset() }
    }
}
