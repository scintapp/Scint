import Foundation
import OSLog


final class Workspaces: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.kaechle.scint", category: "Workspaces")
    static let shared = Workspaces()
    private let structures: Structures = .init()
    var spaces: [Reference] { structures.spaces.all(as: Space.self).filter { $0.1.space == nil }.map(\.0) }

    func store(for ref: Reference) -> (any Bounding)? {
        structures.store(for: ref) != nil ? structures : nil
    }

    func add(_ ref: Reference, _ value: Resolvable) { structures.add(ref, value) }

    func load() async throws {
        if !spaces.isEmpty { return }
        let settings = Runtime.shared.settings.persistence
        let urls = try await Persistence.shared.files(in: settings.spaces)
        for url in urls where url.pathExtension == "json" { await load(url) }
        if spaces.isEmpty { Space.new("Workspace") }
    }

    func load(_ ref: Reference) async { await load(Runtime.shared.settings.persistence.spacePath(ref.storageId)) }

    func load(_ url: URL) async {
        do {
            let stored = try await Persistence.shared.read(StorableStructure.self, at: url)
            load(structures.decode(stored))
        } catch {
            Self.logger.error("Workspace load failed (\(url.lastPathComponent, privacy: .public)): \(String(describing: error), privacy: .public)")
        }
    }

    func load(_ values: [(any Resolvable, Descriptor)]) {
        for (value, descriptor) in values {
            Catalog.shared.set(value.ref, descriptor)
            structures.store(for: value.ref)?.add(value.ref, value)
        }
    }

    func save() async throws {
        for ref in spaces.sorted(by: { $0.storageId.uuidString < $1.storageId.uuidString }) {
            guard let space = Space.with(ref, { $0 }) else { throw RuntimeError.spaces(.loadFailed) }
            let stored = try structures.encode(space)
            let url = Runtime.shared.settings.persistence.spacePath(space.ref.storageId)
            try await Persistence.shared.write(PersistedObject(url: url, value: stored))
        }
    }

    func save(_ ref: Reference) async {
        do { try await save() }
        catch {
            Self.logger.error("Workspace save failed for \(ref.id.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }

    func delete(_ ref: Reference) async throws {
        let closure = Space.with(ref, { $0.closure })
        let input = closure.flatMap { Closure.with($0, { $0.input }) }
        if ref.type is Space.Type { Space.update(ref) { $0.restructure() } }
        Runtime.shared.store(for: ref)?.remove(ref)
        Catalog.shared.delete(ref)
        store(for: ref)?.remove(ref)
        if let closure {
            Catalog.shared.delete(closure)
            store(for: closure)?.remove(closure)
        }
        if let input, input.type == Material.self { try await Library.shared.delete(input) }
        try await save()
    }
}
