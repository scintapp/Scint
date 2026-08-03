import Foundation


final class Workspaces: @unchecked Sendable {
    static let shared = Workspaces()
    private let structures: Structures = .init()
    private var active: Reference?

    var workspace: Reference { guard let active else { RuntimeError.fatal() }; return active }
    var workspaces: [Reference] { structures.workspaces.keys() }

    func store(for ref: Reference) -> Store? { return structures.store(for: ref) }

    func add(_ ref: Reference, _ value: Resolvable) { structures.add(ref, value) }

    func update<T: Resolvable, R>(_ ref: Reference, as type: T.Type = T.self, _ body: (inout T) throws -> R) rethrows -> R? {
        try structures.update(ref, as: type, body)
    }

    func create() async throws {
        let workspace = Workspace.new("Studio", framing: .Scint)
        Runtime.shared.settings.persistence.lastWorkspaceId = workspace.storageId
        active = workspace
        try await save()
    }

    func load() async throws {
        if active != nil { return }
        let settings = Runtime.shared.settings.persistence
        let lastWorkspaceId = settings.lastWorkspaceId
        let urls = try await Persistence.shared.files(in: settings.workspaces)
        for url in urls where url.pathExtension == "json" { await load(url) }
        if let id = lastWorkspaceId,
           let ref = structures.workspaces.keys().first(where: { $0.storageId == id }) {
            active = ref
            Runtime.shared.settings.persistence.lastWorkspaceId = id
        }
        if active == nil { try await create() }
    }

    func load(_ ref: Reference) async { await load(ref.storageId) }

    func load(_ storageId: UUID) async { await load(Runtime.shared.settings.persistence.spacesPath(storageId)) }

    func load(_ url: URL) async {
        do {
            let stored = try await Persistence.shared.read(StorableCollection.self, at: url)
            let (space, descriptor, values) = try structures.decode(stored)
            load(space, descriptor: descriptor, values: values)
        } catch { print("Workspace load failed (\(url.lastPathComponent)): \(error)")}
    }

    func load(_ workspace: Workspace, descriptor: Descriptor, values: [(any Resolvable, Descriptor)]) {
        Catalog.shared.set(workspace.ref, descriptor)
        structures.store(for: workspace.ref)?.add(workspace.ref, workspace)
        active = workspace.ref

        for (value, descriptor) in values {
            Catalog.shared.set(value.ref, descriptor)
            structures.store(for: value.ref)?.add(value.ref, value)
        }
        for (value, _) in values where value.ref.type is Space.Type {
            if (Space.with(value.ref, { $0.space }) ?? nil) == nil {
                Space.update(value.ref) { $0.attach(to: workspace.ref) }
            }
        }

        Runtime.shared.settings.persistence.lastWorkspaceId = workspace.ref.storageId
    }

    func save() async throws {
        guard let active, let ws = Workspace.with(active, { $0 })
        else { throw RuntimeError.spaces(.loadFailed) }
        let stored = try structures.encode(ws)
        let url = Runtime.shared.settings.persistence.spacesPath(ws.ref.storageId)
        try await Persistence.shared.write(PersistedObject(url: url, value: stored))
    }

    func save(_ ref: Reference) async {
        guard active != nil else { return }
        do { try await save() } catch { print("Workspace save failed for \(ref.id): \(error)") }
    }

    func delete(_ ref: Reference) async throws {
        let closure = Space.with(ref, { $0.closure }) ?? Workspace.with(ref, { $0.closure })
        let input = closure.flatMap { Closure.with($0, { $0.input }) }
        _ = Runtime.shared.get(ref)
        Catalog.shared.delete(ref)
        if ref.type == Space.self { Space.update(ref) { $0.restructure() } }
        store(for: ref)?.remove(ref)
        if let closure {
            _ = Runtime.shared.get(closure)
            Catalog.shared.delete(closure)
            store(for: closure)?.remove(closure)
        }
        if let input, input.type == Sheet.self { try await Library.shared.delete(input) }
        try await save()
    }
}
