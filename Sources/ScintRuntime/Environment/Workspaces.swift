import Foundation


final class Workspaces: @unchecked Sendable {
    static let shared = Workspaces()
    private let structures: Structures = .init()
    var workspaces: [Reference] { structures.workspaces.keys() }

    /// Returns the container, not the bare store: mutations must route through
    /// `Bounding`, which marks the reference dirty. A raw `Store` writes silently.
    func store(for ref: Reference) -> (any Bounding)? {
        structures.store(for: ref) != nil ? structures : nil
    }

    func add(_ ref: Reference, _ value: Resolvable) { structures.add(ref, value) }

    func load() async throws {
        if !workspaces.isEmpty { return }
        let settings = Runtime.shared.settings.persistence
        let urls = try await Persistence.shared.files(in: settings.workspaces)
        for url in urls where url.pathExtension == "json" { await load(url) }
        if workspaces.isEmpty { Workspace.new("Workspace") }
    }

    func load(_ ref: Reference) async { await load(Runtime.shared.settings.persistence.workspacePath(ref.storageId)) }

    func load(_ url: URL) async {
        do {
            let stored = try await Persistence.shared.read(StorableCollection.self, at: url)
            let values = try structures.decode(stored)
            load(values)

            let refs = Set(values.compactMap { value, _ in
                value.ref.type is Workspace.Type ? value.ref : nil
            })
            let settings = Runtime.shared.settings.persistence
            let canonical = Set(refs.map { settings.workspacePath($0.storageId).standardizedFileURL.path.lowercased() })
            let source = url.standardizedFileURL.path.lowercased()
            guard refs.count != 1 || !canonical.contains(source) else { return }
            try await save(refs)
            if !canonical.contains(source) { try await Persistence.shared.delete(at: url) }
        } catch { print("Workspace load failed (\(url.lastPathComponent)): \(error)")}
    }

    func load(_ values: [(any Resolvable, Descriptor)]) {
        for (value, descriptor) in values {
            Catalog.shared.set(value.ref, descriptor)
            structures.store(for: value.ref)?.add(value.ref, value)
        }
    }

    func save() async throws {
        try await save(Set(workspaces))
    }

    func save(_ refs: Set<Reference>) async throws {
        let workspaceRefs = Set(refs.compactMap { structures.workspace(for: $0) })
        for ref in workspaceRefs.sorted(by: { $0.storageId.uuidString < $1.storageId.uuidString }) {
            guard let workspace = Workspace.with(ref, { $0 }) else { throw RuntimeError.spaces(.loadFailed) }
            let stored = try structures.encode(workspace)
            let url = Runtime.shared.settings.persistence.workspacePath(workspace.ref.storageId)
            try await Persistence.shared.write(PersistedObject(url: url, value: stored))
        }
    }

    func save(_ ref: Reference) async {
        do { try await save([ref]) } catch { print("Workspace save failed for \(ref.id): \(error)") }
    }

    func delete(_ ref: Reference) async throws {
        let closure = Space.with(ref, { $0.closure }) ?? Workspace.with(ref, { $0.closure })
        let input = closure.flatMap { Closure.with($0, { $0.input }) }
        Runtime.shared.store(for: ref)?.remove(ref)
        Catalog.shared.delete(ref)
        if ref.type == Space.self { Space.update(ref) { $0.restructure() } }
        store(for: ref)?.remove(ref)
        if let closure {
            Catalog.shared.delete(closure)
            store(for: closure)?.remove(closure)
        }
        if let input, input.type == Material.self { try await Library.shared.delete(input) }
        try await save()
    }
}
