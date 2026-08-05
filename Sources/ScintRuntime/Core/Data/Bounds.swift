import Foundation


final class Content: Bounding {
    let sheets = Store()
    let transcripts = Store()
    var stores: [Store] { [sheets, transcripts] }
    
    func store(for ref: Reference?) -> Store? {
        switch ref?.type {
            case is Sheet.Type: return sheets
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
    let routes = Store()
    let spaces = Store()
    let workspaces = Store()
    var stores: [Store] { [routes, closures, spaces, workspaces] }

    func store(for ref: Reference?) -> Store? {
        switch ref?.type {
            case is Space.Type: return spaces
            case is Closure.Type: return closures
            case is Route.Type: return routes
            case is Workspace.Type: return workspaces
            default: return nil
        }
    }

    func encode(_ workspace: Workspace) throws -> StorableCollection {
        func records(_ store: Store) throws -> [StorableObject] {
            try store.keys().map { ref in
                guard let record = try record(for: ref) else { throw RuntimeError.persistence(.encodingFailed(ref)) }
                return record
            }
        }
        guard let ws = try record(for: workspace.ref) else { throw RuntimeError.persistence(.encodingFailed(workspace.ref)) }
        return StorableCollection(
            routes: try records(routes),
            closures: try records(closures),
            spaces: try records(spaces),
            workspace: ws,
            workspaces: try records(workspaces).filter { $0.value.ref != workspace.ref }
        )
    }

    func decode(_ stored: StorableCollection) throws -> (Workspace, Descriptor, [(any Resolvable, Descriptor)]) {
        guard let workspace = stored.workspace.value as? Workspace
        else { throw RuntimeError.persistence(.decodingFailed(URL(fileURLWithPath: "workspace"))) }
        return (
            workspace, stored.workspace.descriptor,
            (stored.workspaces ?? []).map { ($0.value, $0.descriptor) } +
            stored.routes.map { ($0.value, $0.descriptor) } +
            stored.closures.map { ($0.value, $0.descriptor) } +
            stored.spaces.map { ($0.value, $0.descriptor) }
        )
    }

    func reset() {
        for ref in (routes.keys() + closures.keys() + spaces.keys()) { Catalog.shared.delete(ref) }
        routes.reset(); closures.reset(); spaces.reset()
    }
}
